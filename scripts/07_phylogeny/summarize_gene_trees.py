#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import iter_fasta, open_text, read_tsv, write_tsv


def count_fasta(path):
    if not path or not Path(path).exists():
        return 0, 0
    n = 0
    length = None
    for _, seq in iter_fasta(path):
        n += 1
        length = len(seq) if length is None else max(length, len(seq))
    return n, length or 0


def read_tree_list(path):
    if not path or not Path(path).exists():
        return []
    return [line.strip() for line in open_text(path) if line.strip()]


def read_failed(path):
    d = {}
    if path and Path(path).exists():
        with open_text(path) as handle:
            for line in handle:
                p = line.rstrip("\n").split("\t")
                if p:
                    d[p[0]] = ";".join(p[1:]) if len(p) > 1 else "failed"
    return d


def main():
    ap = argparse.ArgumentParser(description="Summarize gene tree outputs.")
    ap.add_argument("--orthogroups", default=None)
    ap.add_argument("--gene-tree-list", required=True)
    ap.add_argument("--alignment-dir", required=True)
    ap.add_argument("--iqtree-dir", default=None)
    ap.add_argument("--failed", default=None)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    tree_paths = read_tree_list(args.gene_tree_list)
    failed = read_failed(args.failed)
    rows = []
    seen = set()
    for tree in tree_paths:
        og = Path(tree).name
        for suf in [".treefile", ".renamed.tree", ".rooted.tree"]:
            if og.endswith(suf):
                og = og[:-len(suf)]
        aln = Path(args.alignment_dir) / f"{og}.trimmed.fa"
        nseq, alen = count_fasta(aln)
        model = "NA"
        iq = Path(args.iqtree_dir or "") / f"{og}.iqtree" if args.iqtree_dir else None
        if iq and iq.exists():
            for line in iq.read_text(errors="replace").splitlines():
                if "Best-fit model" in line:
                    model = line.split(":", 1)[-1].strip()
                    break
        rows.append({"orthogroup": og, "status": "success", "tree_file": tree, "sequence_count": nseq, "alignment_length": alen, "best_model": model, "failed_reason": "NA"})
        seen.add(og)
    for og, reason in failed.items():
        if og not in seen:
            rows.append({"orthogroup": og, "status": "failed", "tree_file": "NA", "sequence_count": 0, "alignment_length": 0, "best_model": "NA", "failed_reason": reason})
    write_tsv(args.out, ["orthogroup", "status", "tree_file", "sequence_count", "alignment_length", "best_model", "failed_reason"], rows)


if __name__ == "__main__":
    main()
