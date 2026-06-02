#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import open_text, read_tsv, write_lines, write_tsv

DONOR_PRIORITY = ["virus", "bacteria", "fungi", "metazoa", "archaea", "other"]


def split_csv(value: str) -> set[str]:
    return {item.strip().casefold() for item in value.split(",") if item.strip()}


def to_float(value: str) -> float:
    if value in {None, "", "NA", "-"}:
        return 0.0
    try:
        return float(value)
    except ValueError:
        return 0.0


def clean_header(name: str) -> str:
    return name.lstrip("#").strip()


def parse_blast2hgt(path: Path):
    rows = []
    with open_text(path) as handle:
        header = None
        for line in handle:
            if not line.strip():
                continue
            cols = line.rstrip("\n").split("\t")
            if cols[0].startswith("#Query_id") or cols[0] == "Query_id":
                header = [clean_header(c) for c in cols]
                continue
            if header is None:
                continue
            if len(cols) != len(header):
                raise SystemExit(f"Column count mismatch in {path}: {cols[0]!r}")
            values = dict(zip(header, cols))
            if "Query_id" not in values:
                raise SystemExit(f"Missing Query_id column in {path}")
            rows.append(values)
    return rows


def pick(row, names, default="NA"):
    lowered = {k.casefold(): v for k, v in row.items()}
    for name in names:
        value = lowered.get(name.casefold())
        if value not in {None, "", "NA"}:
            return value
    return default


def donor_key(value: str) -> str:
    return (value or "NA").strip()


def donor_sort_key(value: str):
    lower = value.casefold()
    if lower in DONOR_PRIORITY:
        return (DONOR_PRIORITY.index(lower), lower)
    return (len(DONOR_PRIORITY), lower)


def read_species_manifest(path: Path):
    rows = read_tsv(path)
    out = []
    for row in rows:
        species = pick(row, ["species", "species_id", "sample", "name"])
        rp_tsv = pick(row, ["rp_tsv", "blast2hgt_rp_tsv", "hgt_input", "input"], "")
        source = pick(row, ["source", "input_source"], "provided")
        if species == "NA":
            raise SystemExit(f"Missing species column in manifest row: {row}")
        out.append({"species": species, "rp_tsv": rp_tsv, "source": source})
    return out


