#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import ensure_file, open_text, write_lines, write_tsv


def main():
    ap = argparse.ArgumentParser(description="Select subject IDs from BLAST/DIAMOND outfmt6 results.")
    ap.add_argument("--blast", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--summary", default=None)
    ap.add_argument("--mode", choices=["top_per_query", "all"], default="top_per_query")
    ap.add_argument("--top", type=int, default=1)
    ap.add_argument("--max-evalue", type=float, default=None)
    ap.add_argument("--min-bitscore", type=float, default=None)
    args = ap.parse_args()
    ensure_file(args.blast, "BLAST outfmt6")
    hits = defaultdict(list)
    with open_text(args.blast) as handle:
        for line in handle:
            if not line.strip() or line.startswith("#"):
                continue
            p = line.rstrip("\n").split("\t")
            if len(p) < 12:
                continue
            evalue = float(p[10])
            bitscore = float(p[11])
            if args.max_evalue is not None and evalue > args.max_evalue:
                continue
            if args.min_bitscore is not None and bitscore < args.min_bitscore:
                continue
            hits[p[0]].append((p[1], evalue, bitscore, p))
    selected, rows = [], []
    for q, hs in hits.items():
        hs.sort(key=lambda x: (x[1], -x[2]))
        take = hs if args.mode == "all" else hs[:args.top]
        for sid, ev, bs, raw in take:
            selected.append(sid)
            rows.append({"query": q, "subject": sid, "evalue": ev, "bitscore": bs})
    write_lines(args.out, sorted(dict.fromkeys(selected)))
    if args.summary:
        write_tsv(args.summary, ["query", "subject", "evalue", "bitscore"], rows)


if __name__ == "__main__":
    main()
