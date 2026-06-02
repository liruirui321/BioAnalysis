#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import iter_fasta, read_tsv, write_fasta, write_lines, write_tsv


def pick(row, names, default="NA"):
    for name in names:
        value = row.get(name)
        if value not in {None, "", "NA"}:
            return value
    lowered = {k.casefold(): v for k, v in row.items()}
    for name in names:
        value = lowered.get(name.casefold())
        if value not in {None, "", "NA"}:
            return value
    return default


def sanitize_source(value: str) -> str:
    value = (value or "NA").strip().replace(" ", "_")
    return value if value else "NA"


def read_candidates(paths):
    seen = set()
    for path in paths:
        for row in read_tsv(path):
            gene = pick(row, ["query_id", "gene_id", "transcript_id"])
            source = sanitize_source(pick(row, ["AI_taxon", "best_donor_group", "best_donor_taxon", "source"]))
            species = pick(row, ["species", "sample", "species_id"], "NA")
            if gene == "NA":
                continue
            key = (gene, source)
            if key in seen:
                continue
            seen.add(key)
            yield {"gene_id": gene, "source": source, "species": species}


def main():
    ap = argparse.ArgumentParser(description="Prepare HGT gene/source lists and optional peptide FASTA for HGT-only OrthoFinder clustering.")
    ap.add_argument("--candidates", required=True, action="append", help="HGT candidate TSV; repeatable")
    ap.add_argument("--outdir", required=True)
    ap.add_argument("--prefix", default="HGT")
    ap.add_argument("--protein", action="append", default=[], help="Protein FASTA containing candidate IDs; repeatable")
    args = ap.parse_args()

    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    rows = list(read_candidates(args.candidates))
    id_map = [{"gene_id": row["gene_id"], "source": row["source"], "hgt_orthofinder_id": f"{row['gene_id']}--{row['source']}", "species": row["species"]} for row in rows]
    wanted = {row["gene_id"]: row for row in id_map}

    write_tsv(outdir / f"{args.prefix}.hgt_gene_source_map.tsv", ["gene_id", "source", "hgt_orthofinder_id", "species"], id_map)
    write_lines(outdir / f"{args.prefix}.hgt_gene_source.list", [row["hgt_orthofinder_id"] for row in id_map])
    write_lines(outdir / f"{args.prefix}.hgt_gene_ids.txt", [row["gene_id"] for row in id_map])

    records = []
    found = set()
    for fasta in args.protein:
        for name, seq in iter_fasta(fasta):
            key = name.split()[0]
            if key in wanted and key not in found:
                records.append((wanted[key]["hgt_orthofinder_id"], seq))
                found.add(key)
    if args.protein:
        write_fasta(records, outdir / f"{args.prefix}.hgt.proteins.fa")
        missing = sorted(set(wanted) - found)
        write_lines(outdir / f"{args.prefix}.hgt_missing_protein_ids.txt", missing)

    write_tsv(outdir / f"{args.prefix}.hgt_orthogroup_manifest.tsv", ["field", "value"], [
        {"field": "candidate_files", "value": ";".join(args.candidates)},
        {"field": "candidate_count", "value": len(id_map)},
        {"field": "protein_fastas", "value": ";".join(args.protein) if args.protein else "NA"},
        {"field": "hgt_gene_source_list", "value": str(outdir / f"{args.prefix}.hgt_gene_source.list")},
        {"field": "hgt_protein_fasta", "value": str(outdir / f"{args.prefix}.hgt.proteins.fa") if args.protein else "NA"},
    ])


if __name__ == "__main__":
    main()
