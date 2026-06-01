#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import read_tsv, write_tsv


def tree_tips(path):
    text = Path(path).read_text().strip()
    toks = re.split(r"[(),:;\s]+", text)
    return [tok for tok in toks if tok and not re.fullmatch(r"[0-9. Ee+-]+", tok)]


def parse_count(value):
    try:
        val = int(float(value or 0))
    except ValueError:
        return None
    return val if val >= 0 else None


def main():
    ap = argparse.ArgumentParser(description="Prepare a Count-compatible gene-family count matrix from OrthoFinder GeneCount output.")
    ap.add_argument("--orthofinder-count", required=True)
    ap.add_argument("--species-tree", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--rejected", required=True)
    ap.add_argument("--species-order", required=True)
    args = ap.parse_args()

    rows = read_tsv(args.orthofinder_count)
    if not rows:
        raise SystemExit("Empty OrthoFinder count table")
    fields = list(rows[0])
    family_col = fields[0]
    species_cols = [f for f in fields[1:] if f.lower() != "total"]
    tips = tree_tips(args.species_tree)
    missing = sorted(set(tips) - set(species_cols))
    if missing:
        raise SystemExit("Tree tips missing from count matrix: " + ", ".join(missing))
    ordered_species = [sp for sp in tips if sp in species_cols]

    accepted = []
    rejected = []
    seen = set()
    for row in rows:
        fam = row.get(family_col, "NA")
        reasons = []
        if fam in seen:
            reasons.append("duplicate_family_id")
        seen.add(fam)
        out = {"Family ID": fam}
        for sp in ordered_species:
            val = parse_count(row.get(sp, "0"))
            if val is None:
                reasons.append(f"invalid_count:{sp}")
                val = 0
            out[sp] = val
        if reasons:
            rejected.append({"Family ID": fam, "reason": ";".join(reasons)})
        else:
            accepted.append(out)

    write_tsv(args.out, ["Family ID"] + ordered_species, accepted)
    write_tsv(args.rejected, ["Family ID", "reason"], rejected)
    write_tsv(args.species_order, ["order", "species"], [{"order": i + 1, "species": sp} for i, sp in enumerate(ordered_species)])


if __name__ == "__main__":
    main()
