#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import math
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import open_text, write_tsv

GENE_FIELDS = ["gene_id", "category", "category_name", "source_column"]
SUMMARY_FIELDS = ["category", "category_name", "gene_count", "proportion", "log2_proportion"]

COG_NAMES = {
    "J": "Translation, ribosomal structure and biogenesis",
    "A": "RNA processing and modification",
    "K": "Transcription",
    "L": "Replication, recombination and repair",
    "B": "Chromatin structure and dynamics",
    "D": "Cell cycle control, cell division, chromosome partitioning",
    "Y": "Nuclear structure",
    "V": "Defense mechanisms",
    "T": "Signal transduction mechanisms",
    "M": "Cell wall/membrane/envelope biogenesis",
    "N": "Cell motility",
    "Z": "Cytoskeleton",
    "W": "Extracellular structures",
    "U": "Intracellular trafficking, secretion, and vesicular transport",
    "O": "Posttranslational modification, protein turnover, chaperones",
    "C": "Energy production and conversion",
    "G": "Carbohydrate transport and metabolism",
    "E": "Amino acid transport and metabolism",
    "F": "Nucleotide transport and metabolism",
    "H": "Coenzyme transport and metabolism",
    "I": "Lipid transport and metabolism",
    "P": "Inorganic ion transport and metabolism",
    "Q": "Secondary metabolites biosynthesis, transport and catabolism",
    "R": "General function prediction only",
    "S": "Function unknown",
}


def read_emapper(path):
    header = None
    rows = []
    with open_text(path) as handle:
        for line in handle:
            if not line.strip():
                continue
            if line.startswith("##"):
                continue
            if line.startswith("#"):
                header = line.lstrip("#").rstrip("\n").split("\t")
                continue
            cols = line.rstrip("\n").split("\t")
            if header:
                row = dict(zip(header, cols))
            else:
                row = {str(i): value for i, value in enumerate(cols)}
            rows.append(row)
    return rows


def pick(row, names, fallback_index=None):
    for name in names:
        if name in row and row[name] and row[name] != "-":
            return row[name], name
    if fallback_index is not None and str(fallback_index) in row and row[str(fallback_index)] and row[str(fallback_index)] != "-":
        return row[str(fallback_index)], str(fallback_index)
    return "NA", "NA"


def split_categories(value):
    if not value or value in {"NA", "-"}:
        return []
    cats = []
    for char in value.strip():
        if char.isalpha():
            cats.append(char.upper())
    return sorted(set(cats))


def main():
    ap = argparse.ArgumentParser(description="Summarize eggNOG-mapper COG/NOG category assignments.")
    ap.add_argument("--eggnog", required=True, help="eggNOG-mapper/emapper annotation TSV")
    ap.add_argument("--out", required=True, help="Category summary TSV")
    ap.add_argument("--gene2category", required=True, help="Long gene-to-category TSV")
    ap.add_argument("--id-column", default=None, help="Override query ID column")
    ap.add_argument("--category-column", default=None, help="Override COG/category column")
    args = ap.parse_args()

    gene_rows = []
    category_to_genes = defaultdict(set)
    source_counter = Counter()
    all_genes = set()
    for row in read_emapper(args.eggnog):
        id_names = [args.id_column] if args.id_column else ["#query", "query", "query_name", "0"]
        cat_names = [args.category_column] if args.category_column else ["COG_category", "COG cat", "COG_category_id", "cog_category", "6"]
        gene_id, _id_source = pick(row, id_names, 0)
        category_value, category_source = pick(row, cat_names, 6)
        if gene_id == "NA":
            continue
        all_genes.add(gene_id)
        cats = split_categories(category_value)
        if not cats:
            cats = ["NA"]
        source_counter[category_source] += 1
        for category in cats:
            category_to_genes[category].add(gene_id)
            gene_rows.append({
                "gene_id": gene_id,
                "category": category,
                "category_name": COG_NAMES.get(category, "NA" if category == "NA" else "Unmapped category"),
                "source_column": category_source,
            })

    total = len(all_genes)
    summary = []
    for category, genes in sorted(category_to_genes.items(), key=lambda item: (-len(item[1]), item[0])):
        proportion = len(genes) / total if total else 0
        log2_prop = "NA" if proportion == 0 else f"{math.log2(proportion):.6f}"
        summary.append({
            "category": category,
            "category_name": COG_NAMES.get(category, "NA" if category == "NA" else "Unmapped category"),
            "gene_count": len(genes),
            "proportion": f"{proportion:.6f}",
            "log2_proportion": log2_prop,
        })
    write_tsv(args.gene2category, GENE_FIELDS, gene_rows)
    write_tsv(args.out, SUMMARY_FIELDS, summary)


if __name__ == "__main__":
    main()
