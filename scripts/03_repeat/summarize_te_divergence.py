#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections import defaultdict
from pathlib import Path
import re
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import open_text, write_tsv

DETAIL_FIELDS = [
    "seqid", "start", "end", "strand", "repeat_name", "repeat_class", "repeat_family",
    "divergence", "deletion", "insertion", "length", "insertion_time_mya",
]
SUMMARY_FIELDS = [
    "repeat_class", "repeat_family", "copies", "covered_bp", "mean_divergence", "median_divergence", "mean_insertion_time_mya",
]


def split_repeat_class(value: str) -> tuple[str, str]:
    if "/" in value:
        first, rest = value.split("/", 1)
        return first, rest
    return value or "NA", "NA"


def parse_repeatmasker(path):
    rows = []
    with open_text(path) as handle:
        for line in handle:
            if not line.strip() or line.lstrip().startswith(("SW", "score", "perc", "#")):
                continue
            cols = line.split()
            if len(cols) < 11:
                continue
            try:
                divergence = float(cols[1])
                deletion = float(cols[2])
                insertion = float(cols[3])
                start = int(cols[5])
                end = int(cols[6])
            except ValueError:
                continue
            strand = "-" if cols[8] == "C" else cols[8]
            repeat_name = cols[9]
            repeat_class_raw = cols[10]
            repeat_class, repeat_family = split_repeat_class(repeat_class_raw)
            rows.append({
                "seqid": cols[4],
                "start": start,
                "end": end,
                "strand": strand,
                "repeat_name": repeat_name,
                "repeat_class": repeat_class,
                "repeat_family": repeat_family,
                "divergence": divergence,
                "deletion": deletion,
                "insertion": insertion,
                "length": max(0, end - start + 1),
            })
    return rows


def median(values):
    values = sorted(values)
    if not values:
        return "NA"
    mid = len(values) // 2
    if len(values) % 2:
        return values[mid]
    return (values[mid - 1] + values[mid]) / 2


def main():
    ap = argparse.ArgumentParser(description="Summarize RepeatMasker divergence and optional TE insertion-time estimates.")
    ap.add_argument("--repeatmasker-out", required=True)
    ap.add_argument("--out", required=True, help="Per-repeat detail TSV")
    ap.add_argument("--summary", required=True)
    ap.add_argument("--substitution-rate", type=float, default=None, help="Substitutions/site/year for insertion time: divergence_fraction / (2*r)")
    args = ap.parse_args()

    rows = parse_repeatmasker(args.repeatmasker_out)
    for row in rows:
        if args.substitution_rate and args.substitution_rate > 0:
            div_fraction = row["divergence"] / 100.0
            row["insertion_time_mya"] = f"{div_fraction / (2 * args.substitution_rate) / 1e6:.6f}"
        else:
            row["insertion_time_mya"] = "NA"

    grouped = defaultdict(list)
    for row in rows:
        grouped[(row["repeat_class"], row["repeat_family"])].append(row)

    summary = []
    for (repeat_class, repeat_family), items in sorted(grouped.items()):
        divs = [item["divergence"] for item in items]
        times = [float(item["insertion_time_mya"]) for item in items if item["insertion_time_mya"] != "NA"]
        summary.append({
            "repeat_class": repeat_class,
            "repeat_family": repeat_family,
            "copies": len(items),
            "covered_bp": sum(item["length"] for item in items),
            "mean_divergence": f"{sum(divs) / len(divs):.6f}" if divs else "NA",
            "median_divergence": f"{median(divs):.6f}" if divs else "NA",
            "mean_insertion_time_mya": f"{sum(times) / len(times):.6f}" if times else "NA",
        })

    write_tsv(args.out, DETAIL_FIELDS, rows)
    write_tsv(args.summary, SUMMARY_FIELDS, summary)


if __name__ == "__main__":
    main()
