#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import read_tsv


def main():
    ap = argparse.ArgumentParser(description="Rename Newick tree tips using a TSV table with tip_id and label columns.")
    ap.add_argument("--tree", required=True)
    ap.add_argument("--tip-annotation", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--label-column", default="label")
    args = ap.parse_args()
    mapping = {}
    for r in read_tsv(args.tip_annotation):
        old = r.get("tip_id")
        new = r.get(args.label_column) or old
        if old and new:
            mapping[old] = re.sub(r"[\s,:();]+", "_", new)
    text = Path(args.tree).read_text().strip()
    before = len(re.findall(r"(?<=[(,])([^:(),]+)(?=[:),])", text))
    def repl(m):
        tip = m.group(1)
        return mapping.get(tip, tip)
    new_text = re.sub(r"(?<=[(,])([^:(),]+)(?=[:),])", repl, text)
    after = len(re.findall(r"(?<=[(,])([^:(),]+)(?=[:),])", new_text))
    if before != after:
        raise SystemExit(f"Tip count changed: {before} -> {after}")
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    Path(args.out).write_text(new_text + "\n")


if __name__ == "__main__":
    main()
