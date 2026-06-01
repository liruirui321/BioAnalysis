#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import read_tsv, write_lines, write_tsv


def load_species(path, rows, family_col):
    if path:
        with open(path) as handle:
            return [line.strip().split()[0] for line in handle if line.strip() and not line.startswith("#")]
    fields = list(rows[0]) if rows else []
    return [f for f in fields if f not in {family_col, "Total"}]


def parse_count(value):
    try:
        return int(float(value or 0))
    except ValueError:
        return 0


def main():
    ap = argparse.ArgumentParser(description="Summarize OrthoFinder gene-family count and occupancy patterns.")
    ap.add_argument("--orthogroups", default=None, help="Optional Orthogroups.tsv membership table")
    ap.add_argument("--gene-count", required=True, help="Orthogroups.GeneCount.tsv")
    ap.add_argument("--species-list", default=None)
    ap.add_argument("--out", required=True)
    ap.add_argument("--single-copy-list", default=None)
    ap.add_argument("--core-list", default=None)
    ap.add_argument("--lineage-specific-list", default=None)
    args = ap.parse_args()

    counts = read_tsv(args.gene_count)
    if not counts:
        raise SystemExit("Empty gene count table")
    family_col = list(counts[0])[0]
    species = load_species(args.species_list, counts, family_col)

    members = {}
    if args.orthogroups:
        for row in read_tsv(args.orthogroups):
            fam = row.get(family_col) or row.get("Orthogroup") or row.get("Family ID")
            if fam:
                members[fam] = {sp: row.get(sp, "") for sp in species}

    rows = []
    single_copy = []
    core = []
    lineage_specific = []
    for row in counts:
        fam = row.get(family_col, "NA")
        values = {sp: parse_count(row.get(sp, "0")) for sp in species}
        present = [sp for sp, val in values.items() if val > 0]
        total = sum(values.values())
        is_single = all(val == 1 for val in values.values())
        is_core = len(present) == len(species)
        is_lineage_specific = len(present) == 1
        if is_single:
            single_copy.append(fam)
        if is_core:
            core.append(fam)
        if is_lineage_specific:
            lineage_specific.append(fam)
        rows.append({
            "family_id": fam,
            "total_copies": total,
            "species_present": len(present),
            "species_total": len(species),
            "occupancy": f"{len(present) / len(species):.6f}" if species else "0",
            "single_copy_all_species": str(is_single),
            "core_family": str(is_core),
            "lineage_specific": str(is_lineage_specific),
            "present_species": ";".join(present) if present else "NA",
            "copy_counts": ";".join(f"{sp}:{values[sp]}" for sp in species),
        })

    write_tsv(args.out, [
        "family_id", "total_copies", "species_present", "species_total", "occupancy",
        "single_copy_all_species", "core_family", "lineage_specific", "present_species", "copy_counts",
    ], rows)
    if args.single_copy_list:
        write_lines(args.single_copy_list, single_copy)
    if args.core_list:
        write_lines(args.core_list, core)
    if args.lineage_specific_list:
        write_lines(args.lineage_specific_list, lineage_specific)


if __name__ == "__main__":
    main()
