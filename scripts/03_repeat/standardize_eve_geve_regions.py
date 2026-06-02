#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import open_text, parse_gff_attributes, write_tsv

FIELDS = ["region_id", "seqid", "start0", "end", "strand", "source", "region_type", "score", "attributes"]


def parse_bed(path, source, region_type):
    rows = []
    with open_text(path) as handle:
        for i, line in enumerate(handle, start=1):
            if not line.strip() or line.startswith("#"):
                continue
            cols = line.rstrip("\n").split("\t")
            if len(cols) < 3:
                continue
            rows.append({
                "region_id": cols[3] if len(cols) > 3 and cols[3] else f"{region_type}_{i}",
                "seqid": cols[0],
                "start0": cols[1],
                "end": cols[2],
                "strand": cols[5] if len(cols) > 5 else "NA",
                "source": source,
                "region_type": region_type,
                "score": cols[4] if len(cols) > 4 else "NA",
                "attributes": "NA",
            })
    return rows


def parse_gff(path, source, region_type, feature_types):
    rows = []
    wanted = set(feature_types.split(",")) if feature_types else None
    with open_text(path) as handle:
        for i, line in enumerate(handle, start=1):
            if not line.strip() or line.startswith("#"):
                continue
            cols = line.rstrip("\n").split("\t")
            if len(cols) < 9:
                continue
            if wanted and cols[2] not in wanted:
                continue
            attrs = parse_gff_attributes(cols[8])
            rid = attrs.get("ID") or attrs.get("Name") or f"{region_type}_{i}"
            rows.append({
                "region_id": rid,
                "seqid": cols[0],
                "start0": str(max(0, int(cols[3]) - 1)),
                "end": cols[4],
                "strand": cols[6],
                "source": cols[1] if cols[1] != "." else source,
                "region_type": cols[2] if cols[2] != "." else region_type,
                "score": cols[5] if cols[5] != "." else "NA",
                "attributes": cols[8],
            })
    return rows


def parse_tsv(path, source, region_type):
    rows = []
    with open_text(path) as handle:
        header = handle.readline().rstrip("\n").split("\t")
        for i, line in enumerate(handle, start=1):
            if not line.strip():
                continue
            values = line.rstrip("\n").split("\t")
            row = dict(zip(header, values))
            seqid = row.get("seqid") or row.get("chrom") or row.get("chromosome")
            start = row.get("start0") or row.get("start")
            end = row.get("end")
            if not seqid or not start or not end:
                continue
            start0 = int(float(start)) if "start0" in row else max(0, int(float(start)) - 1)
            rows.append({
                "region_id": row.get("region_id") or row.get("id") or row.get("ID") or f"{region_type}_{i}",
                "seqid": seqid,
                "start0": str(start0),
                "end": str(int(float(end))),
                "strand": row.get("strand", "NA"),
                "source": row.get("source", source),
                "region_type": row.get("region_type", region_type),
                "score": row.get("score", "NA"),
                "attributes": row.get("attributes", "NA"),
            })
    return rows


def main():
    ap = argparse.ArgumentParser(description="Standardize external EVE/GEVE region calls into BED and TSV handoff files.")
    ap.add_argument("--input", required=True)
    ap.add_argument("--format", choices=["bed", "gff", "tsv"], required=True)
    ap.add_argument("--out-bed", required=True)
    ap.add_argument("--out-tsv", required=True)
    ap.add_argument("--source", default="external_eve_geve_caller")
    ap.add_argument("--region-type", default="EVE_GEVE_region")
    ap.add_argument("--feature-types", default=None, help="Comma-separated GFF feature types to keep")
    args = ap.parse_args()

    if args.format == "bed":
        rows = parse_bed(args.input, args.source, args.region_type)
    elif args.format == "gff":
        rows = parse_gff(args.input, args.source, args.region_type, args.feature_types)
    else:
        rows = parse_tsv(args.input, args.source, args.region_type)

    rows.sort(key=lambda r: (r["seqid"], int(r["start0"]), int(r["end"]), r["region_id"]))
    write_tsv(args.out_tsv, FIELDS, rows)
    out = Path(args.out_bed)
    out.parent.mkdir(parents=True, exist_ok=True)
    with open(out, "w") as handle:
        for row in rows:
            handle.write(f"{row['seqid']}\t{row['start0']}\t{row['end']}\t{row['region_id']}\t0\t{row['strand']}\n")


if __name__ == "__main__":
    main()
