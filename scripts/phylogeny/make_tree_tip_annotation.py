#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import read_tsv, write_tsv


def read_map(path):
    if not path:
        return {}
    out = {}
    for r in read_tsv(path):
        pid = r.get("prefixed_id") or r.get("tip_id")
        oid = r.get("original_id") or r.get("transcript_id")
        pref = r.get("prefix", "NA")
        if pid:
            out[pid] = {"transcript_id": oid or pid, "species": pref}
    return out


def main():
    ap = argparse.ArgumentParser(description="Make tree tip annotation table from functional annotation and optional ID map.")
    ap.add_argument("--functional-annotation", required=True)
    ap.add_argument("--id-map", default=None)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    ann = {r.get("transcript_id", r.get("gene_id", "")): r for r in read_tsv(args.functional_annotation)}
    idmap = read_map(args.id_map)
    rows = []
    if idmap:
        for tip, m in sorted(idmap.items()):
            tid = m["transcript_id"]
            a = ann.get(tid, {})
            rows.append({"tip_id": tip, "species": m.get("species", "NA"), "transcript_id": tid, "gene_id": a.get("gene_id", "NA"), "label": tip, "Pfam_ids": a.get("Pfam_ids", "NA"), "KEGG_ko": a.get("KEGG_ko", "NA"), "description": a.get("SwissProt_description", "NA")})
    else:
        for tid, a in sorted(ann.items()):
            rows.append({"tip_id": tid, "species": a.get("species", "NA"), "transcript_id": tid, "gene_id": a.get("gene_id", "NA"), "label": tid, "Pfam_ids": a.get("Pfam_ids", "NA"), "KEGG_ko": a.get("KEGG_ko", "NA"), "description": a.get("SwissProt_description", "NA")})
    write_tsv(args.out, ["tip_id", "species", "transcript_id", "gene_id", "label", "Pfam_ids", "KEGG_ko", "description"], rows)


if __name__ == "__main__":
    main()
