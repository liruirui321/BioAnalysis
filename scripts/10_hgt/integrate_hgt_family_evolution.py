#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections import defaultdict
from pathlib import Path
import re
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import read_tsv, write_tsv

FIELDS = [
    "query_id", "gene_id", "best_donor_group", "refined_donor_taxon", "orthogroup_id",
    "target_family_status", "target_family_ids", "evolution_status", "event_nodes",
    "alien_index", "bitscore_delta", "missing_data_note",
]
SUMMARY_FIELDS = ["category", "value", "candidate_count"]


def split_members(value):
    if not value or value == "NA":
        return []
    return [part.strip() for part in re.split(r"[,;]\s*", value) if part.strip()]


def pick(row, names, default="NA"):
    for name in names:
        value = row.get(name)
        if value not in {None, "", "NA"}:
            return value
    return default


def to_float(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0.0


def read_orthogroups(path):
    mapping = defaultdict(set)
    if not path:
        return mapping
    for row in read_tsv(path):
        og = pick(row, ["Orthogroup", "orthogroup", "family_id", "Family ID"])
        if og == "NA":
            continue
        for key, value in row.items():
            if key in {"Orthogroup", "orthogroup", "family_id", "Family ID"}:
                continue
            for gene in split_members(value):
                mapping[gene].add(og)
    return mapping


def read_target(path):
    mapping = defaultdict(set)
    if not path:
        return mapping
    for row in read_tsv(path):
        gene = row.get("gene_id")
        if gene:
            mapping[gene].add(row.get("family_id", "NA"))
    return mapping


def read_events(path):
    events = defaultdict(list)
    if not path:
        return events
    for row in read_tsv(path):
        family = pick(row, ["family_id", "orthogroup_id", "Family ID"])
        if family != "NA":
            events[family].append(row)
    return events


def event_status(rows):
    if not rows:
        return "missing", "NA"
    statuses = []
    nodes = set()
    for row in rows:
        node = pick(row, ["node_label", "node_id", "node"], "NA")
        for metric in ["gain", "loss", "expansion", "contraction"]:
            if to_float(row.get(metric)) > 0:
                statuses.append(metric)
                nodes.add(node)
    return ";".join(sorted(set(statuses))) if statuses else "no_change", ";".join(sorted(nodes)) if nodes else "NA"


def read_refined(path):
    if not path:
        return {}
    return {pick(row, ["query_id", "gene_id"]): row for row in read_tsv(path)}


def main():
    ap = argparse.ArgumentParser(description="Integrate HGT candidates with orthogroups, target-family evidence, and family-evolution events.")
    ap.add_argument("--candidates", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--summary", required=True)
    ap.add_argument("--refined-donors", default=None)
    ap.add_argument("--orthogroups", default=None)
    ap.add_argument("--target-evidence", default=None)
    ap.add_argument("--family-gain-loss", default=None)
    args = ap.parse_args()

    refined = read_refined(args.refined_donors)
    gene_to_og = read_orthogroups(args.orthogroups)
    target = read_target(args.target_evidence)
    events = read_events(args.family_gain_loss)
    rows = []
    counts = defaultdict(int)

    for cand in read_tsv(args.candidates):
        query = pick(cand, ["query_id", "gene_id", "transcript_id"])
        gene = pick(cand, ["gene_id", "query_id", "transcript_id"], query)
        donor = refined.get(query, {})
        orthogroups = sorted(gene_to_og.get(query) or gene_to_og.get(gene) or []) or ["NA"]
        target_fams = sorted(target.get(query) or target.get(gene) or [])
        missing_base = []
        if not args.orthogroups:
            missing_base.append("orthogroups")
        if not args.target_evidence:
            missing_base.append("target_evidence")
        if not args.family_gain_loss:
            missing_base.append("family_gain_loss")
        if not args.refined_donors:
            missing_base.append("refined_donors")
        for og in orthogroups:
            status, nodes = event_status(events.get(og, [])) if og != "NA" else ("missing", "NA")
            missing = list(missing_base)
            if og == "NA":
                missing.append("orthogroup_assignment")
            if status == "missing" and args.family_gain_loss:
                missing.append("orthogroup_evolution_event")
            row = {
                "query_id": query,
                "gene_id": gene,
                "best_donor_group": pick(donor, ["best_donor_group"], pick(cand, ["best_donor_group"], "NA")),
                "refined_donor_taxon": pick(donor, ["refined_donor_taxon"], pick(cand, ["best_donor_taxon", "best_donor_group"], "NA")),
                "orthogroup_id": og,
                "target_family_status": "target_family" if target_fams else "not_target_family",
                "target_family_ids": ";".join(target_fams) if target_fams else "NA",
                "evolution_status": status,
                "event_nodes": nodes,
                "alien_index": pick(cand, ["alien_index"], "NA"),
                "bitscore_delta": pick(cand, ["bitscore_delta"], "NA"),
                "missing_data_note": ";".join(sorted(set(missing))) if missing else "none",
            }
            rows.append(row)
            counts[("donor_group", row["best_donor_group"])] += 1
            counts[("target_family_status", row["target_family_status"])] += 1
            counts[("evolution_status", row["evolution_status"])] += 1
    summary = [{"category": cat, "value": value, "candidate_count": count} for (cat, value), count in sorted(counts.items())]
    write_tsv(args.out, FIELDS, rows)
    write_tsv(args.summary, SUMMARY_FIELDS, summary)


if __name__ == "__main__":
    main()
