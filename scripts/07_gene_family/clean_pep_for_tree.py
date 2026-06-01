#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import iter_fasta, write_fasta, write_tsv


def main():
    ap = argparse.ArgumentParser(description="Clean peptide FASTA before gene-tree alignment.")
    ap.add_argument("--input", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--summary", default=None)
    ap.add_argument("--remove-terminal-stop", action="store_true")
    ap.add_argument("--drop-empty", action="store_true")
    args = ap.parse_args()
    records, rows = [], []
    for name, seq in iter_fasta(args.input):
        old_len = len(seq)
        terminal_stop = int(seq.endswith("*"))
        if args.remove_terminal_stop and terminal_stop:
            seq = seq[:-1]
        internal_stop = seq[:-1].count("*") if seq else 0
        if args.drop_empty and not seq:
            rows.append({"id": name, "old_len": old_len, "new_len": len(seq), "terminal_stop_removed": terminal_stop, "internal_stop": internal_stop, "status": "dropped_empty"})
            continue
        records.append((name, seq))
        rows.append({"id": name, "old_len": old_len, "new_len": len(seq), "terminal_stop_removed": terminal_stop, "internal_stop": internal_stop, "status": "kept"})
    write_fasta(records, args.out)
    if args.summary:
        write_tsv(args.summary, ["id", "old_len", "new_len", "terminal_stop_removed", "internal_stop", "status"], rows)


if __name__ == "__main__":
    main()
