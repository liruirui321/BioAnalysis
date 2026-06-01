#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import iter_fasta, write_fasta, write_tsv


def main():
    ap = argparse.ArgumentParser(description="Prefix FASTA IDs and write an ID map.")
    ap.add_argument("--input", required=True)
    ap.add_argument("--prefix", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--map", required=True)
    ap.add_argument("--sep", default="|")
    args = ap.parse_args()
    records, rows = [], []
    for old, seq in iter_fasta(args.input):
        new = f"{args.prefix}{args.sep}{old}"
        records.append((new, seq))
        rows.append({"prefixed_id": new, "original_id": old, "prefix": args.prefix})
    write_fasta(records, args.out)
    write_tsv(args.map, ["prefixed_id", "original_id", "prefix"], rows)


if __name__ == "__main__":
    main()
