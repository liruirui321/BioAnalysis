#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import iter_fasta, write_tsv


def nx(lengths, threshold):
    if not lengths:
        return 0, 0
    total = sum(lengths)
    target = total * threshold
    acc = 0
    for i, length in enumerate(sorted(lengths, reverse=True), start=1):
        acc += length
        if acc >= target:
            return length, i
    return 0, 0


def main():
    ap = argparse.ArgumentParser(description="Compute assembly statistics from a FASTA file.")
    ap.add_argument("--fasta", required=True)
    ap.add_argument("--out", required=True, help="Summary TSV output")
    ap.add_argument("--lengths", default=None, help="Optional per-sequence length TSV")
    args = ap.parse_args()

    lengths = []
    gc = 0
    n_count = 0
    rows = []
    for name, seq in iter_fasta(args.fasta):
        seq_u = seq.upper()
        length = len(seq_u)
        lengths.append(length)
        seq_gc = seq_u.count("G") + seq_u.count("C")
        seq_n = seq_u.count("N")
        gc += seq_gc
        n_count += seq_n
        rows.append({"seqid": name, "length": length, "gc": seq_gc, "n": seq_n})

    total = sum(lengths)
    n50, l50 = nx(lengths, 0.5)
    n90, l90 = nx(lengths, 0.9)
    summary = [{
        "fasta": args.fasta,
        "seq_count": len(lengths),
        "total_length": total,
        "min_length": min(lengths) if lengths else 0,
        "max_length": max(lengths) if lengths else 0,
        "N50": n50,
        "L50": l50,
        "N90": n90,
        "L90": l90,
        "GC_count": gc,
        "GC_percent": f"{(gc / total * 100):.6f}" if total else "0",
        "N_count": n_count,
        "N_percent": f"{(n_count / total * 100):.6f}" if total else "0",
    }]
    write_tsv(args.out, list(summary[0]), summary)
    if args.lengths:
        write_tsv(args.lengths, ["seqid", "length", "gc", "n"], rows)


if __name__ == "__main__":
    main()
