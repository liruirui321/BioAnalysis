#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections import defaultdict
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import read_tsv, write_tsv


def to_int(value, default=0):
    try:
        return int(float(value))
    except (TypeError, ValueError):
        return default


def main():
    ap = argparse.ArgumentParser(description="Summarize ordered Pfam domain architectures from parsed InterProScan output.")
    ap.add_argument("--iprscan", required=True, help="Parsed InterProScan table from parse_interproscan_tsv.py")
    ap.add_argument("--out", required=True, help="Per-query domain architecture TSV")
    ap.add_argument("--summary", required=True, help="Architecture frequency summary TSV")
    args = ap.parse_args()

    by_query = defaultdict(list)
    desc = {}
    for row in read_tsv(args.iprscan):
        if row.get("Subject_DB") != "Pfam":
            continue
        qid = row.get("Query_id", "NA")
        pfam = row.get("Subject_id", "NA")
        if qid == "NA" or pfam == "NA":
            continue
        by_query[qid].append({
            "pfam_id": pfam,
            "start": to_int(row.get("Query_start")),
            "end": to_int(row.get("Query_end")),
        })
        desc.setdefault(pfam, row.get("Subject_annotation", "NA"))

    rows = []
    arch_counts = defaultdict(set)
    for qid, domains in sorted(by_query.items()):
        domains.sort(key=lambda d: (d["start"], d["end"], d["pfam_id"]))
        pfams = [d["pfam_id"] for d in domains]
        architecture = "|".join(pfams)
        spans = ";".join(f"{d['pfam_id']}:{d['start']}-{d['end']}" for d in domains)
        arch_counts[architecture].add(qid)
        rows.append({
            "Query_id": qid,
            "domain_architecture": architecture,
            "domain_count": len(domains),
            "Pfam_ids_ordered": ";".join(pfams),
            "domain_spans": spans,
        })

    summary = [
        {"domain_architecture": arch, "gene_count": len(ids), "genes": ";".join(sorted(ids))}
        for arch, ids in sorted(arch_counts.items(), key=lambda item: (-len(item[1]), item[0]))
    ]
    write_tsv(args.out, ["Query_id", "domain_architecture", "domain_count", "Pfam_ids_ordered", "domain_spans"], rows)
    write_tsv(args.summary, ["domain_architecture", "gene_count", "genes"], summary)


if __name__ == "__main__":
    main()
