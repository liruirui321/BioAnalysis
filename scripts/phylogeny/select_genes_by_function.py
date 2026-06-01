#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import read_tsv, read_id_set, write_lines, write_tsv


def split_terms(v):
    if not v or v == "NA":
        return set()
    return {x for x in re.split(r"[;,| ]+", v) if x and x != "NA"}


def main():
    ap = argparse.ArgumentParser(description="Select gene/transcript IDs by Pfam, KO, keyword, or candidate list from functional_annotation.tsv.")
    ap.add_argument("--annotation", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--summary", default=None)
    ap.add_argument("--id-column", default="transcript_id")
    ap.add_argument("--pfam", default=None, help="Comma-separated Pfam IDs")
    ap.add_argument("--ko", default=None, help="Comma-separated KO IDs")
    ap.add_argument("--keyword", default=None, help="Case-insensitive keyword regex searched across annotation fields")
    ap.add_argument("--candidate-list", default=None)
    args = ap.parse_args()
    pfams = set(args.pfam.split(",")) if args.pfam else set()
    kos = set(args.ko.split(",")) if args.ko else set()
    candidates = read_id_set(args.candidate_list) if args.candidate_list else set()
    rx = re.compile(args.keyword, re.I) if args.keyword else None
    rows = read_tsv(args.annotation)
    selected = []
    reasons = []
    for r in rows:
        tid = r.get(args.id_column) or r.get("transcript_id") or r.get("gene_id")
        if not tid:
            continue
        reason = []
        if pfams and split_terms(r.get("Pfam_ids", "")) & pfams:
            reason.append("pfam")
        ko_terms = split_terms(r.get("KEGG_ko", "")) | split_terms(r.get("Kofam_ko", "")) | split_terms(r.get("KO_ids", ""))
        if kos and ko_terms & kos:
            reason.append("ko")
        if rx and rx.search("\t".join(r.values())):
            reason.append("keyword")
        if candidates and (tid in candidates or r.get("gene_id") in candidates):
            reason.append("candidate")
        if reason:
            selected.append(tid)
            reasons.append({"id": tid, "gene_id": r.get("gene_id", "NA"), "reason": ";".join(reason)})
    write_lines(args.out, sorted(dict.fromkeys(selected)))
    if args.summary:
        write_tsv(args.summary, ["id", "gene_id", "reason"], reasons)


if __name__ == "__main__":
    main()
