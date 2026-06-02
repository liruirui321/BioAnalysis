#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import read_tsv, write_tsv

FIELDS = [
    "term_id", "term_name", "ontology", "p_value", "q_value", "foreground_count",
    "foreground_total", "background_count", "background_total", "foreground_ids", "plot_group",
    "label", "semantic_tool_status",
]


def pick(row, names, default="NA"):
    for name in names:
        value = row.get(name)
        if value not in {None, "", "NA"}:
            return value
    return default


def read_go_names(path):
    if not path:
        return {}
    out = {}
    for row in read_tsv(path):
        term = pick(row, ["go_term", "term_id", "GO", "GO_ID"])
        if term == "NA":
            continue
        out[term] = {
            "term_name": pick(row, ["term_name", "name", "description"], term),
            "ontology": pick(row, ["ontology", "namespace", "aspect"], "NA"),
        }
    return out


def as_float(value, default=1.0):
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def main():
    ap = argparse.ArgumentParser(description="Prepare GO enrichment results for downstream semantic-space visualization tools.")
    ap.add_argument("--enrichment", required=True, help="GO enrichment TSV from enrich_annotation_terms.py or a compatible table")
    ap.add_argument("--out", required=True)
    ap.add_argument("--go-names", default=None, help="Optional GO term-name TSV")
    ap.add_argument("--max-terms", type=int, default=200)
    ap.add_argument("--q-value-cutoff", type=float, default=0.05)
    ap.add_argument("--plot-group", default="target")
    args = ap.parse_args()

    names = read_go_names(args.go_names)
    rows = []
    for row in read_tsv(args.enrichment):
        mode = row.get("mode", "go")
        if mode.lower() != "go":
            continue
        q_value = as_float(pick(row, ["q_value", "FDR", "padj"], "1"))
        if q_value > args.q_value_cutoff:
            continue
        term = pick(row, ["term_id", "go_term", "GO", "GO_ID"])
        if term == "NA":
            continue
        meta = names.get(term, {})
        foreground_count = pick(row, ["foreground_with_term", "foreground_count", "study_count"], "NA")
        background_count = pick(row, ["background_with_term", "background_count", "population_count"], "NA")
        term_name = meta.get("term_name", pick(row, ["term_name", "name", "description"], term))
        rows.append({
            "term_id": term,
            "term_name": term_name,
            "ontology": meta.get("ontology", pick(row, ["ontology", "namespace", "aspect"], "NA")),
            "p_value": pick(row, ["p_value", "pvalue", "PValue"], "NA"),
            "q_value": f"{q_value:.6g}",
            "foreground_count": foreground_count,
            "foreground_total": pick(row, ["foreground_total", "study_total"], "NA"),
            "background_count": background_count,
            "background_total": pick(row, ["background_total", "population_total"], "NA"),
            "foreground_ids": pick(row, ["foreground_ids", "genes", "gene_ids"], "NA"),
            "plot_group": args.plot_group,
            "label": f"{term} {term_name}",
            "semantic_tool_status": "external_handoff",
        })
    rows.sort(key=lambda row: (as_float(row["q_value"]), as_float(row["p_value"]), row["term_id"]))
    write_tsv(args.out, FIELDS, rows[:args.max_terms])


if __name__ == "__main__":
    main()
