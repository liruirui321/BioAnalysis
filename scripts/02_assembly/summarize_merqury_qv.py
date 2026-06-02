#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path
import re
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import open_text, write_tsv

FIELDS = ["sample", "metric", "value", "source_file"]


def add_qv_rows(path, sample, rows):
    with open_text(path) as handle:
        for line in handle:
            text = line.strip()
            if not text or text.startswith("#"):
                continue
            cols = re.split(r"\s+", text)
            if len(cols) >= 4:
                rows.append({"sample": sample, "metric": "assembly", "value": cols[0], "source_file": str(path)})
                rows.append({"sample": sample, "metric": "kmer_error_rate", "value": cols[-2], "source_file": str(path)})
                rows.append({"sample": sample, "metric": "kmer_qv", "value": cols[-1], "source_file": str(path)})
            elif len(cols) >= 2:
                rows.append({"sample": sample, "metric": cols[0].rstrip(":"), "value": cols[-1], "source_file": str(path)})


def add_generic_rows(path, sample, rows):
    with open_text(path) as handle:
        for line in handle:
            text = line.strip()
            if not text or text.startswith("#"):
                continue
            cols = re.split(r"\s+", text)
            if len(cols) < 2:
                continue
            if "completeness" in path.name.lower() and len(cols) >= 3:
                rows.append({"sample": sample, "metric": f"{cols[0]}_completeness", "value": cols[-1], "source_file": str(path)})
            elif "spectra" in path.name.lower() and len(cols) >= 2:
                rows.append({"sample": sample, "metric": cols[0].rstrip(":"), "value": cols[-1], "source_file": str(path)})
            else:
                rows.append({"sample": sample, "metric": cols[0].rstrip(":"), "value": cols[-1], "source_file": str(path)})


def parse_file(path, sample):
    rows = []
    if path.name == "final_kmer.txt":
        with open_text(path) as handle:
            value = handle.read().strip()
        rows.append({"sample": sample, "metric": "final_kmer", "value": value or "NA", "source_file": str(path)})
    elif path.suffix == ".qv" or path.name.endswith(".qv"):
        add_qv_rows(path, sample, rows)
    else:
        add_generic_rows(path, sample, rows)
    return rows


def main():
    ap = argparse.ArgumentParser(description="Summarize Merqury QV/completeness output files into a stable TSV.")
    ap.add_argument("--input", action="append", default=[])
    ap.add_argument("--dir", default=None)
    ap.add_argument("--sample", default="genome")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    files = [Path(path) for path in args.input]
    if args.dir:
        root = Path(args.dir)
        for pattern in ["*.qv", "*.completeness.stats", "*.spectra-cn.stats", "*.only.hist", "*.dist_only.hist", "final_kmer.txt"]:
            files.extend(sorted(root.glob(pattern)))
    files = sorted(dict.fromkeys(files))
    if not files:
        raise SystemExit("Provide --input or --dir with Merqury output files")
    rows = []
    for path in files:
        if path.exists() and path.stat().st_size > 0:
            rows.extend(parse_file(path, args.sample))
    write_tsv(args.out, FIELDS, rows)


if __name__ == "__main__":
    main()
