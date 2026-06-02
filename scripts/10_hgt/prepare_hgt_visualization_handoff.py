#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import read_tsv, write_tsv


def to_int(value):
    try:
        return int(float(value))
    except (TypeError, ValueError):
        return 0


def read_condition_matrix(path):
    rows = read_tsv(path)
    long_rows = []
    pct_rows = []
    for row in rows:
        species = row.get("species", "NA")
        total = to_int(row.get("total"))
        for key, value in row.items():
            if key in {"species", "total"}:
                continue
            count = to_int(value)
            if count == 0:
                continue
            long_rows.append({"species": species, "donor_group": key, "hgt_count": count, "total_hgt": total})
            pct_rows.append({"species": species, "donor_group": key, "hgt_count": count, "total_hgt": total, "fraction": f"{count / total:.6f}" if total else "0.000000"})
    return long_rows, pct_rows


def read_event_summary(path):
    rows = []
    for row in read_tsv(path):
        gain = to_int(row.get("gain"))
        expansion = to_int(row.get("expansion"))
        rows.append({
            "node": row.get("node", "NA"),
            "parent": row.get("parent", "NA"),
            "gain": gain,
            "expansion": expansion,
            "hgt_gain_expansion": to_int(row.get("hgt_gain_expansion")) or gain + expansion,
            "method": row.get("method", "NA"),
        })
    return rows


def read_source_breakdown(path):
    out = []
    for row in read_tsv(path):
        if row.get("event") not in {"gain", "expansion"}:
            continue
        out.append({
            "node": row.get("node", "NA"),
            "event": row.get("event", "NA"),
            "donor_group": row.get("majority_source", "NA"),
            "orthogroup_count": row.get("orthogroup_count", 0),
            "method": row.get("method", "NA"),
        })
    return out


def main():
    ap = argparse.ArgumentParser(description="Prepare plot-ready HGT donor and node-event handoff tables for external visualization.")
    ap.add_argument("--outdir", required=True)
    ap.add_argument("--prefix", default="hgt_visualization")
    ap.add_argument("--condition-matrix", default=None, help="Condition2 or Condition1 donor count matrix")
    ap.add_argument("--event-summary", default=None, help="M1/M2 summary evolution TSV")
    ap.add_argument("--source-breakdown", default=None, help="M1/M2 HGT source breakdown TSV")
    args = ap.parse_args()

    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    manifest = []

    if args.condition_matrix:
        long_rows, pct_rows = read_condition_matrix(args.condition_matrix)
        species_long = outdir / f"{args.prefix}.species_hgt_donor_counts.long.tsv"
        species_pct = outdir / f"{args.prefix}.species_hgt_donor_fractions.long.tsv"
        write_tsv(species_long, ["species", "donor_group", "hgt_count", "total_hgt"], long_rows)
        write_tsv(species_pct, ["species", "donor_group", "hgt_count", "total_hgt", "fraction"], pct_rows)
        manifest.append({"file": "species_hgt_donor_counts", "path": str(species_long), "description": "Long donor count table for species stacked bars"})
        manifest.append({"file": "species_hgt_donor_fractions", "path": str(species_pct), "description": "Long donor fraction table for species stacked bars"})

    if args.event_summary:
        node_rows = read_event_summary(args.event_summary)
        node_out = outdir / f"{args.prefix}.node_hgt_events.tsv"
        write_tsv(node_out, ["node", "parent", "gain", "expansion", "hgt_gain_expansion", "method"], node_rows)
        manifest.append({"file": "node_hgt_events", "path": str(node_out), "description": "Node gain/expansion counts for tree labels"})

    if args.source_breakdown:
        source_rows = read_source_breakdown(args.source_breakdown)
        source_out = outdir / f"{args.prefix}.node_hgt_source_breakdown.tsv"
        write_tsv(source_out, ["node", "event", "donor_group", "orthogroup_count", "method"], source_rows)
        manifest.append({"file": "node_hgt_source_breakdown", "path": str(source_out), "description": "Node donor source counts for pies or stacked bars"})

    if not manifest:
        raise SystemExit("Provide at least one of --condition-matrix, --event-summary, or --source-breakdown")
    write_tsv(outdir / f"{args.prefix}.hgt_visualization_manifest.tsv", ["file", "path", "description"], manifest)


if __name__ == "__main__":
    main()
