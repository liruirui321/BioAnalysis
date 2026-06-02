#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections import defaultdict
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import iter_fasta, read_id_set, read_tsv, write_fasta, write_tsv

TIP_FIELDS = ["gene_id", "family_ids", "family_names", "gene_name", "description", "Pfam_ids", "KO_ids", "GO_terms"]


def annotation_map(path, id_column):
    out = {}
    if not path:
        return out
    for row in read_tsv(path):
        gid = row.get(id_column) or row.get("transcript_id") or row.get("gene_id")
        if gid:
            out[gid] = row
    return out


def evidence_map(path):
    fam_ids = defaultdict(set)
    fam_names = defaultdict(set)
    if not path:
        return fam_ids, fam_names
    for row in read_tsv(path):
        gid = row.get("gene_id")
        if not gid:
            continue
        fam_ids[gid].add(row.get("family_id", "NA"))
        fam_names[gid].add(row.get("family_name", row.get("family_id", "NA")))
    return fam_ids, fam_names


def main():
    ap = argparse.ArgumentParser(description="Build peptide FASTA and tree-tip metadata for target functional-family genes.")
    ap.add_argument("--target-ids", required=True)
    ap.add_argument("--peptides", required=True)
    ap.add_argument("--out-fasta", required=True)
    ap.add_argument("--tip-table", required=True)
    ap.add_argument("--functional-annotation", default=None)
    ap.add_argument("--evidence", default=None)
    ap.add_argument("--id-column", default="transcript_id")
    ap.add_argument("--missing-ids", default=None)
    args = ap.parse_args()

    targets = read_id_set(args.target_ids)
    ann = annotation_map(args.functional_annotation, args.id_column)
    fam_ids, fam_names = evidence_map(args.evidence)
    found = set()
    fasta_records = []
    for seq_id, seq in iter_fasta(args.peptides):
        if seq_id in targets:
            fasta_records.append((seq_id, seq))
            found.add(seq_id)
    write_fasta(fasta_records, args.out_fasta)

    rows = []
    for gid in sorted(targets):
        row = ann.get(gid, {})
        ko_ids = ";".join(x for x in [row.get("KEGG_ko", "NA"), row.get("Kofam_ko", "NA")] if x and x != "NA") or "NA"
        rows.append({
            "gene_id": gid,
            "family_ids": ";".join(sorted(fam_ids.get(gid, {"NA"}))),
            "family_names": ";".join(sorted(fam_names.get(gid, {"NA"}))),
            "gene_name": row.get("gene_id", gid),
            "description": row.get("SwissProt_description", row.get("NR_description", "NA")),
            "Pfam_ids": row.get("Pfam_ids", "NA"),
            "KO_ids": ko_ids,
            "GO_terms": row.get("GO_terms", "NA"),
        })
    write_tsv(args.tip_table, TIP_FIELDS, rows)
    if args.missing_ids:
        missing = sorted(targets - found)
        write_tsv(args.missing_ids, ["gene_id", "reason"], [{"gene_id": gid, "reason": "missing_from_peptide_fasta"} for gid in missing])


if __name__ == "__main__":
    main()
