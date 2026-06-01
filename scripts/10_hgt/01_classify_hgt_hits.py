#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import read_tsv, write_tsv

OUT_FIELDS = [
    "query_id", "subject_id", "pident", "query_coverage", "evalue", "bitscore",
    "taxid", "scientific_name", "lineage", "taxon_group", "hit_class",
]


def split_groups(value: str) -> set[str]:
    return {x.strip() for x in value.split(",") if x.strip()}


def get_first(row, names, default="NA"):
    for name in names:
        if name in row and row[name] not in {"", None}:
            return row[name]
    return default


def to_float(value, default=0.0):
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def load_taxonomy(path):
    tax = {}
    for row in read_tsv(path):
        sid = get_first(row, ["subject_id", "sseqid", "subject", "id"])
        if sid == "NA":
            continue
        tax[sid] = {
            "taxid": get_first(row, ["taxid", "staxids"]),
            "scientific_name": get_first(row, ["scientific_name", "name", "taxon_name"]),
            "lineage": get_first(row, ["lineage", "full_lineage"]),
            "taxon_group": get_first(row, ["taxon_group", "group", "lineage_group"]),
        }
    return tax


def classify(group, ingroup, donor, exclude):
    if group in exclude:
        return "exclude"
    if group in ingroup:
        return "ingroup"
    if group in donor:
        return "donor"
    return "unknown"


def main():
    ap = argparse.ArgumentParser(description="Classify BLAST/DIAMOND hits by local taxonomy groups for HGT screening.")
    ap.add_argument("--hits", required=True, help="TSV with query/subject/evalue/bitscore fields")
    ap.add_argument("--taxonomy", required=True, help="TSV mapping subject_id to taxon_group and lineage")
    ap.add_argument("--out", required=True)
    ap.add_argument("--summary", default=None)
    ap.add_argument("--ingroup-groups", required=True, help="Comma-separated host/close-relative taxon groups")
    ap.add_argument("--donor-groups", required=True, help="Comma-separated distant candidate donor taxon groups")
    ap.add_argument("--exclude-groups", default="", help="Comma-separated self/contaminant/excluded groups")
    ap.add_argument("--max-evalue", type=float, default=1e-5)
    ap.add_argument("--min-pident", type=float, default=0.0)
    ap.add_argument("--min-query-cover", type=float, default=0.0)
    args = ap.parse_args()

    taxonomy = load_taxonomy(args.taxonomy)
    ingroup = split_groups(args.ingroup_groups)
    donor = split_groups(args.donor_groups)
    exclude = split_groups(args.exclude_groups)
    rows = []
    summary = {"ingroup": 0, "donor": 0, "exclude": 0, "unknown": 0, "filtered": 0}

    for hit in read_tsv(args.hits):
        query = get_first(hit, ["query_id", "qseqid", "query"])
        subject = get_first(hit, ["subject_id", "sseqid", "subject"])
        pident = to_float(get_first(hit, ["pident", "identity"], "0"))
        evalue = to_float(get_first(hit, ["evalue", "e_value"], "1"), 1.0)
        bitscore = to_float(get_first(hit, ["bitscore", "bit_score"], "0"))
        qcov = to_float(get_first(hit, ["query_coverage", "qcovhsp", "qcov", "qcovs"], "0"))
        if evalue > args.max_evalue or pident < args.min_pident or qcov < args.min_query_cover:
            summary["filtered"] += 1
            continue
        tax = taxonomy.get(subject, {"taxid": "NA", "scientific_name": "NA", "lineage": "NA", "taxon_group": "NA"})
        hit_class = classify(tax["taxon_group"], ingroup, donor, exclude)
        summary[hit_class] += 1
        rows.append({
            "query_id": query,
            "subject_id": subject,
            "pident": f"{pident:.6f}",
            "query_coverage": f"{qcov:.6f}",
            "evalue": evalue,
            "bitscore": f"{bitscore:.6f}",
            "taxid": tax["taxid"],
            "scientific_name": tax["scientific_name"],
            "lineage": tax["lineage"],
            "taxon_group": tax["taxon_group"],
            "hit_class": hit_class,
        })

    rows.sort(key=lambda r: (r["query_id"], -float(r["bitscore"]), float(r["evalue"])))
    write_tsv(args.out, OUT_FIELDS, rows)
    if args.summary:
        write_tsv(args.summary, ["metric", "value"], [{"metric": k, "value": v} for k, v in sorted(summary.items())])


if __name__ == "__main__":
    main()
