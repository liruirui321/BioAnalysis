#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import iter_fasta, read_id_set, read_tsv, write_tsv


def ann_map(path):
    return {r.get("transcript_id", r.get("gene_id", "")): r for r in read_tsv(path)} if path else {}


def main():
    ap = argparse.ArgumentParser(description="Build tip annotation table for function-driven gene trees.")
    ap.add_argument("--target-ids", required=True)
    ap.add_argument("--outgroup-ids", default=None)
    ap.add_argument("--marker-fasta", default=None)
    ap.add_argument("--functional-annotation", default=None)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    targets = read_id_set(args.target_ids)
    outgroups = read_id_set(args.outgroup_ids) if args.outgroup_ids else set()
    ann = ann_map(args.functional_annotation)
    rows = []
    for tid in sorted(targets):
        a = ann.get(tid, {})
        rows.append({"tip_id": tid, "source_group": "target", "species": a.get("species", "NA"), "transcript_id": tid, "gene_id": a.get("gene_id", "NA"), "Pfam_ids": a.get("Pfam_ids", "NA"), "KO_ids": a.get("KEGG_ko", a.get("Kofam_ko", "NA")), "note": "NA"})
    for tid in sorted(outgroups):
        rows.append({"tip_id": tid, "source_group": "outgroup", "species": "outgroup", "transcript_id": tid, "gene_id": "NA", "Pfam_ids": "NA", "KO_ids": "NA", "note": "NA"})
    if args.marker_fasta:
        for tid, _ in iter_fasta(args.marker_fasta):
            rows.append({"tip_id": tid, "source_group": "marker_or_maker", "species": "NA", "transcript_id": tid, "gene_id": "NA", "Pfam_ids": "NA", "KO_ids": "NA", "note": "marker_or_maker"})
    fields = ["tip_id", "source_group", "species", "transcript_id", "gene_id", "Pfam_ids", "KO_ids", "note"]
    write_tsv(args.out, fields, rows)


if __name__ == "__main__":
    main()
