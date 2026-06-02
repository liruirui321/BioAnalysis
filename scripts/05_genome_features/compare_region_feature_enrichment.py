#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections import defaultdict
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import open_text, parse_gff_attributes, write_tsv

SUMMARY_FIELDS = [
    "region_set", "region_count", "region_bp", "feature_count", "overlapping_features",
    "overlap_events", "covered_bp", "coverage_fraction", "feature_rate_per_mb",
    "fold_enrichment_vs_background", "qc_note",
]
DETAIL_FIELDS = [
    "region_set", "region_id", "seqid", "region_start0", "region_end", "feature_id",
    "feature_type", "feature_start0", "feature_end", "overlap_bp",
]


def to_int(value, default=None):
    try:
        return int(float(value))
    except (TypeError, ValueError):
        return default


def read_bed_regions(path, label):
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
            region_id = cols[3] if len(cols) > 3 and cols[3] else f"{label}_{i}"
            regions[cols[0]].append({"id": region_id, "seqid": cols[0], "start0": start, "end": end})
    return regions


def read_bed_features(path):
    features = defaultdict(list)
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
            feature_id = cols[3] if len(cols) > 3 and cols[3] else f"feature_{i}"
            features[cols[0]].append({
                "id": feature_id,
                "seqid": cols[0],
                "start0": start,
                "end": end,
                "type": "BED_feature",
            })
    return features


def read_gff_features(path, feature_types):
    wanted = set(feature_types.split(",")) if feature_types else None
    features = defaultdict(list)
    with open_text(path) as handle:
        for i, line in enumerate(handle, start=1):
            if not line.strip() or line.startswith("#"):
                continue
            cols = line.rstrip("\n").split("\t")
            if len(cols) < 9:
                continue
            if wanted and cols[2] not in wanted:
                continue
            start = to_int(cols[3])
            end = to_int(cols[4])
            if start is None or end is None or end < start:
                continue
            attrs = parse_gff_attributes(cols[8])
            feature_id = attrs.get("ID") or attrs.get("Name") or f"{cols[2]}_{i}"
            features[cols[0]].append({
                "id": feature_id,
                "seqid": cols[0],
                "start0": max(0, start - 1),
                "end": end,
                "type": cols[2],
            })
    return features


def merge_intervals(intervals):
    if not intervals:
        return []
    intervals = sorted(intervals)
    merged = [list(intervals[0])]
    for start, end in intervals[1:]:
        if start <= merged[-1][1]:
            merged[-1][1] = max(merged[-1][1], end)
        else:
            merged.append([start, end])
    return [(start, end) for start, end in merged]


def summarize_region_set(name, regions, features):
    region_count = sum(len(vals) for vals in regions.values())
    region_bp = sum(region["end"] - region["start0"] for vals in regions.values() for region in vals)
    feature_ids = set()
    overlap_events = 0
    covered_intervals = defaultdict(list)
    details = []

    for seqid, seq_regions in regions.items():
        seq_features = features.get(seqid, [])
        for region in seq_regions:
            for feature in seq_features:
                ov_start = max(region["start0"], feature["start0"])
                ov_end = min(region["end"], feature["end"])
                overlap = max(0, ov_end - ov_start)
                if overlap == 0:
                    continue
                feature_ids.add(feature["id"])
                overlap_events += 1
                covered_intervals[(seqid, region["id"])].append((ov_start, ov_end))
                details.append({
                    "region_set": name,
                    "region_id": region["id"],
                    "seqid": seqid,
                    "region_start0": region["start0"],
                    "region_end": region["end"],
                    "feature_id": feature["id"],
                    "feature_type": feature["type"],
                    "feature_start0": feature["start0"],
                    "feature_end": feature["end"],
                    "overlap_bp": overlap,
                })

    covered_bp = 0
    for intervals in covered_intervals.values():
        covered_bp += sum(end - start for start, end in merge_intervals(intervals))
    coverage_fraction = covered_bp / region_bp if region_bp else 0
    feature_rate = len(feature_ids) / (region_bp / 1_000_000) if region_bp else 0
    return {
        "region_set": name,
        "region_count": region_count,
        "region_bp": region_bp,
        "feature_count": sum(len(vals) for vals in features.values()),
        "overlapping_features": len(feature_ids),
        "overlap_events": overlap_events,
        "covered_bp": covered_bp,
        "coverage_fraction": coverage_fraction,
        "feature_rate_per_mb": feature_rate,
        "fold_enrichment_vs_background": "NA",
        "qc_note": "ok" if region_count and region_bp else "empty_region_set",
    }, details


def format_summary(row):
    out = dict(row)
    out["coverage_fraction"] = f"{row['coverage_fraction']:.6f}" if isinstance(row["coverage_fraction"], float) else row["coverage_fraction"]
    out["feature_rate_per_mb"] = f"{row['feature_rate_per_mb']:.6f}" if isinstance(row["feature_rate_per_mb"], float) else row["feature_rate_per_mb"]
    if isinstance(row["fold_enrichment_vs_background"], float):
        out["fold_enrichment_vs_background"] = f"{row['fold_enrichment_vs_background']:.6f}"
    return out


def main():
    ap = argparse.ArgumentParser(description="Compare target-region and optional background-region enrichment for BED or GFF features.")
    ap.add_argument("--target-bed", required=True)
    ap.add_argument("--features", required=True, help="Feature BED or GFF file")
    ap.add_argument("--feature-format", choices=["bed", "gff"], required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--details", default=None)
    ap.add_argument("--background-bed", default=None)
    ap.add_argument("--feature-types", default=None, help="Comma-separated GFF feature types to keep")
    args = ap.parse_args()

    target_regions = read_bed_regions(args.target_bed, "target")
    background_regions = read_bed_regions(args.background_bed, "background") if args.background_bed else defaultdict(list)
    features = read_bed_features(args.features) if args.feature_format == "bed" else read_gff_features(args.features, args.feature_types)

    target_summary, target_details = summarize_region_set("target", target_regions, features)
    rows = [target_summary]
    details = target_details

    if args.background_bed:
        background_summary, background_details = summarize_region_set("background", background_regions, features)
        bg_fraction = background_summary["coverage_fraction"]
        if bg_fraction:
            target_summary["fold_enrichment_vs_background"] = target_summary["coverage_fraction"] / bg_fraction
        else:
            target_summary["fold_enrichment_vs_background"] = "NA"
            target_summary["qc_note"] = "background_has_zero_feature_coverage"
        rows.append(background_summary)
        details.extend(background_details)

    write_tsv(args.out, SUMMARY_FIELDS, [format_summary(row) for row in rows])
    if args.details:
        write_tsv(args.details, DETAIL_FIELDS, details)


if __name__ == "__main__":
    main()
