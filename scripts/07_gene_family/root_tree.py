#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path


def main():
    ap = argparse.ArgumentParser(description="Documented placeholder for tree rooting. Use external tree tools for robust rerooting.")
    ap.add_argument("--tree", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--outgroup", default=None)
    ap.add_argument("--outgroup-file", default=None)
    args = ap.parse_args()
    text = Path(args.tree).read_text().strip()
    # Robust Newick rerooting is intentionally not reimplemented here. This script preserves the tree
    # and writes a sidecar note so workflows have a concrete handoff point without silent topology edits.
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    Path(args.out).write_text(text + "\n")
    note = Path(args.out).with_suffix(Path(args.out).suffix + ".rooting_note.txt")
    og = args.outgroup or args.outgroup_file or "NA"
    note.write_text(f"Tree copied unchanged. Requested outgroup: {og}. Use FigTree, ETE, or Newick utilities for validated rerooting.\n")


if __name__ == "__main__":
    main()
