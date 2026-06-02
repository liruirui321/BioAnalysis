#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import open_text, write_tsv

DETAIL_FIELDS = ["block_id", "ref_gene", "query_gene", "ref_species", "query_species", "score", "source_format"]
SUMMARY_FIELDS = ["ref_species", "query_species", "blocks", "linked_gene_pairs", "unique_ref_genes", "unique_query_genes"]


def parse_pair_label(value):
    if value and "." in value:
        first, second = value.split(".", 1)
        return first, second
    if value and "_vs_" in value:
        first, second = value.split("_vs_", 1)
        return first, second
    return "ref", "query"


def read_simple(path, ref_species, query_species):
    rows = []
    with open_text(path) as handle:
        block = 0
        for line in handle:
            if not line.strip() or line.startswith("#"):
                continue
            cols = line.rstrip("\n").split("\t")
            if len(cols) < 4:
                continue
            block += 1
            rows.append({
                "block_id": f"block_{block}",
                "ref_gene": f"{cols[0]}..{cols[1]}",
                "query_gene": f"{cols[2]}..{cols[3]}",
                "ref_species": ref_species,
                "query_species": query_species,
                "score": cols[4] if len(cols) > 4 else "NA",
                "source_format": "simple",
            })
    return rows


def read_anchor(path, ref_species, query_species):
    rows = []
    block = 0
    with open_text(path) as handle:
        for line in handle:
            if not line.strip():
                continue
            if line.startswith("#"):
                block += 1
                continue
            cols = line.rstrip("\n").split()
            if len(cols) < 2:
                continue
            rows.append({
                "block_id": f"block_{block or 1}",
                "ref_gene": cols[0],
                "query_gene": cols[1],
                "ref_species": ref_species,
                "query_species": query_species,
                "score": cols[2] if len(cols) > 2 else "NA",
                "source_format": "anchor",
            })
    return rows


def read_table(path, ref_species, query_species):
    rows = []
    with open_text(path) as handle:
        header = None
        for i, line in enumerate(handle, start=1):
            if not line.strip() or line.startswith("#"):
                continue
            cols = line.rstrip("\n").split("\t")
            if header is None and any(name in cols for name in ["ref_gene", "query_gene", "block_id"]):
                header = cols
                continue
            row = dict(zip(header, cols)) if header else {}
            rows.append({
                "block_id": row.get("block_id") or f"block_{i}",
                "ref_gene": row.get("ref_gene") or row.get("gene1") or (cols[0] if cols else "NA"),
                "query_gene": row.get("query_gene") or row.get("gene2") or (cols[1] if len(cols) > 1 else "NA"),
                "ref_species": row.get("ref_species") or ref_species,
                "query_species": row.get("query_species") or query_species,
                "score": row.get("score") or (cols[2] if len(cols) > 2 else "NA"),
                "source_format": "table",
            })
    return rows


def summarize(rows):
    grouped = defaultdict(list)
    for row in rows:
        grouped[(row["ref_species"], row["query_species"])].append(row)
    out = []
    for (ref, query), vals in sorted(grouped.items()):
        out.append({
            "ref_species": ref,
            "query_species": query,
            "blocks": len({row["block_id"] for row in vals}),
            "linked_gene_pairs": len(vals),
            "unique_ref_genes": len({row["ref_gene"] for row in vals}),
            "unique_query_genes": len({row["query_gene"] for row in vals}),
        })
    return out


def main():
    ap = argparse.ArgumentParser(description="Normalize MCScanX/JCVI anchor, simple, or table synteny files into stable summaries.")
    ap.add_argument("--input", required=True)
    ap.add_argument("--format", choices=["anchor", "simple", "table"], required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--summary", required=True)
    ap.add_argument("--pair-label", default=None, help="Optional species pair label, e.g. Arabidopsis_thaliana.Arabidopsis_lyrata")
    ap.add_argument("--ref-species", default=None)
    ap.add_argument("--query-species", default=None)
    args = ap.parse_args()

    inferred_ref, inferred_query = parse_pair_label(args.pair_label or "")
    ref_species = args.ref_species or inferred_ref
    query_species = args.query_species or inferred_query
    if args.format == "anchor":
        rows = read_anchor(args.input, ref_species, query_species)
    elif args.format == "simple":
        rows = read_simple(args.input, ref_species, query_species)
    else:
        rows = read_table(args.input, ref_species, query_species)
    write_tsv(args.out, DETAIL_FIELDS, rows)
    write_tsv(args.summary, SUMMARY_FIELDS, summarize(rows))


if __name__ == "__main__":
    main()
