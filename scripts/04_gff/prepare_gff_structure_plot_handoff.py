#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections import defaultdict
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import read_tsv, write_tsv

METRIC_MATRIX_FIELDS_BASE = ["metric"]
PLOT_FIELDS = ["species", "plot_group", "x", "y", "value", "source_category"]


def main():
    ap = argparse.ArgumentParser(description="Prepare plot-ready handoff tables from GFF structure summary outputs.")
    ap.add_argument("--metrics", required=True)
    ap.add_argument("--distributions", required=True)
    ap.add_argument("--out-prefix", required=True)
    args = ap.parse_args()

    metric_values = defaultdict(dict)
    species_order = []
    for row in read_tsv(args.metrics):
        species = row.get("species", "NA")
        if species not in species_order:
            species_order.append(species)
        metric_values[row.get("metric", "NA")][species] = row.get("value", "NA")
    matrix = []
    for metric in sorted(metric_values):
        out = {"metric": metric}
        for species in species_order:
            out[species] = metric_values[metric].get(species, "NA")
        matrix.append(out)
    write_tsv(f"{args.out_prefix}.metric_matrix.tsv", ["metric", *species_order], matrix)

    plot_rows = []
    for row in read_tsv(args.distributions):
        category = row.get("category", "NA")
        value = row.get("length") if row.get("length") not in {None, "", "NA"} else row.get("count", "NA")
        plot_rows.append({
            "species": row.get("species", "NA"),
            "plot_group": category,
            "x": row.get("species", "NA"),
            "y": category,
            "value": value,
            "source_category": category,
        })
    write_tsv(f"{args.out_prefix}.distribution_plot_long.tsv", PLOT_FIELDS, plot_rows)


if __name__ == "__main__":
    main()
