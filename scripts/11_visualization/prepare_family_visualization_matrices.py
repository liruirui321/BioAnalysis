#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections import defaultdict
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import read_tsv, write_tsv


def add_values(path, row_key, col_key, value_key, values):
    if not path:
        return set(), set()
    rows = set()
    cols = set()
    for row in read_tsv(path):
        r = row.get(row_key)
        c = row.get(col_key)
        if not r or not c:
            continue
        v = row.get(value_key, "1") if value_key else "1"
        values[(r, c)] = v if v not in {"", "NA"} else "0"
        rows.add(r)
        cols.add(c)
    return rows, cols


def write_matrix(path, row_name, rows, cols, values):
    out_rows = []
    for r in sorted(rows):
        out = {row_name: r}
        for c in sorted(cols):
            out[c] = values.get((r, c), "0")
        out_rows.append(out)
    write_tsv(path, [row_name, *sorted(cols)], out_rows)


def main():
    ap = argparse.ArgumentParser(description="Prepare target-family visualization matrices from expression, evolution, and HGT integration tables.")
    ap.add_argument("--out-prefix", required=True)
    ap.add_argument("--expression-summary", default=None)
    ap.add_argument("--target-evolution", default=None)
    ap.add_argument("--hgt-family", default=None)
    args = ap.parse_args()

    outputs = []
    if args.expression_summary:
        values = {}
        rows, cols = add_values(args.expression_summary, "family_id", "sample", "mean_expression", values)
        path = f"{args.out_prefix}.expression_matrix.tsv"
        write_matrix(path, "family_id", rows, cols, values)
        outputs.append({"matrix": path, "source": args.expression_summary, "matrix_type": "expression"})
    if args.target_evolution:
        values = {}
        rows, cols = add_values(args.target_evolution, "target_family_id", "evolution_status", None, values)
        path = f"{args.out_prefix}.target_evolution_status_matrix.tsv"
        write_matrix(path, "target_family_id", rows, cols, values)
        outputs.append({"matrix": path, "source": args.target_evolution, "matrix_type": "target_evolution_status"})
    if args.hgt_family:
        values = {}
        rows, cols = add_values(args.hgt_family, "query_id", "target_family_status", None, values)
        path = f"{args.out_prefix}.hgt_target_status_matrix.tsv"
        write_matrix(path, "query_id", rows, cols, values)
        outputs.append({"matrix": path, "source": args.hgt_family, "matrix_type": "hgt_target_status"})
    write_tsv(f"{args.out_prefix}.matrix_manifest.tsv", ["matrix", "source", "matrix_type"], outputs)


if __name__ == "__main__":
    main()
