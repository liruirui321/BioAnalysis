#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import ensure_file, open_text, write_tsv


def main():
    ap = argparse.ArgumentParser(description="Parse KofamScan exec_annotation -f detail output.")
    ap.add_argument("--input", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--keep-all", action="store_true")
    args = ap.parse_args()
    ensure_file(args.input, "Kofam detail")
    rows = []
    with open_text(args.input) as handle:
        for line in handle:
            if not line.strip() or line.startswith("#"):
                continue
            parts = line.rstrip("\n").split()
            passed = "0"
            if parts[0] == "*":
                passed = "1"
                parts = parts[1:]
            if len(parts) < 5:
                continue
            query, ko, threshold, score = parts[0], parts[1], parts[2], parts[3]
            evalue = parts[4]
            desc = " ".join(parts[5:]) if len(parts) > 5 else "NA"
            if passed == "1" or args.keep_all:
                rows.append({"Query_id": query, "KO": ko, "threshold": threshold, "score": score, "E_value": evalue, "pass": passed, "description": desc})
    write_tsv(args.out, ["Query_id", "KO", "threshold", "score", "E_value", "pass", "description"], rows)


if __name__ == "__main__":
    main()
