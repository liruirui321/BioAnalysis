#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import read_tsv, write_tsv

FIELDS = [
    "query_id", "best_donor_group", "best_donor_taxon", "refined_donor_taxon", "refined_donor_rank",
    "lineage", "taxonomy_status", "alien_index", "best_donor_bitscore", "donor_taxon_source",
]
SUMMARY_FIELDS = ["rank", "donor_taxon", "candidate_count", "donor_groups"]


def pick(row, names, default="NA"):
    for name in names:
        value = row.get(name)
        if value not in {None, "", "NA", "unknown"}:
            return value
    return default


def load_taxonomy(path, rank):
    if not path:
        return {}
    out = {}
    for row in read_tsv(path):
        key = pick(row, ["query_id", "gene_id", "transcript_id", "candidate_id", "subject_id"])
        if key == "NA":
            continue
        refined = pick(row, [rank, "refined_donor_taxon", "taxon", "name", "lineage"], "NA")
        out[key] = {
            "refined_donor_taxon": refined,
            "refined_donor_rank": rank,
            "lineage": pick(row, ["lineage", "full_lineage", "taxonomy"], "NA"),
        }
    return out


def main():
    ap = argparse.ArgumentParser(description="Refine HGT candidate donor taxonomy using local lineage/taxonomy tables.")
    ap.add_argument("--candidates", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--summary", required=True)
    ap.add_argument("--taxonomy", default=None, help="Optional local taxonomy table keyed by query/gene/candidate ID")
    ap.add_argument("--rank", default="genus", help="Preferred taxonomy rank column")
    args = ap.parse_args()

    taxonomy = load_taxonomy(args.taxonomy, args.rank)
    rows = []
    counts = Counter()
    groups = defaultdict(set)
    for cand in read_tsv(args.candidates):
        query = pick(cand, ["query_id", "gene_id", "transcript_id"])
        tax = taxonomy.get(query, {})
        refined = tax.get("refined_donor_taxon") or pick(cand, ["best_donor_taxon", "best_donor_group"], "unknown")
        rank = tax.get("refined_donor_rank", "blast2hgt_group" if not args.taxonomy else args.rank)
        status = "refined" if query in taxonomy else "group_only"
        row = {
            "query_id": query,
            "best_donor_group": pick(cand, ["best_donor_group"], "unknown"),
            "best_donor_taxon": pick(cand, ["best_donor_taxon"], "unknown"),
            "refined_donor_taxon": refined,
            "refined_donor_rank": rank,
            "lineage": tax.get("lineage", "NA"),
            "taxonomy_status": status,
            "alien_index": pick(cand, ["alien_index"], "NA"),
            "best_donor_bitscore": pick(cand, ["best_donor_bitscore"], "NA"),
            "donor_taxon_source": "taxonomy_table" if query in taxonomy else "blast2hgt",
        }
        rows.append(row)
        counts[(rank, refined)] += 1
        groups[(rank, refined)].add(row["best_donor_group"])
    summary = [
        {"rank": rank, "donor_taxon": taxon, "candidate_count": count, "donor_groups": ";".join(sorted(groups[(rank, taxon)]))}
        for (rank, taxon), count in sorted(counts.items(), key=lambda item: (-item[1], item[0]))
    ]
    write_tsv(args.out, FIELDS, rows)
    write_tsv(args.summary, SUMMARY_FIELDS, summary)


if __name__ == "__main__":
    main()
