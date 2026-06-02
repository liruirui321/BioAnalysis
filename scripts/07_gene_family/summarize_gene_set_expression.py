#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections import defaultdict
from pathlib import Path
import statistics
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import read_id_set, read_tsv, write_tsv

GENE_FIELDS = ["gene_id", "family_id", "sample", "expression_value"]
SUMMARY_FIELDS = ["family_id", "sample", "genes_observed", "mean_expression", "median_expression", "sum_expression"]


def family_map(evidence, target_ids):
    mapping = defaultdict(set)
    if evidence:
        for row in read_tsv(evidence):
            gid = row.get("gene_id")
            fam = row.get("family_id", "target")
            if gid:
                mapping[gid].add(fam)
    if target_ids:
        for gid in read_id_set(target_ids):
            mapping.setdefault(gid, {"target"})
    return mapping


def as_float(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def main():
    ap = argparse.ArgumentParser(description="Summarize expression matrices by target family or gene set.")
    ap.add_argument("--matrix", required=True, help="TSV expression matrix with gene ID column and sample columns")
    ap.add_argument("--out", required=True, help="Family/sample expression summary TSV")
    ap.add_argument("--gene-details", required=True, help="Long gene/sample expression TSV")
    ap.add_argument("--evidence", default=None, help="Target-family evidence table with gene_id and family_id")
    ap.add_argument("--target-ids", default=None)
    ap.add_argument("--id-column", default="gene_id")
    args = ap.parse_args()

    mapping = family_map(args.evidence, args.target_ids)
    rows = read_tsv(args.matrix)
    if not rows:
        write_tsv(args.gene_details, GENE_FIELDS, [])
        write_tsv(args.out, SUMMARY_FIELDS, [])
        return
    sample_cols = [col for col in rows[0].keys() if col != args.id_column]
    gene_details = []
    values = defaultdict(list)
    for row in rows:
        gid = row.get(args.id_column) or row.get("gene_id") or row.get("transcript_id")
        if gid not in mapping:
            continue
        for sample in sample_cols:
            value = as_float(row.get(sample))
            if value is None:
                continue
            for fam in mapping[gid]:
                gene_details.append({"gene_id": gid, "family_id": fam, "sample": sample, "expression_value": f"{value:.6f}"})
                values[(fam, sample)].append(value)
    summary = []
    for (fam, sample), vals in sorted(values.items()):
        summary.append({
            "family_id": fam,
            "sample": sample,
            "genes_observed": len(vals),
            "mean_expression": f"{statistics.mean(vals):.6f}" if vals else "NA",
            "median_expression": f"{statistics.median(vals):.6f}" if vals else "NA",
            "sum_expression": f"{sum(vals):.6f}" if vals else "NA",
        })
    write_tsv(args.gene_details, GENE_FIELDS, gene_details)
    write_tsv(args.out, SUMMARY_FIELDS, summary)


if __name__ == "__main__":
    main()
