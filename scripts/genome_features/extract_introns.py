#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections import defaultdict
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import open_text, parse_gff_attributes, write_tsv


def main():
    ap = argparse.ArgumentParser(description="Infer introns from exon or CDS features in GFF3.")
    ap.add_argument("--gff", required=True)
    ap.add_argument("--out", required=True, help="All introns BED")
    ap.add_argument("--short-out", default=None)
    ap.add_argument("--feature", default="exon", choices=["exon", "CDS"])
    ap.add_argument("--min-short", type=int, default=40)
    ap.add_argument("--max-short", type=int, default=65)
    ap.add_argument("--summary", default=None)
    args = ap.parse_args()
    parts = defaultdict(list)
    with open_text(args.gff) as handle:
        for line in handle:
            if line.startswith("#") or not line.strip():
                continue
            p = line.rstrip("\n").split("\t")
            if len(p) < 9 or p[2] != args.feature:
                continue
            attrs = parse_gff_attributes(p[8])
            parent = attrs.get("Parent")
            if not parent:
                continue
            for par in parent.split(","):
                parts[par].append((p[0], int(p[3]), int(p[4]), p[6]))
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    introns = []
    with open(args.out, "w") as out:
        for tx, segs in parts.items():
            segs.sort(key=lambda x: x[1])
            for i in range(len(segs) - 1):
                chrom, s1, e1, strand = segs[i]
                chrom2, s2, e2, _ = segs[i + 1]
                if chrom != chrom2:
                    continue
                start = e1
                end = s2 - 1
                if end > start:
                    length = end - start
                    introns.append((chrom, start, end, tx, length, strand))
                    out.write(f"{chrom}\t{start}\t{end}\t{tx}.intron{i+1}\t{length}\t{strand}\n")
    if args.short_out:
        with open(args.short_out, "w") as out:
            for chrom, start, end, tx, length, strand in introns:
                if args.min_short <= length <= args.max_short:
                    out.write(f"{chrom}\t{start}\t{end}\t{tx}\t{length}\t{strand}\n")
    if args.summary:
        write_tsv(args.summary, ["metric", "value"], [{"metric": "transcripts_with_features", "value": len(parts)}, {"metric": "introns", "value": len(introns)}])


if __name__ == "__main__":
    main()
