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
    terms = []
    for part in re.split(r"[;,|]\s*", value):
        part = part.strip()
        if part:
            terms.append(part)
    return sorted(set(terms))


def main():
    ap = argparse.ArgumentParser(description="Summarize GO terms from functional_annotation.tsv.")
    ap.add_argument("--annotation", required=True)
    ap.add_argument("--out", required=True, help="GO term count summary TSV")
    ap.add_argument("--gene2go", required=True, help="Long gene-to-GO TSV")
    ap.add_argument("--id-column", default="transcript_id")
    ap.add_argument("--term-column", default="GO_terms")
    args = ap.parse_args()

    gene_rows = []
    by_term = defaultdict(set)
    total_ids = set()
    for row in read_tsv(args.annotation):
        gid = row.get(args.id_column, "NA")
        if gid == "NA":
            continue
        total_ids.add(gid)
        for term in split_terms(row.get(args.term_column, "NA")):
            by_term[term].add(gid)
            gene_rows.append({"gene_id": gid, "go_term": term})

    summary = [
        {"go_term": term, "gene_count": len(ids), "genes": ";".join(sorted(ids))}
        for term, ids in sorted(by_term.items(), key=lambda item: (-len(item[1]), item[0]))
    ]
    write_tsv(args.gene2go, ["gene_id", "go_term"], gene_rows)
    write_tsv(args.out, ["go_term", "gene_count", "genes"], summary)


if __name__ == "__main__":
    main()