def main():
    ap = argparse.ArgumentParser(description="Build Condition1/Condition2 HGT candidate tables and donor matrices from per-species blast2hgt .rp.tsv files.")
    ap.add_argument("--species-manifest", required=True, help="TSV with species and rp_tsv/blast2hgt_rp_tsv columns; empty rp_tsv marks pending species")
    ap.add_argument("--outdir", required=True)
    ap.add_argument("--prefix", default="hgt_conditions")
    ap.add_argument("--donor-groups", default="bacteria,fungi,Metazoa,virus,archaea,other")
    ap.add_argument("--exclude-groups", default="Plant,Viridiplantae,Rhodophyta,Glaucocystophyceae,unknown")
    ap.add_argument("--min-alien-index", type=float, default=0.0)
    args = ap.parse_args()

    donors = split_csv(args.donor_groups)
    excluded = split_csv(args.exclude_groups)
    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    id_dir = outdir / "HGT_id_lists"
    id_dir.mkdir(exist_ok=True)

    condition_rows = {"Condition1": [], "Condition2": []}
    matrix_counts = {"Condition1": defaultdict(Counter), "Condition2": defaultdict(Counter)}
    source_summary = []
    all_donors = set()

    for item in read_species_manifest(Path(args.species_manifest)):
        species = item["species"]
        rp = item["rp_tsv"]
        if not rp or rp == "NA":
            source_summary.append({"species": species, "source": "pending_no_hgt_input", "input": "NA", "condition1_count": 0, "condition2_count": 0})
            write_lines(id_dir / f"{species}_Condition1_HGT.id.list", [])
            write_lines(id_dir / f"{species}_Condition2_HGT.id.list", [])
            continue
        rp_path = Path(rp)
        if not rp_path.is_file() or rp_path.stat().st_size == 0:
            raise SystemExit(f"Missing or empty rp_tsv for {species}: {rp}")
        c1_ids = []
        c2_ids = []
        rows = parse_blast2hgt(rp_path)
        for row in rows:
            query = pick(row, ["Query_id", "query_id"])
            ai_taxon = donor_key(pick(row, ["AI_taxon", "alien_index_taxon"]))
            h_taxon = donor_key(pick(row, ["h_taxon", "best_donor_group"]))
            alien_index = to_float(pick(row, ["alien_index"]))
            ai_key = ai_taxon.casefold()
            if ai_key not in donors or ai_key in excluded or alien_index <= args.min_alien_index:
                continue
            out_row = {
                "species": species,
                "query_id": query,
                "alien_index": alien_index,
                "AI_taxon": ai_taxon,
                "h_taxon": h_taxon,
                "condition": "Condition1",
                "source_file": str(rp_path),
            }
            condition_rows["Condition1"].append(out_row)
            matrix_counts["Condition1"][species][ai_taxon] += 1
            all_donors.add(ai_taxon)
            c1_ids.append(f"{query}\t{ai_taxon}")
            if ai_taxon.casefold() == h_taxon.casefold():
                c2_row = dict(out_row)
                c2_row["condition"] = "Condition2"
                condition_rows["Condition2"].append(c2_row)
                matrix_counts["Condition2"][species][ai_taxon] += 1
                c2_ids.append(f"{query}\t{ai_taxon}")
        write_lines(id_dir / f"{species}_Condition1_HGT.id.list", c1_ids)
        write_lines(id_dir / f"{species}_Condition2_HGT.id.list", c2_ids)
        source_summary.append({
            "species": species,
            "source": item["source"],
            "input": str(rp_path),
            "condition1_count": len(c1_ids),
            "condition2_count": len(c2_ids),
        })

    species_order = [item["species"] for item in read_species_manifest(Path(args.species_manifest))]
    donor_order = sorted(all_donors | {d for d in ["bacteria", "fungi", "Metazoa", "virus", "archaea", "other"] if d.casefold() in donors}, key=donor_sort_key)
    fields = ["species", "query_id", "alien_index", "AI_taxon", "h_taxon", "condition", "source_file"]
    for condition in ["Condition1", "Condition2"]:
        write_tsv(outdir / f"{condition}_HGT_candidates.tsv", fields, condition_rows[condition])
        count_rows = []
        prop_rows = []
        for species in species_order:
            counts = matrix_counts[condition][species]
            total = sum(counts.values())
            count_row = {"species": species, "total": total}
            prop_row = {"species": species, "total": total}
            for donor in donor_order:
                value = counts.get(donor, 0)
                count_row[donor] = value
                prop_row[donor] = f"{(value / total):.6f}" if total else "0.000000"
            count_rows.append(count_row)
            prop_rows.append(prop_row)
        suffix = "AI_taxon" if condition == "Condition1" else "Matching_taxon"
        write_tsv(outdir / f"{condition}_{suffix}_counts_matrix.tsv", ["species", *donor_order, "total"], count_rows)
        write_tsv(outdir / f"{condition}_{suffix}_props_matrix.tsv", ["species", *donor_order, "total"], prop_rows)

    write_tsv(outdir / "species_source_summary.tsv", ["species", "source", "input", "condition1_count", "condition2_count"], source_summary)
    run_summary = [
        {"metric": "tree_species", "value": len(species_order)},
        {"metric": "Condition1 total HGT", "value": len(condition_rows["Condition1"])},
        {"metric": "Condition2 total HGT", "value": len(condition_rows["Condition2"])},
        {"metric": "pending_no_hgt_input", "value": sum(1 for row in source_summary if row["source"] == "pending_no_hgt_input")},
    ]
    write_tsv(outdir / "run_summary.tsv", ["metric", "value"], run_summary)
    write_tsv(outdir / "filter_conditions.tsv", ["field", "value"], [
        {"field": "Condition1", "value": f"alien_index > {args.min_alien_index}; AI_taxon in donor whitelist"},
        {"field": "Condition2", "value": f"alien_index > {args.min_alien_index}; AI_taxon == h_taxon; AI_taxon in donor whitelist"},
        {"field": "donor_groups", "value": args.donor_groups},
        {"field": "exclude_groups", "value": args.exclude_groups},
    ])


if __name__ == "__main__":
    main()
