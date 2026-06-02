#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections import defaultdict
from pathlib import Path
import re
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import read_tsv, write_tsv

DETAIL_FIELDS = [
    "gene_id", "target_family_id", "target_family_name", "orthogroup_id", "evidence_types",
    "evolution_status", "event_nodes", "gain", "loss", "expansion", "contraction", "missing_data_note",
]
SUMMARY_FIELDS = [
    "target_family_id", "target_family_name", "selected_genes", "orthogroups", "genes_with_evolution_signal",
    "gain_nodes", "loss_nodes", "expansion_nodes", "contraction_nodes", "missing_data_note",
]


def split_members(value):
    if not value or value == "NA":
        return []
    return [part.strip() for part in re.split(r"[,;]\s*", value) if part.strip()]


def to_float(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0.0


def read_orthogroups(path):
    if not path:
        return {}
    mapping = defaultdict(set)
    for row in read_tsv(path):
        orthogroup = row.get("Orthogroup") or row.get("orthogroup") or row.get("family_id") or row.get("Family ID")
        if not orthogroup:
            continue
        for key, value in row.items():
            if key in {"Orthogroup", "orthogroup", "family_id", "Family ID"}:
                continue
            for gene in split_members(value):
                mapping[gene].add(orthogroup)
    return mapping


def read_target_evidence(path):
    genes = defaultdict(lambda: {"family_ids": set(), "family_names": set(), "evidence_types": set()})
    for row in read_tsv(path):
        gene = row.get("gene_id")
        if not gene:
            continue
        genes[gene]["family_ids"].add(row.get("family_id", "NA"))
        genes[gene]["family_names"].add(row.get("family_name", row.get("family_id", "NA")))
        genes[gene]["evidence_types"].add(row.get("evidence_type", "NA"))
    return genes


def read_events(path):
    events = defaultdict(list)
    if not path:
        return events
    for row in read_tsv(path):
        family = row.get("family_id") or row.get("orthogroup_id") or row.get("Family ID")
        if family:
            events[family].append(row)
    return events


def summarize_events(event_rows):
    totals = {"gain": 0.0, "loss": 0.0, "expansion": 0.0, "contraction": 0.0}
    nodes = {"gain": set(), "loss": set(), "expansion": set(), "contraction": set()}
    for row in event_rows:
        node = row.get("node_label") or row.get("node_id") or row.get("node") or "NA"
        for metric in totals:
            value = to_float(row.get(metric))
            totals[metric] += value
            if value > 0:
                nodes[metric].add(node)
    status = [metric for metric, value in totals.items() if value > 0]
    return totals, nodes, ";".join(status) if status else "no_change"


def main():
    ap = argparse.ArgumentParser(description="Integrate target-family evidence with orthogroups and Count/CAFE gain-loss outputs.")
    ap.add_argument("--target-evidence", required=True)
    ap.add_argument("--out", required=True, help="Gene-level target-family evolution table")
    ap.add_argument("--summary", required=True)
    ap.add_argument("--orthogroups", default=None, help="OrthoFinder Orthogroups.tsv or compatible membership table")
    ap.add_argument("--family-gain-loss", default=None, help="Family/node gain-loss table from Stage 08")
    args = ap.parse_args()

    targets = read_target_evidence(args.target_evidence)
    gene_to_og = read_orthogroups(args.orthogroups)
    event_by_family = read_events(args.family_gain_loss)
    detail = []
    grouped = defaultdict(list)

    for gene, meta in sorted(targets.items()):
        family_ids = sorted(meta["family_ids"])
        family_names = sorted(meta["family_names"])
        orthogroups = sorted(gene_to_og.get(gene, [])) or ["NA"]
        for family_id, family_name in zip(family_ids, family_names):
            for orthogroup in orthogroups:
                event_rows = event_by_family.get(orthogroup, []) if orthogroup != "NA" else []
                totals, nodes, status = summarize_events(event_rows)
                missing = []
                if not args.orthogroups:
                    missing.append("orthogroups")
                elif orthogroup == "NA":
                    missing.append("orthogroup_assignment")
                if not args.family_gain_loss:
                    missing.append("family_gain_loss")
                elif not event_rows:
                    missing.append("orthogroup_evolution_event")
                row = {
                    "gene_id": gene,
                    "target_family_id": family_id,
                    "target_family_name": family_name,
                    "orthogroup_id": orthogroup,
                    "evidence_types": ";".join(sorted(meta["evidence_types"])),
                    "evolution_status": status if not missing else "missing" if status == "no_change" else status,
                    "event_nodes": ";".join(sorted(set().union(*nodes.values()))) if event_rows else "NA",
                    "gain": f"{totals['gain']:.6g}",
                    "loss": f"{totals['loss']:.6g}",
                    "expansion": f"{totals['expansion']:.6g}",
                    "contraction": f"{totals['contraction']:.6g}",
                    "missing_data_note": ";".join(missing) if missing else "none",
                }
                detail.append(row)
                grouped[(family_id, family_name)].append(row)

    summary = []
    for (family_id, family_name), rows in sorted(grouped.items()):
        with_signal = [row for row in rows if row["evolution_status"] not in {"no_change", "missing"}]
        summary.append({
            "target_family_id": family_id,
            "target_family_name": family_name,
            "selected_genes": len({row["gene_id"] for row in rows}),
            "orthogroups": len({row["orthogroup_id"] for row in rows if row["orthogroup_id"] != "NA"}),
            "genes_with_evolution_signal": len({row["gene_id"] for row in with_signal}),
            "gain_nodes": ";".join(sorted({node for row in rows if to_float(row["gain"]) > 0 for node in split_members(row["event_nodes"])})) or "NA",
            "loss_nodes": ";".join(sorted({node for row in rows if to_float(row["loss"]) > 0 for node in split_members(row["event_nodes"])})) or "NA",
            "expansion_nodes": ";".join(sorted({node for row in rows if to_float(row["expansion"]) > 0 for node in split_members(row["event_nodes"])})) or "NA",
            "contraction_nodes": ";".join(sorted({node for row in rows if to_float(row["contraction"]) > 0 for node in split_members(row["event_nodes"])})) or "NA",
            "missing_data_note": ";".join(sorted({row["missing_data_note"] for row in rows if row["missing_data_note"] != "none"})) or "none",
        })

    write_tsv(args.out, DETAIL_FIELDS, detail)
    write_tsv(args.summary, SUMMARY_FIELDS, summary)


if __name__ == "__main__":
    main()
