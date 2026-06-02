#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import read_tsv, write_tsv


def to_float(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0.0


def main():
    ap = argparse.ArgumentParser(description="Build a pairwise heatmap-ready matrix from synteny summary tables.")
    ap.add_argument("--summary", required=True, help="Synteny summary TSV")
    ap.add_argument("--out", required=True)
    ap.add_argument("--metric", choices=["blocks", "linked_gene_pairs", "unique_ref_genes", "unique_query_genes", "covered_target_regions"], default="blocks")
    ap.add_argument("--symmetric", action="store_true", help="Mirror values across species pairs")
    args = ap.parse_args()

    values = {}
    labels = set()
    for row in read_tsv(args.summary):
        ref = row.get("ref_species", "ref")
        query = row.get("query_species", "query")
        labels.update([ref, query])
        values[(ref, query)] = to_float(row.get(args.metric))
        if args.symmetric:
            values[(query, ref)] = to_float(row.get(args.metric))
    labels = sorted(labels)
    rows = []
    for ref in labels:
        out = {"species": ref}
        for query in labels:
            out[query] = f"{values.get((ref, query), 0):.6g}"
        rows.append(out)
    write_tsv(args.out, ["species", *labels], rows)


if __name__ == "__main__":
    main()
