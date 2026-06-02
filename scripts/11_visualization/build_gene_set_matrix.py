#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import open_text, write_tsv


def read_ids(path):
    ids = set()
    with open_text(path) as handle:
        for line in handle:
            if line.strip() and not line.startswith("#"):
                ids.add(line.split()[0])
    return ids


def parse_set_args(values):
    sets = []
    for value in values:
        if "=" not in value:
            raise SystemExit("--set must be NAME=FILE")
        name, path = value.split("=", 1)
        sets.append((name, path))
    return sets


def main():
    ap = argparse.ArgumentParser(description="Build an UpSet/Venn-style binary membership matrix from multiple gene ID lists.")
    ap.add_argument("--set", dest="sets", action="append", required=True, help="NAME=gene_ids.txt; repeatable")
    ap.add_argument("--out", required=True)
    ap.add_argument("--summary", default=None)
    args = ap.parse_args()

    sets = [(name, read_ids(path)) for name, path in parse_set_args(args.sets)]
    all_ids = sorted(set().union(*(ids for _name, ids in sets))) if sets else []
    rows = []
    for gid in all_ids:
        row = {"gene_id": gid}
        for name, ids in sets:
            row[name] = 1 if gid in ids else 0
        row["membership_count"] = sum(int(row[name]) for name, _ids in sets)
        rows.append(row)
    fields = ["gene_id", *[name for name, _ids in sets], "membership_count"]
    write_tsv(args.out, fields, rows)
    if args.summary:
        summary = [{"set_name": name, "gene_count": len(ids)} for name, ids in sets]
        write_tsv(args.summary, ["set_name", "gene_count"], summary)


if __name__ == "__main__":
    main()
