#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections import defaultdict
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import read_tsv, write_tsv


def to_float(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0.0


def load_family_summary(path):
    if not path:
        return {}
    return {row.get("family_id", row.get("Family ID", "NA")): row for row in read_tsv(path)}


def main():
    ap = argparse.ArgumentParser(description="Summarize Count gain/loss calls by family and node.")
    ap.add_argument("--count-gain-loss", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--node-summary", required=True)
    ap.add_argument("--family-summary", default=None)
    ap.add_argument("--functional-annotation", default=None, help="Reserved for downstream annotation joins")
    args = ap.parse_args()

    family_meta = load_family_summary(args.family_summary)
    family_rows = []
    node_totals = defaultdict(lambda: {"gain": 0.0, "loss": 0.0, "expansion": 0.0, "contraction": 0.0, "families": set()})

    for row in read_tsv(args.count_gain_loss):
        fam = row.get("family_id", "NA")
        node = row.get("node_label") or row.get("node_id", "NA")
        gain = to_float(row.get("gain"))
        loss = to_float(row.get("loss"))
        expansion = to_float(row.get("expansion"))
        contraction = to_float(row.get("contraction"))
        status = []
        if gain > 0:
            status.append("gain")
        if loss > 0:
            status.append("loss")
        if expansion > 0:
            status.append("expansion")
        if contraction > 0:
            status.append("contraction")
        meta = family_meta.get(fam, {})
        family_rows.append({
            "family_id": fam,
            "node_label": node,
            "gain": gain,
            "loss": loss,
            "expansion": expansion,
            "contraction": contraction,
            "inferred_count": row.get("inferred_count", "NA"),
            "event_status": ";".join(status) if status else "no_change",
            "total_copies": meta.get("total_copies", "NA"),
            "species_present": meta.get("species_present", "NA"),
            "present_species": meta.get("present_species", "NA"),
        })
        node_totals[node]["gain"] += gain
        node_totals[node]["loss"] += loss
        node_totals[node]["expansion"] += expansion
        node_totals[node]["contraction"] += contraction
        node_totals[node]["families"].add(fam)

    node_rows = []
    for node, vals in sorted(node_totals.items()):
        node_rows.append({
            "node_label": node,
            "family_count": len(vals["families"]),
            "total_gain": f"{vals['gain']:.6g}",
            "total_loss": f"{vals['loss']:.6g}",
            "total_expansion": f"{vals['expansion']:.6g}",
            "total_contraction": f"{vals['contraction']:.6g}",
        })

    write_tsv(args.out, [
        "family_id", "node_label", "gain", "loss", "expansion", "contraction", "inferred_count",
        "event_status", "total_copies", "species_present", "present_species",
    ], family_rows)
    write_tsv(args.node_summary, ["node_label", "family_count", "total_gain", "total_loss", "total_expansion", "total_contraction"], node_rows)


if __name__ == "__main__":
    main()
