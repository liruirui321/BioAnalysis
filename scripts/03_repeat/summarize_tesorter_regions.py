#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import open_text, read_tsv, write_tsv

OUT_FIELDS = [
    "region_status", "class_level_1", "class_level_2", "class_level_3", "domain_type",
    "domain_count", "unique_loci", "covered_bp",
]
DETAIL_FIELDS = [
    "domain_id", "seqid", "start", "end", "region_status", "class_path", "domain_type", "overlap_bp",
]


def read_bed(path: str | None):
    regions = defaultdict(list)
    if not path:
        return regions
    with open_text(path) as handle:
        for line in handle:
            if not line.strip() or line.startswith("#"):
                continue
            cols = line.rstrip("\n").split("\t")
            if len(cols) < 3:
                continue
            regions[cols[0]].append((int(cols[1]), int(cols[2])))
    return regions


def overlap_bp(seqid: str, start: int, end: int, regions) -> int:
    total = 0
    for r_start, r_end in regions.get(seqid, []):
        total += max(0, min(end, r_end) - max(start, r_start))
    return total


def to_int(value, default=None):
    try:
        return int(float(value))
    except (TypeError, ValueError):
        return default


def classify(row, target_regions, background_regions):
    seqid = row.get("seqid", "NA")
    start = to_int(row.get("start"))
    end = to_int(row.get("end"))
    if seqid == "NA" or start is None or end is None:
        return "missing_coordinates", 0
    start0 = max(0, start - 1)
    target_overlap = overlap_bp(seqid, start0, end, target_regions)
    if target_overlap > 0:
        return "target", target_overlap
    if background_regions:
        background_overlap = overlap_bp(seqid, start0, end, background_regions)
        if background_overlap > 0:
            return "background", background_overlap
        return "outside_background", 0
    return "background", 0


def main():
    ap = argparse.ArgumentParser(description="Summarize parsed TEsorter domains in target regions versus background regions.")
    ap.add_argument("--domains", required=True, help="Parsed domain TSV from parse_tesorter_domains.py")
    ap.add_argument("--target-bed", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--details", default=None)
    ap.add_argument("--background-bed", default=None)
    args = ap.parse_args()

    target_regions = read_bed(args.target_bed)
    background_regions = read_bed(args.background_bed)
    counts = Counter()
    loci = defaultdict(set)
    bp = defaultdict(int)
    details = []

    for row in read_tsv(args.domains):
        status, ov = classify(row, target_regions, background_regions)
        key = (status, row.get("class_level_1", "NA"), row.get("class_level_2", "NA"), row.get("class_level_3", "NA"), row.get("domain_type", "NA"))
        counts[key] += 1
        loci[key].add((row.get("seqid", "NA"), row.get("start", "NA"), row.get("end", "NA")))
        bp[key] += ov
        details.append({
            "domain_id": row.get("domain_id", "NA"),
            "seqid": row.get("seqid", "NA"),
            "start": row.get("start", "NA"),
            "end": row.get("end", "NA"),
            "region_status": status,
            "class_path": row.get("class_path", "NA"),
            "domain_type": row.get("domain_type", "NA"),
            "overlap_bp": ov,
        })

    summary = []
    for key, count in sorted(counts.items()):
        summary.append({
            "region_status": key[0],
            "class_level_1": key[1],
            "class_level_2": key[2],
            "class_level_3": key[3],
            "domain_type": key[4],
            "domain_count": count,
            "unique_loci": len(loci[key]),
            "covered_bp": bp[key],
        })
    write_tsv(args.out, OUT_FIELDS, summary)
    if args.details:
        write_tsv(args.details, DETAIL_FIELDS, details)


if __name__ == "__main__":
    main()
