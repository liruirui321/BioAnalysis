#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections import Counter
from pathlib import Path
import re
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import iter_fasta, write_tsv

FIELDS = [
    "domain_id", "seqid", "start", "end", "strand", "class_path", "class_level_1",
    "class_level_2", "class_level_3", "domain_gene", "domain_type", "source_header",
]
SUMMARY_FIELDS = ["class_level_1", "class_level_2", "class_level_3", "domain_type", "count"]


def split_class(value: str) -> tuple[str, str, str]:
    if not value or value == "NA":
        return "NA", "NA", "NA"
    parts = value.replace("-", "/").split("/")
    return (parts + ["NA", "NA", "NA"])[:3]


def domain_type(gene: str) -> str:
    upper = gene.upper()
    if upper == "RT" or "RVT" in upper:
        return "RT"
    if "TPASE" in upper or "TRANSPOSASE" in upper or "DDE" in upper:
        return "TPase"
    return gene if gene else "NA"


def parse_header(header: str) -> dict[str, str]:
    token = header.split()[0]
    token = token.lstrip(">")
    seqid = start = end = strand = "NA"
    m = re.match(r"([^:|]+):(\d+)-(\d+)", token)
    if m:
        seqid, start, end = m.group(1), m.group(2), m.group(3)
    elif ":" in token and "-" in token:
        loc = token.split("|", 1)[0]
        m = re.match(r"([^:]+):(\d+)-(\d+)", loc)
        if m:
            seqid, start, end = m.group(1), m.group(2), m.group(3)
    strand_match = re.search(r"(?:strand|Strand)=([+-])", header)
    if strand_match:
        strand = strand_match.group(1)
    gene_match = re.search(r"(?:gene|Gene)=([^;\s]+)", header)
    gene = gene_match.group(1) if gene_match else "NA"
    class_match = re.search(r"Classification=([^;\s]+)", header)
    class_tail = class_match.group(1) if class_match else "NA"
    class_prefix = "NA"
    if "|" in token:
        after_pipe = token.split("|", 1)[1]
        class_prefix = after_pipe.split("/", 1)[0] if after_pipe else "NA"
    class_path = class_tail if class_prefix == "NA" else f"{class_prefix}/{class_tail}"
    c1, c2, c3 = split_class(class_path)
    return {
        "domain_id": token,
        "seqid": seqid,
        "start": start,
        "end": end,
        "strand": strand,
        "class_path": class_path,
        "class_level_1": c1,
        "class_level_2": c2,
        "class_level_3": c3,
        "domain_gene": gene,
        "domain_type": domain_type(gene),
        "source_header": header,
    }


def main():
    ap = argparse.ArgumentParser(description="Parse TEsorter domain FASTA headers into normalized TE/domain tables.")
    ap.add_argument("--domains", required=True, help="TEsorter domain FASTA, commonly rexdb.dom.faa")
    ap.add_argument("--out", required=True)
    ap.add_argument("--summary", required=True)
    args = ap.parse_args()

    rows = [parse_header(header) for header, _seq in iter_fasta(args.domains)]
    counts = Counter((r["class_level_1"], r["class_level_2"], r["class_level_3"], r["domain_type"]) for r in rows)
    summary = [
        {"class_level_1": k[0], "class_level_2": k[1], "class_level_3": k[2], "domain_type": k[3], "count": v}
        for k, v in sorted(counts.items())
    ]
    write_tsv(args.out, FIELDS, rows)
    write_tsv(args.summary, SUMMARY_FIELDS, summary)


if __name__ == "__main__":
    main()
