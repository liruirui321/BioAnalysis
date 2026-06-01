#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections import defaultdict
from pathlib import Path
import re
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import read_tsv, write_tsv


def split_terms(value: str) -> list[str]:
    if not value or value == "NA":
        return []
    return sorted({part.strip() for part in re.split(r"[;,|]\s*", value) if part.strip()})


def load_names(path):
    if not path:
        return {}
    names = {}
    for row in read_tsv(path):
        pid = row.get("pfam_id") or row.get("Pfam") or row.get("Subject_id")
        name = row.get("pfam_name") or row.get("Description") or row.get("Subject_annotation") or "NA"
        if pid:
            names[pid] = name
    return names


def main():
    ap = argparse.ArgumentParser(description="Summarize Pfam/domain assignments from functional_annotation.tsv.")
    ap.add_argument("--annotation", required=True)
    ap.add_argument("--out", required=True, help="Pfam count summary TSV")
    ap.add_argument("--gene2pfam", required=True, help="Long gene-to-Pfam TSV")
    ap.add_argument("--id-column", default="transcript_id")
    ap.add_argument("--term-column", default="Pfam_ids")
    ap.add_argument("--pfam-map", default=None, help="Optional Pfam name map TSV")
    args = ap.parse_args()

    names = load_names(args.pfam_map)
    gene_rows = []
    by_pfam = defaultdict(set)
    for row in read_tsv(args.annotation):
        gid = row.get(args.id_column, "NA")
        if gid == "NA":
            continue
        for pfam in split_terms(row.get(args.term_column, "NA")):
            by_pfam[pfam].add(gid)
            gene_rows.append({"gene_id": gid, "pfam_id": pfam, "pfam_name": names.get(pfam, "NA")})

    summary = [
        {"pfam_id": pfam, "pfam_name": names.get(pfam, "NA"), "gene_count": len(ids), "genes": ";".join(sorted(ids))}
        for pfam, ids in sorted(by_pfam.items(), key=lambda item: (-len(item[1]), item[0]))
    ]
    write_tsv(args.gene2pfam, ["gene_id", "pfam_id", "pfam_name"], gene_rows)
    write_tsv(args.out, ["pfam_id", "pfam_name", "gene_count", "genes"], summary)


if __name__ == "__main__":
    main()
