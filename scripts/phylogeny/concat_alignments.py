#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import iter_fasta, read_id_set, write_fasta, write_tsv


def read_species(path):
    return [line.strip().split()[0] for line in open(path) if line.strip() and not line.startswith("#")]


def main():
    ap = argparse.ArgumentParser(description="Concatenate aligned FASTA files into a supermatrix.")
    ap.add_argument("--input-dir", required=True)
    ap.add_argument("--suffix", default=".trimmed.fa")
    ap.add_argument("--species-list", required=True)
    ap.add_argument("--out-fasta", required=True)
    ap.add_argument("--out-partition", required=True)
    ap.add_argument("--out-stats", required=True)
    args = ap.parse_args()
    species = read_species(args.species_list)
    seqs = {sp: [] for sp in species}
    stats = {sp: {"species": sp, "present_genes": 0, "missing_genes": 0, "sequence_length": 0} for sp in species}
    partitions = []
    pos = 1
    for fa in sorted(Path(args.input_dir).glob(f"*{args.suffix}")):
        gene = fa.name[:-len(args.suffix)] if args.suffix and fa.name.endswith(args.suffix) else fa.stem
        rec = dict(iter_fasta(fa))
        length = len(next(iter(rec.values()))) if rec else 0
        end = pos + length - 1
        partitions.append({"gene": gene, "start": pos, "end": end})
        for sp in species:
            if sp in rec:
                seqs[sp].append(rec[sp])
                stats[sp]["present_genes"] += 1
            else:
                seqs[sp].append("-" * length)
                stats[sp]["missing_genes"] += 1
        pos = end + 1
    records = [(sp, "".join(parts)) for sp, parts in seqs.items()]
    for sp, seq in records:
        stats[sp]["sequence_length"] = len(seq)
    write_fasta(records, args.out_fasta)
    with open(args.out_partition, "w") as out:
        for p in partitions:
            out.write(f"{p['gene']} = {p['start']}-{p['end']}\n")
    write_tsv(args.out_stats, ["species", "present_genes", "missing_genes", "sequence_length"], stats.values())


if __name__ == "__main__":
    main()
