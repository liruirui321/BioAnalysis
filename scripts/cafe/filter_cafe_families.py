#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import read_tsv, write_tsv


def main():
    ap = argparse.ArgumentParser(description="Filter CAFE family count matrix.")
    ap.add_argument("--input", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--removed", required=True)
    ap.add_argument("--max-copy", type=int, default=None)
    ap.add_argument("--min-species", type=int, default=1)
    ap.add_argument("--remove-all-zero", action="store_true")
    args = ap.parse_args()
    rows = read_tsv(args.input)
    fields = list(rows[0]) if rows else []
    meta = {"Desc", "Family ID"}
    species = [f for f in fields if f not in meta]
    kept, removed = [], []
    for r in rows:
        vals = []
        bad = []
        for sp in species:
            try:
                v = int(float(r.get(sp, "0") or 0))
            except ValueError:
                v = 0
            vals.append(v)
        if args.remove_all_zero and sum(vals) == 0:
            bad.append("all_zero")
        if args.max_copy is not None and max(vals or [0]) > args.max_copy:
            bad.append("max_copy")
        if sum(1 for v in vals if v > 0) < args.min_species:
            bad.append("min_species")
        if bad:
            rr = {"Family ID": r.get("Family ID", r.get("Desc", "NA")), "reason": ";".join(bad)}
            removed.append(rr)
        else:
            kept.append(r)
    write_tsv(args.out, fields, kept)
    write_tsv(args.removed, ["Family ID", "reason"], removed)


if __name__ == "__main__":
    main()
