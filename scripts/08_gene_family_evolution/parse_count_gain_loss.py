#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import read_tsv, write_tsv

FIELDS = ["family_id", "node_id", "node_label", "gain", "loss", "expansion", "contraction", "inferred_count"]


def get(row, names, default="NA"):
    for name in names:
        if name in row and row[name] not in {"", None}:
            return row[name]
    return default


def parse_long(rows):
    out = []
    for row in rows:
        out.append({
            "family_id": get(row, ["family_id", "Family ID", "family", "orthogroup"]),
            "node_id": get(row, ["node_id", "node", "branch"]),
            "node_label": get(row, ["node_label", "label", "species"]),
            "gain": get(row, ["gain", "gains"], "0"),
            "loss": get(row, ["loss", "losses"], "0"),
            "expansion": get(row, ["expansion", "expansions"], "0"),
            "contraction": get(row, ["contraction", "contractions"], "0"),
            "inferred_count": get(row, ["inferred_count", "count", "family_size"], "NA"),
        })
    return out


def parse_wide(rows):
    if not rows:
        return []
    fields = list(rows[0])
    family_col = fields[0]
    out = []
    for row in rows:
        fam = row.get(family_col, "NA")
        for field in fields[1:]:
            parts = field.split("|")
            if len(parts) == 2:
                node, metric = parts
            elif "_" in field:
                node, metric = field.rsplit("_", 1)
            else:
                continue
            if metric not in {"gain", "loss", "expansion", "contraction", "count"}:
                continue
            record_key = (fam, node)
            out.append({
                "family_id": fam,
                "node_id": node,
                "node_label": node,
                "gain": row[field] if metric == "gain" else "0",
                "loss": row[field] if metric == "loss" else "0",
                "expansion": row[field] if metric == "expansion" else "0",
                "contraction": row[field] if metric == "contraction" else "0",
                "inferred_count": row[field] if metric == "count" else "NA",
            })
    merged = {}
    for row in out:
        key = (row["family_id"], row["node_id"])
        merged.setdefault(key, {"family_id": row["family_id"], "node_id": row["node_id"], "node_label": row["node_label"], "gain": "0", "loss": "0", "expansion": "0", "contraction": "0", "inferred_count": "NA"})
        for metric in ["gain", "loss", "expansion", "contraction", "inferred_count"]:
            if row[metric] not in {"0", "NA"}:
                merged[key][metric] = row[metric]
    return list(merged.values())


def main():
    ap = argparse.ArgumentParser(description="Normalize Count gain/loss output to a stable long table.")
    ap.add_argument("--input", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--format", choices=["long", "wide"], default="long")
    args = ap.parse_args()

    rows = read_tsv(args.input)
    parsed = parse_long(rows) if args.format == "long" else parse_wide(rows)
    write_tsv(args.out, FIELDS, parsed)


if __name__ == "__main__":
    main()
