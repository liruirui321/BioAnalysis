#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections import defaultdict
from pathlib import Path
import re
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import read_tsv, write_tsv


def split_terms(value: str) -> list[str]:
    if not value or value == "NA":
        return []
    return sorted({part.strip().replace("ko:", "") for part in re.split(r"[;,|]\s*", value) if part.strip() and part.strip() != "NA"})


def load_ko_map(path):
    mapping = defaultdict(set)
    for row in read_tsv(path):
        ko = row.get("KO") or row.get("ko") or row.get("ko_id") or row.get("K")
        pathway = row.get("pathway_id") or row.get("Pathway") or row.get("map_id")
        if ko and pathway:
            mapping[ko.replace("ko:", "")].add(pathway)
    return mapping


def load_pathway_names(path):
    if not path:
        return {}
    names = {}
    for row in read_tsv(path):
        pid = row.get("pathway_id") or row.get("Pathway") or row.get("map_id")
        if not pid:
            continue
        names[pid] = {
            "pathway_name": row.get("pathway_name") or row.get("name") or row.get("description") or "NA",
            "level1": row.get("level1", "NA"),
            "level2": row.get("level2", "NA"),
        }
    return names


def main():
    ap = argparse.ArgumentParser(description="Summarize KEGG KO-to-pathway assignments from functional_annotation.tsv.")
    ap.add_argument("--annotation", required=True)
    ap.add_argument("--ko-map", required=True, help="TSV with KO and pathway_id columns")
    ap.add_argument("--out", required=True, help="Pathway count summary TSV")
    ap.add_argument("--gene2pathway", required=True, help="Long gene-to-KO/pathway TSV")
    ap.add_argument("--unmapped", required=True, help="KO IDs not found in the KO-to-pathway map")
    ap.add_argument("--pathway-names", default=None)
    ap.add_argument("--id-column", default="transcript_id")
    ap.add_argument("--ko-columns", default="KEGG_ko,Kofam_ko")
    args = ap.parse_args()

    ko_map = load_ko_map(args.ko_map)
    names = load_pathway_names(args.pathway_names)
    ko_columns = [x.strip() for x in args.ko_columns.split(",") if x.strip()]
    gene_rows = []
    by_pathway = defaultdict(set)
    pathway_kos = defaultdict(set)
    unmapped = defaultdict(set)

    for row in read_tsv(args.annotation):
        gid = row.get(args.id_column, "NA")
        if gid == "NA":
            continue
        kos = set()
        for col in ko_columns:
            kos.update(split_terms(row.get(col, "NA")))
        for ko in sorted(kos):
            pathways = ko_map.get(ko)
            if not pathways:
                unmapped[ko].add(gid)
                continue
            for pathway in sorted(pathways):
                meta = names.get(pathway, {"pathway_name": "NA", "level1": "NA", "level2": "NA"})
                by_pathway[pathway].add(gid)
                pathway_kos[pathway].add(ko)
                gene_rows.append({
                    "gene_id": gid,
                    "ko_id": ko,
                    "pathway_id": pathway,
                    **meta,
                })

    summary = []
    for pathway, genes in sorted(by_pathway.items(), key=lambda item: (-len(item[1]), item[0])):
        meta = names.get(pathway, {"pathway_name": "NA", "level1": "NA", "level2": "NA"})
        summary.append({
            "pathway_id": pathway,
            **meta,
            "gene_count": len(genes),
            "ko_ids": ";".join(sorted(pathway_kos[pathway])),
            "genes": ";".join(sorted(genes)),
        })
    unmapped_rows = [{"ko_id": ko, "gene_count": len(genes), "genes": ";".join(sorted(genes))} for ko, genes in sorted(unmapped.items())]

    write_tsv(args.gene2pathway, ["gene_id", "ko_id", "pathway_id", "pathway_name", "level1", "level2"], gene_rows)
    write_tsv(args.out, ["pathway_id", "pathway_name", "level1", "level2", "gene_count", "ko_ids", "genes"], summary)
    write_tsv(args.unmapped, ["ko_id", "gene_count", "genes"], unmapped_rows)


if __name__ == "__main__":
    main()
