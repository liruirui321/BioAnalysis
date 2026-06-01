#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import ensure_file, open_text, write_tsv


def parse_line(parts):
    qid = parts[0] if len(parts) > 0 else "NA"
    db = parts[3] if len(parts) > 3 else "NA"
    sid = parts[4] if len(parts) > 4 else "NA"
    desc = parts[5] if len(parts) > 5 else "NA"
    start = parts[6] if len(parts) > 6 else "NA"
    end = parts[7] if len(parts) > 7 else "NA"
    evalue = parts[8] if len(parts) > 8 else "NA"
    interpro = parts[11] if len(parts) > 11 else "NA"
    interpro_desc = parts[12] if len(parts) > 12 else "NA"
    go = parts[13] if len(parts) > 13 else "NA"
    return {
        "Query_id": qid,
        "Subject_id": sid,
        "Subject_DB": db,
        "Query_start": start,
        "Query_end": end,
        "E_value": evalue,
        "Subject_annotation": desc,
        "InterPro_id": interpro,
        "InterPro_annotation": interpro_desc,
        "GO_terms": go,
    }


def main():
    ap = argparse.ArgumentParser(description="Convert InterProScan TSV to BioAnalysis iprscan-style table.")
    ap.add_argument("--input", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    ensure_file(args.input, "InterProScan TSV")
    rows = []
    with open_text(args.input) as handle:
        for line in handle:
            if not line.strip() or line.startswith("#"):
                continue
            rows.append(parse_line(line.rstrip("\n").split("\t")))
    fields = ["Query_id", "Subject_id", "Subject_DB", "Query_start", "Query_end", "E_value", "Subject_annotation", "InterPro_id", "InterPro_annotation", "GO_terms"]
    write_tsv(args.out, fields, rows)


if __name__ == "__main__":
    main()
