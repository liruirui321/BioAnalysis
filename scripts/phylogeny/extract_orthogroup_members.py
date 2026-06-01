#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import ensure_dir, ensure_file, open_text, read_id_set, write_lines, write_tsv


def read_targets(path):
    return read_id_set(path)


def read_id_map(path):
    if not path:
        return {}
    mp = {}
    with open_text(path) as handle:
        header = handle.readline().rstrip("\n").split("\t")
        for line in handle:
            p = line.rstrip("\n").split("\t")
            row = dict(zip(header, p))
            old = row.get("original_id") or row.get("original") or row.get("transcript_id")
            new = row.get("prefixed_id") or row.get("prefixed")
            if old and new:
                mp[old] = new
    return mp


def main():
    ap = argparse.ArgumentParser(description="Extract member ID lists for target OrthoFinder orthogroups.")
    ap.add_argument("--orthogroups", required=True)
    ap.add_argument("--target-list", required=True)
    ap.add_argument("--outdir", required=True)
    ap.add_argument("--id-map", default=None)
    ap.add_argument("--summary", default=None)
    args = ap.parse_args()
    targets = read_targets(args.target_list)
    idmap = read_id_map(args.id_map)
    outdir = ensure_dir(args.outdir)
    ensure_file(args.orthogroups, "Orthogroups.tsv")
    summary = []
    with open_text(args.orthogroups) as handle:
        header = handle.readline().rstrip("\n").split("\t")
        for line in handle:
            p = line.rstrip("\n").split("\t")
            if not p:
                continue
            og = p[0].rstrip(":")
            if og not in targets:
                continue
            members = []
            for cell in p[1:]:
                for gene in cell.replace(",", " ").split():
                    gene = gene.strip()
                    if gene:
                        members.append(idmap.get(gene, gene))
            members = sorted(dict.fromkeys(members))
            write_lines(outdir / f"{og}.ids", members)
            summary.append({"orthogroup": og, "member_count": len(members), "ids_file": str(outdir / f"{og}.ids")})
    if args.summary:
        write_tsv(args.summary, ["orthogroup", "member_count", "ids_file"], summary)


if __name__ == "__main__":
    main()
