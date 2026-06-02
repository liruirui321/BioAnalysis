#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections import defaultdict
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import open_text, read_tsv, write_tsv

FIELDS = ["region_set", "regions", "region_bp", "syntenic_genes", "synteny_links", "covered_target_regions", "syntenic_gene_rate_per_mb"]
DETAIL_FIELDS = ["region_set", "region_id", "seqid", "start0", "end", "gene_id", "synteny_links"]


def to_int(value, default=None):
    try:
        return int(float(value))
    except (TypeError, ValueError):
        return default


def read_bed(path, label):
    regions = defaultdict(list)
    with open_text(path) as handle:
        for i, line in enumerate(handle, start=1):
            if not line.strip() or line.startswith("#"):
                continue
            cols = line.rstrip("\n").split("\t")
            if len(cols) < 3:
                continue
            start = to_int(cols[1])
            end = to_int(cols[2])
            if start is None or end is None or end <= start:
                continue
            regions[cols[0]].append({"id": cols[3] if len(cols) > 3 and cols[3] else f"{label}_{i}", "seqid": cols[0], "start0": start, "end": end})
    return regions


def read_gene_bed(path):
    genes = defaultdict(list)
    with open_text(path) as handle:
        for line in handle:
            if not line.strip() or line.startswith("#"):
                continue
            cols = line.rstrip("\n").split("\t")
            if len(cols) < 4:
                continue
            start = to_int(cols[1])
            end = to_int(cols[2])
            if start is None or end is None or end <= start:
                continue
            genes[cols[0]].append({"gene_id": cols[3], "seqid": cols[0], "start0": start, "end": end})
    return genes


def synteny_counts(path):
    counts = defaultdict(int)
    for row in read_tsv(path):
        for key in ["ref_gene", "query_gene"]:
            gene = row.get(key)
            if gene and gene != "NA":
                counts[gene] += 1
    return counts


def summarize(label, regions, genes, link_counts):
    detail = []
    syntenic_genes = set()
    total_links = 0
    covered_regions = set()
    region_count = 0
    region_bp = 0
    for seqid, seq_regions in regions.items():
        seq_genes = genes.get(seqid, [])
        for region in seq_regions:
            region_count += 1
            region_bp += region["end"] - region["start0"]
            for gene in seq_genes:
                if max(region["start0"], gene["start0"]) >= min(region["end"], gene["end"]):
                    continue
                links = link_counts.get(gene["gene_id"], 0)
                if links <= 0:
                    continue
                syntenic_genes.add(gene["gene_id"])
                total_links += links
                covered_regions.add(region["id"])
                detail.append({
                    "region_set": label,
                    "region_id": region["id"],
                    "seqid": seqid,
                    "start0": region["start0"],
                    "end": region["end"],
                    "gene_id": gene["gene_id"],
                    "synteny_links": links,
                })
    summary = {
        "region_set": label,
        "regions": region_count,
        "region_bp": region_bp,
        "syntenic_genes": len(syntenic_genes),
        "synteny_links": total_links,
        "covered_target_regions": len(covered_regions),
        "syntenic_gene_rate_per_mb": f"{len(syntenic_genes) / (region_bp / 1_000_000):.6f}" if region_bp else "0",
    }
    return summary, detail


def main():
    ap = argparse.ArgumentParser(description="Compare synteny support in target regions versus optional background regions.")
    ap.add_argument("--synteny", required=True, help="Normalized synteny detail TSV")
    ap.add_argument("--gene-bed", required=True, help="Gene BED with gene ID in column 4")
    ap.add_argument("--target-bed", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--details", default=None)
    ap.add_argument("--background-bed", default=None)
    args = ap.parse_args()

    genes = read_gene_bed(args.gene_bed)
    counts = synteny_counts(args.synteny)
    rows = []
    details = []
    target_summary, target_details = summarize("target", read_bed(args.target_bed, "target"), genes, counts)
    rows.append(target_summary)
    details.extend(target_details)
    if args.background_bed:
        bg_summary, bg_details = summarize("background", read_bed(args.background_bed, "background"), genes, counts)
        rows.append(bg_summary)
        details.extend(bg_details)
    write_tsv(args.out, FIELDS, rows)
    if args.details:
        write_tsv(args.details, DETAIL_FIELDS, details)


if __name__ == "__main__":
    main()
