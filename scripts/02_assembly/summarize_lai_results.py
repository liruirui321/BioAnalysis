#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path
import re
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import open_text, write_tsv

FIELDS = ["sample", "region", "start", "end", "raw_lai", "neutral_lai", "lai_score", "quality_status", "lai_file"]


def numeric(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def quality(score):
    value = numeric(score)
    if value is None:
        return "NA"
    if value >= 20:
        return "gold"
    if value >= 10:
        return "reference"
    if value >= 5:
        return "draft"
    return "low"


def pick(row, names, default="NA"):
    for name in names:
        if name in row and row[name] != "":
            return row[name]
    return default


def parse_lai_file(path, sample):
    rows = []
    header = None
    with open_text(path) as handle:
        for line in handle:
            text = line.strip()
            if not text:
                continue
            if text.startswith("#"):
                clean = text.lstrip("#").strip()
                if re.search(r"\bLAI\b", clean) and re.search(r"\s", clean):
                    header = re.split(r"\s+", clean)
                continue
            cols = re.split(r"\s+", text)
            if len(cols) < 2:
                continue
            row = dict(zip(header, cols)) if header and len(header) == len(cols) else {}
            numeric_values = [value for value in cols if numeric(value) is not None]
            if not numeric_values:
                continue
            raw_lai = pick(row, ["raw_LAI", "Raw_LAI", "raw_lai"])
            neutral_lai = pick(row, ["neutral_LAI", "Neutral_LAI", "neutral_lai"])
            lai_score = pick(row, ["LAI", "lai"])
            if lai_score == "NA":
                lai_score = neutral_lai if neutral_lai != "NA" else numeric_values[-1]
            rows.append({
                "sample": sample,
                "region": pick(row, ["Chr", "chr", "region", "Region"], cols[0]),
                "start": pick(row, ["Start", "start"], cols[1] if len(cols) > 2 and numeric(cols[1]) is not None else "NA"),
                "end": pick(row, ["End", "end"], cols[2] if len(cols) > 3 and numeric(cols[2]) is not None else "NA"),
                "raw_lai": raw_lai,
                "neutral_lai": neutral_lai,
                "lai_score": lai_score,
                "quality_status": quality(lai_score),
                "lai_file": str(path),
            })
    if not rows:
        rows.append({"sample": sample, "region": "NA", "start": "NA", "end": "NA", "raw_lai": "NA", "neutral_lai": "NA", "lai_score": "NA", "quality_status": "missing", "lai_file": str(path)})
    return rows


def main():
    ap = argparse.ArgumentParser(description="Summarize LTR_retriever LAI output files into a stable TSV.")
    ap.add_argument("--lai-file", action="append", default=[])
    ap.add_argument("--lai-dir", default=None)
    ap.add_argument("--sample", default="genome")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    files = [Path(path) for path in args.lai_file]
    if args.lai_dir:
        root = Path(args.lai_dir)
        for pattern in ["*.LAI", "*.out.LAI", "*.LAI.txt", "*.lai", "*.lai.tsv"]:
            files.extend(sorted(root.glob(pattern)))
    files = sorted(dict.fromkeys(files))
    if not files:
        raise SystemExit("Provide --lai-file or --lai-dir containing LAI output files")
    rows = []
    for path in files:
        if path.exists() and path.stat().st_size > 0:
            rows.extend(parse_lai_file(path, args.sample))
    write_tsv(args.out, FIELDS, rows)


if __name__ == "__main__":
    main()
