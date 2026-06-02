#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections import defaultdict
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import open_text, write_tsv

BIN_FIELDS = [
    "region_id", "seqid", "region_start0", "region_end", "strand", "section", "bin_index",
    "bin_start0", "bin_end", "context", "covered_sites", "methylated_counts",
    "total_counts", "methylation_level",
]
SUMMARY_FIELDS = [
    "region_set", "context", "regions", "covered_sites", "methylated_counts", "total_counts",
    "methylation_level", "qc_note",
]


def to_int(value, default=None):
    try:
        return int(float(value))
    except (TypeError, ValueError):
        return default


def read_bed(path):
    regions = []
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
            regions.append({
                "seqid": cols[0],
                "start0": start,
                "end": end,
                "id": cols[3] if len(cols) > 3 and cols[3] else f"region_{i}",
                "strand": cols[5] if len(cols) > 5 else "+",
            })
    return regions


def parse_bin_scheme(value):
    parts = [int(x) for x in value.split(",")]
    if len(parts) != 3 or any(x < 0 for x in parts) or parts[1] <= 0:
        raise SystemExit("--bins must contain upstream,body,downstream non-negative integers with body > 0")
    return parts


def region_bins(region, flank_bp, scheme):
    up_bins, body_bins, down_bins = scheme
    start = region["start0"]
    end = region["end"]
    length = end - start
    bins = []

    def add_scaled(section, count, section_start, section_end):
        if count <= 0:
            return
        section_len = section_end - section_start
        for idx in range(count):
            b_start = section_start + int(section_len * idx / count)
            b_end = section_start + int(section_len * (idx + 1) / count)
            if b_end > b_start:
                bins.append({"section": section, "bin_index": idx + 1, "start0": b_start, "end": b_end})

    upstream_start = max(0, start - flank_bp)
    upstream_end = start
    downstream_start = end
    downstream_end = end + flank_bp
    if region["strand"] == "-":
        add_scaled("upstream", up_bins, downstream_start, downstream_end)
        add_scaled("body", body_bins, start, end)
        add_scaled("downstream", down_bins, upstream_start, upstream_end)
    else:
        add_scaled("upstream", up_bins, upstream_start, upstream_end)
        add_scaled("body", body_bins, start, end)
        add_scaled("downstream", down_bins, downstream_start, downstream_end)
    if length <= 0:
        return []
    return bins


def context_label(raw):
    raw = raw.upper()
    if raw.startswith("CG"):
        return "CG"
    if raw.startswith("CHG"):
        return "CHG"
    if raw.startswith("CHH"):
        return "CHH"
    if len(raw) >= 3 and raw[0] == "C" and raw[2] == "G":
        return "CHG"
    if raw.startswith("C"):
        return "CHH"
    return raw or "NA"


def read_cx(path, min_coverage):
    sites = defaultdict(list)
    with open_text(path) as handle:
        for line in handle:
            if not line.strip() or line.startswith("#"):
                continue
            cols = line.rstrip("\n").split("\t")
            if len(cols) < 6:
                continue
            pos = to_int(cols[1])
            methylated = to_int(cols[3])
            unmethylated = to_int(cols[4])
            if pos is None or methylated is None or unmethylated is None:
                continue
            total = methylated + unmethylated
            if total < min_coverage:
                continue
            context = context_label(cols[5])
            sites[cols[0]].append({
                "pos0": max(0, pos - 1),
                "context": context,
                "methylated": methylated,
                "total": total,
            })
    for seqid in sites:
        sites[seqid].sort(key=lambda row: row["pos0"])
    return sites


def summarize_bins(regions, sites, flank_bp, scheme):
    rows = []
    summary = defaultdict(lambda: {"regions": set(), "covered_sites": 0, "methylated_counts": 0, "total_counts": 0})
    contexts = ["CG", "CHG", "CHH"]
    for region in regions:
        bins = region_bins(region, flank_bp, scheme)
        seq_sites = sites.get(region["seqid"], [])
        for b in bins:
            by_context = {context: {"covered_sites": 0, "methylated_counts": 0, "total_counts": 0} for context in contexts}
            for site in seq_sites:
                if site["pos0"] < b["start0"]:
                    continue
                if site["pos0"] >= b["end"]:
                    break
                if site["context"] not in by_context:
                    continue
                bucket = by_context[site["context"]]
                bucket["covered_sites"] += 1
                bucket["methylated_counts"] += site["methylated"]
                bucket["total_counts"] += site["total"]
            for context, values in by_context.items():
                total = values["total_counts"]
                level = values["methylated_counts"] / total if total else "NA"
                rows.append({
                    "region_id": region["id"],
                    "seqid": region["seqid"],
                    "region_start0": region["start0"],
                    "region_end": region["end"],
                    "strand": region["strand"],
                    "section": b["section"],
                    "bin_index": b["bin_index"],
                    "bin_start0": b["start0"],
                    "bin_end": b["end"],
                    "context": context,
                    "covered_sites": values["covered_sites"],
                    "methylated_counts": values["methylated_counts"],
                    "total_counts": total,
                    "methylation_level": f"{level:.6f}" if isinstance(level, float) else level,
                })
                item = summary[context]
                item["regions"].add(region["id"])
                item["covered_sites"] += values["covered_sites"]
                item["methylated_counts"] += values["methylated_counts"]
                item["total_counts"] += total
    summary_rows = []
    for context in contexts:
        item = summary[context]
        total = item["total_counts"]
        level = item["methylated_counts"] / total if total else "NA"
        summary_rows.append({
            "region_set": "target",
            "context": context,
            "regions": len(item["regions"]),
            "covered_sites": item["covered_sites"],
            "methylated_counts": item["methylated_counts"],
            "total_counts": total,
            "methylation_level": f"{level:.6f}" if isinstance(level, float) else level,
            "qc_note": "ok" if total else "no_covered_sites",
        })
    return rows, summary_rows


def main():
    ap = argparse.ArgumentParser(description="Summarize Bismark CX methylation over target regions using upstream/body/downstream bins.")
    ap.add_argument("--cx", required=True, help="Bismark CX report")
    ap.add_argument("--regions-bed", required=True)
    ap.add_argument("--out", required=True, help="Long bin table")
    ap.add_argument("--summary", required=True)
    ap.add_argument("--bins", default="25,100,25", help="Upstream,body,downstream bin counts")
    ap.add_argument("--flank-bp", type=int, default=2000)
    ap.add_argument("--min-coverage", type=int, default=1)
    args = ap.parse_args()

    scheme = parse_bin_scheme(args.bins)
    regions = read_bed(args.regions_bed)
    sites = read_cx(args.cx, args.min_coverage)
    rows, summary = summarize_bins(regions, sites, args.flank_bp, scheme)
    write_tsv(args.out, BIN_FIELDS, rows)
    write_tsv(args.summary, SUMMARY_FIELDS, summary)


if __name__ == "__main__":
    main()
