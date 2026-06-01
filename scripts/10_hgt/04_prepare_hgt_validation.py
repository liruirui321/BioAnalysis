#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections import defaultdict
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import read_tsv, write_lines, write_tsv


def main():
    ap = argparse.ArgumentParser(description="Prepare HGT candidate validation handoff files for phylogenetic review.")
    ap.add_argument("--context", required=True, help="HGT context TSV from 03_add_hgt_context.py")
    ap.add_argument("--classified-hits", required=True, help="Classified hits from 01_classify_hgt_hits.py")
    ap.add_argument("--outdir", required=True)
    ap.add_argument("--top-donor-hits", type=int, default=5)
    args = ap.parse_args()

    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    candidates = [row for row in read_tsv(args.context) if row.get("validation_priority") in {"high", "review"}]
    candidate_ids = [row["query_id"] for row in candidates]
    write_lines(outdir / "hgt_candidate.ids", candidate_ids)

    donor_by_query = defaultdict(list)
    for row in read_tsv(args.classified_hits):
        if row.get("hit_class") == "donor":
            donor_by_query[row["query_id"]].append(row)

    donor_ids = []
    manifest = []
    for row in candidates:
        query = row["query_id"]
        donors = sorted(donor_by_query.get(query, []), key=lambda r: (-float(r.get("bitscore", 0)), float(r.get("evalue", 1))))[:args.top_donor_hits]
        ids = [hit["subject_id"] for hit in donors]
        donor_ids.extend(ids)
        manifest.append({
            "query_id": query,
            "candidate_id_file": "hgt_candidate.ids",
            "top_donor_subject_ids": ",".join(ids) if ids else "NA",
            "recommended_validation": "build candidate homolog tree with scripts/06_phylogeny workflow",
            "validation_priority": row.get("validation_priority", "review"),
            "missing_data_note": row.get("missing_data_note", "NA"),
        })

    write_lines(outdir / "hgt_candidate_top_donor_subject.ids", sorted(set(donor_ids)))
    write_tsv(outdir / "hgt_candidate_validation_manifest.tsv", [
        "query_id", "candidate_id_file", "top_donor_subject_ids", "recommended_validation",
        "validation_priority", "missing_data_note",
    ], manifest)


if __name__ == "__main__":
    main()
