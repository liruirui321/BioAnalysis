#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import ensure_file, open_text


def read_bed(path):
    ensure_file(path, "gene BED")
    d = {}
    with open_text(path) as handle:
        for line in handle:
            if not line.strip() or line.startswith("#"):
                continue
            p = line.rstrip("\n").split("\t")
            if len(p) < 4:
                raise SystemExit(f"BED needs at least 4 columns: {path}")
            d[p[3]] = p[:3]
    return d


def main():
    ap = argparse.ArgumentParser(description="Convert simple anchor/block records to Circos link format. Generalized from reference simple2links.py.")
    ap.add_argument("--simple", required=True, help="Simple file with ref_start_gene ref_end_gene qry_start_gene qry_end_gene")
    ap.add_argument("--ref-bed", required=True, help="BED with gene ID in 4th column")
    ap.add_argument("--qry-bed", required=True, help="BED with gene ID in 4th column")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    ref = read_bed(args.ref_bed)
    qry = read_bed(args.qry_bed)
    ensure_file(args.simple, "simple anchors")
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    missing = 0
    with open_text(args.simple) as inp, open(args.out, "w") as out:
        for line in inp:
            if not line.strip() or line.startswith("#"):
                continue
            p = line.rstrip("\n").split("\t")
            if len(p) < 4:
                continue
            r1, r2, q1, q2 = p[:4]
            if r1 not in ref or r2 not in ref or q1 not in qry or q2 not in qry:
                missing += 1
                continue
            rchr, rstart = ref[r1][0], ref[r1][1]
            rend = ref[r2][2]
            qchr, qstart = qry[q1][0], qry[q1][1]
            qend = qry[q2][2]
            out.write("\t".join([rchr, rstart, rend, qchr, qstart, qend]) + "\n")
    if missing:
        sys.stderr.write(f"Skipped {missing} records with missing gene coordinates\n")


if __name__ == "__main__":
    main()
