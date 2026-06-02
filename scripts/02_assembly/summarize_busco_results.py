#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import open_text, write_tsv

FIELDS = [
    "sample", "input_file", "mode", "lineage", "busco_version", "complete_percent", "single_copy_percent",
    "duplicated_percent", "fragmented_percent", "missing_percent", "complete_count", "single_copy_count",
    "duplicated_count", "fragmented_count", "missing_count", "total_buscos", "summary_file",
]


def parse_percent_summary(value):
    metrics = {}
    m = re.search(r"C:([0-9.]+)%\[S:([0-9.]+)%,D:([0-9.]+)%\],F:([0-9.]+)%,M:([0-9.]+)%,n:(\d+)", value)
    if m:
        metrics.update({
            "complete_percent": m.group(1),
            "single_copy_percent": m.group(2),
            "duplicated_percent": m.group(3),
            "fragmented_percent": m.group(4),
            "missing_percent": m.group(5),
            "total_buscos": m.group(6),
        })
    return metrics


def parse_txt(path):
    metrics = {}
    with open_text(path) as handle:
        for line in handle:
            text = line.strip()
            if not text:
                continue
            if text.startswith("C:"):
                metrics.update(parse_percent_summary(text))
                continue
            if "Complete BUSCOs" in text:
                metrics["complete_count"] = text.split()[0]
            elif "Complete and single-copy BUSCOs" in text:
                metrics["single_copy_count"] = text.split()[0]
            elif "Complete and duplicated BUSCOs" in text:
                metrics["duplicated_count"] = text.split()[0]
            elif "Fragmented BUSCOs" in text:
                metrics["fragmented_count"] = text.split()[0]
            elif "Missing BUSCOs" in text:
                metrics["missing_count"] = text.split()[0]
            elif "Total BUSCO groups searched" in text:
                metrics["total_buscos"] = text.split()[0]
            elif "lineage dataset" in text.lower() and ":" in text:
                metrics["lineage"] = text.split(":", 1)[1].strip().split()[0]
            elif "BUSCO version" in text and ":" in text:
                metrics["busco_version"] = text.split(":", 1)[1].strip()
    return metrics


def parse_json(path):
    with open_text(path) as handle:
        data = json.load(handle)
    results = data.get("results", data)
    metrics = {
        "complete_percent": results.get("Complete percentage", results.get("C", "NA")),
        "single_copy_percent": results.get("Single copy percentage", results.get("S", "NA")),
        "duplicated_percent": results.get("Multi copy percentage", results.get("D", "NA")),
        "fragmented_percent": results.get("Fragmented percentage", results.get("F", "NA")),
        "missing_percent": results.get("Missing percentage", results.get("M", "NA")),
        "complete_count": results.get("Complete BUSCOs", "NA"),
        "single_copy_count": results.get("Single copy BUSCOs", "NA"),
        "duplicated_count": results.get("Multi copy BUSCOs", "NA"),
        "fragmented_count": results.get("Fragmented BUSCOs", "NA"),
        "missing_count": results.get("Missing BUSCOs", "NA"),
        "total_buscos": results.get("Total BUSCO groups searched", results.get("n", "NA")),
        "lineage": data.get("lineage_dataset", data.get("lineage", "NA")),
        "busco_version": data.get("busco_version", data.get("version", "NA")),
    }
    return {key: str(value) for key, value in metrics.items() if value is not None}


def parse_summary(path):
    path = Path(path)
    if path.suffix == ".json":
        return parse_json(path)
    return parse_txt(path)


def infer_sample(path):
    name = Path(path).name
    name = re.sub(r"^short_summary(?:\.specific)?\.", "", name)
    name = re.sub(r"\.(?:json|txt)$", "", name)
    return name or Path(path).stem


def main():
    ap = argparse.ArgumentParser(description="Summarize BUSCO short_summary JSON/TXT outputs into a stable TSV.")
    ap.add_argument("--summary", action="append", required=True, help="BUSCO short_summary JSON/TXT; repeatable")
    ap.add_argument("--out", required=True)
    ap.add_argument("--sample", default=None, help="Sample name override for single --summary use")
    ap.add_argument("--input-file", default="NA")
    ap.add_argument("--mode", default="NA")
    ap.add_argument("--lineage", default="NA")
    args = ap.parse_args()

    rows = []
    for path in args.summary:
        metrics = parse_summary(path)
        sample = args.sample if args.sample and len(args.summary) == 1 else infer_sample(path)
        row = {field: "NA" for field in FIELDS}
        row.update(metrics)
        row.update({
            "sample": sample,
            "input_file": args.input_file,
            "mode": args.mode,
            "lineage": metrics.get("lineage", args.lineage),
            "summary_file": str(path),
        })
        rows.append(row)
    write_tsv(args.out, FIELDS, rows)


if __name__ == "__main__":
    main()
