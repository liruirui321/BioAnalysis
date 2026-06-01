#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections import defaultdict
from math import comb
from pathlib import Path
import re
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import read_id_set, read_tsv, write_tsv


def split_terms(value: str) -> list[str]:
    if not value or value == "NA":
        return []
    return sorted({part.strip().replace("ko:", "") for part in re.split(r"[;,|]\s*", value) if part.strip() and part.strip() != "NA"})


def fisher_right_tail(a, b, c, d):
    n = a + b + c + d
    row1 = a + b
    col1 = a + c
    max_a = min(row1, col1)
    denom = comb(n, row1)
    p = 0.0
    for x in range(a, max_a + 1):
        p += comb(col1, x) * comb(n - col1, row1 - x) / denom
    return min(p, 1.0)


def benjamini_hochberg(rows):
    m = len(rows)
    ranked = sorted(enumerate(rows), key=lambda item: item[1]["p_value"])
    qvals = [1.0] * m
    prev = 1.0
    for rank, (idx, row) in reversed(list(enumerate(ranked, start=1))):
        q = min(prev, row["p_value"] * m / rank)
        qvals[idx] = q
        prev = q
    return qvals


def main():
    ap = argparse.ArgumentParser(description="Run simple overrepresentation enrichment for GO, KEGG, or Pfam terms.")
    ap.add_argument("--annotation", required=True)
    ap.add_argument("--foreground", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--mode", choices=["go", "kegg", "pfam"], required=True)
    ap.add_argument("--background", default=None)
    ap.add_argument("--id-column", default="transcript_id")
    ap.add_argument("--term-column", default=None)
    ap.add_argument("--min-count", type=int, default=1)
    args = ap.parse_args()

    default_column = {"go": "GO_terms", "kegg": "KEGG_ko", "pfam": "Pfam_ids"}[args.mode]
    term_column = args.term_column or default_column
    foreground = read_id_set(args.foreground)
    background_filter = read_id_set(args.background) if args.background else None

    term_to_ids = defaultdict(set)
    universe = set()
    for row in read_tsv(args.annotation):
        gid = row.get(args.id_column, "NA")
        if gid == "NA":
            continue
        if background_filter is not None and gid not in background_filter:
            continue
        universe.add(gid)
        for term in split_terms(row.get(term_column, "NA")):
            term_to_ids[term].add(gid)

    fg = foreground & universe
    bg_total = len(universe)
    fg_total = len(fg)
    rows = []
    for term, ids in term_to_ids.items():
        a = len(ids & fg)
        if a < args.min_count:
            continue
        c = len(ids - fg)
        b = fg_total - a
        d = bg_total - fg_total - c
        p_value = fisher_right_tail(a, b, c, d)
        rows.append({
            "mode": args.mode,
            "term_id": term,
            "foreground_with_term": a,
            "foreground_total": fg_total,
            "background_with_term": len(ids),
            "background_total": bg_total,
            "p_value": p_value,
            "q_value": 1.0,
            "foreground_ids": ";".join(sorted(ids & fg)),
        })

    qvals = benjamini_hochberg(rows)
    for row, q in zip(rows, qvals):
        row["p_value"] = f"{row['p_value']:.6g}"
        row["q_value"] = f"{q:.6g}"
    rows.sort(key=lambda r: (float(r["q_value"]), float(r["p_value"]), r["term_id"]))
    write_tsv(args.out, [
        "mode", "term_id", "foreground_with_term", "foreground_total", "background_with_term",
        "background_total", "p_value", "q_value", "foreground_ids",
    ], rows)


if __name__ == "__main__":
    main()
