#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import read_tsv, write_tsv


def tree_tips(newick):
    text = Path(newick).read_text().strip()
    toks = re.split(r"[(),:;\s]+", text)
    tips = []
    for t in toks:
        if not t or re.fullmatch(r"[0-9. Ee+-]+", t):
            continue
        tips.append(t)
    return set(tips)


def main():
    ap = argparse.ArgumentParser(description="Prepare OrthoFinder GeneCount table for CAFE.")
    ap.add_argument("--orthofinder-count", required=True)
    ap.add_argument("--species-tree", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    rows = read_tsv(args.orthofinder_count)
    if not rows:
        raise SystemExit("Empty gene count table")
    cols = list(rows[0])
    family_col = cols[0]
    species_cols = [c for c in cols[1:] if c.lower() not in {"total"}]
    tips = tree_tips(args.species_tree)
    missing = sorted(tips - set(species_cols))
    extra = sorted(set(species_cols) - tips)
    if missing:
        raise SystemExit(f"Tree tips missing from count matrix: {', '.join(missing)}")
    out_rows = []
    for r in rows:
        out = {"Desc": r.get(family_col, "NA"), "Family ID": r.get(family_col, "NA")}
        for sp in species_cols:
            out[sp] = r.get(sp, "0") or "0"
        out_rows.append(out)
    write_tsv(args.out, ["Desc", "Family ID"] + species_cols, out_rows)
    if extra:
        sys.stderr.write("Warning: species columns not in tree: " + ", ".join(extra) + "\n")


if __name__ == "__main__":
    main()
