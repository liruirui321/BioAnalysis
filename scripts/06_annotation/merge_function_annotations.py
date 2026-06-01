#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import ensure_file, open_text, parse_gff_attributes, read_tsv, write_tsv


def read_gff_features(path):
    ensure_file(path, "GFF3")
    rows = {}
    gene_for_tx = {}
    with open_text(path) as handle:
        for line in handle:
            if line.startswith("#") or not line.strip():
                continue
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 9:
                continue
            attrs = parse_gff_attributes(parts[8])
            feature = parts[2]
            fid = attrs.get("ID", "")
            parents = attrs.get("Parent", "")
            if feature == "gene" and fid:
                rows.setdefault(fid, {"gene_id": fid, "transcript_id": "NA", "seqid": parts[0], "start": parts[3], "end": parts[4], "strand": parts[6]})
            elif feature in {"mRNA", "transcript"} and fid:
                gid = parents.split(",")[0] if parents else fid
                gene_for_tx[fid] = gid
                rows[fid] = {"gene_id": gid, "transcript_id": fid, "seqid": parts[0], "start": parts[3], "end": parts[4], "strand": parts[6]}
    return rows, gene_for_tx


def map_by(rows, key):
    return {r.get(key, ""): r for r in rows if r.get(key)}


def collect_ipr(path):
    out = defaultdict(lambda: {"Pfam_ids": set(), "InterPro_ids": set(), "GO_terms": set()})
    if not path:
        return out
    for r in read_tsv(path):
        q = r.get("Query_id", "")
        if not q:
            continue
        if r.get("Subject_DB") == "Pfam" and r.get("Subject_id"):
            out[q]["Pfam_ids"].add(r["Subject_id"])
        if r.get("InterPro_id") and r.get("InterPro_id") != "NA":
            out[q]["InterPro_ids"].add(r["InterPro_id"])
        if r.get("GO_terms") and r.get("GO_terms") != "NA":
            out[q]["GO_terms"].update(x for x in r["GO_terms"].split("|") if x)
    return out


def read_besthit(path):
    if not path:
        return {}
    ensure_file(path, "besthit")
    hits = {}
    with open_text(path) as handle:
        for line in handle:
            if not line.strip() or line.startswith("#"):
                continue
            p = line.rstrip("\n").split("\t")
            if len(p) >= 2 and p[0] not in hits:
                hits[p[0]] = {"hit": p[1], "description": p[-1] if len(p) > 12 else "NA"}
    return hits


def main():
    ap = argparse.ArgumentParser(description="Merge functional annotation tables into one transcript-level TSV.")
    ap.add_argument("--gff", required=True)
    ap.add_argument("--cds-check", default=None)
    ap.add_argument("--iprscan", default=None)
    ap.add_argument("--eggnog", default=None)
    ap.add_argument("--kofam", default=None)
    ap.add_argument("--swissprot", default=None)
    ap.add_argument("--nr", default=None)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    gff_rows, _ = read_gff_features(args.gff)
    cds = map_by(read_tsv(args.cds_check), "transcript_id") if args.cds_check else {}
    ipr = collect_ipr(args.iprscan) if args.iprscan else {}
    kofam = map_by(read_tsv(args.kofam), "Query_id") if args.kofam else {}
    sp = read_besthit(args.swissprot) if args.swissprot else {}
    nr = read_besthit(args.nr) if args.nr else {}
    egg = map_by(read_tsv(args.eggnog), "#query") if args.eggnog else {}
    if not egg and args.eggnog:
        egg = map_by(read_tsv(args.eggnog), "query")

    fields = ["transcript_id", "gene_id", "seqid", "start", "end", "strand", "cds_len", "phase_ok", "start_ok", "terminal_stop", "internal_stop", "ambiguous_nt", "Pfam_ids", "InterPro_ids", "GO_terms", "eggNOG_ortholog", "COG_category", "KEGG_ko", "Kofam_ko", "SwissProt_best_hit", "SwissProt_description", "NR_best_hit", "NR_description"]
    out_rows = []
    for tid, base in sorted(gff_rows.items()):
        if base.get("transcript_id") == "NA":
            continue
        row = {k: "NA" for k in fields}
        row.update(base)
        row["transcript_id"] = tid
        if tid in cds:
            c = cds[tid]
            row.update({"cds_len": c.get("cds_len", c.get("len", "NA")), "phase_ok": c.get("phase_ok", "NA"), "start_ok": c.get("start_ok", "NA"), "terminal_stop": c.get("terminal_stop", "NA"), "internal_stop": c.get("internal_stop", "NA"), "ambiguous_nt": c.get("ambiguous_nt", "NA")})
        if tid in ipr:
            row["Pfam_ids"] = ";".join(sorted(ipr[tid]["Pfam_ids"])) or "NA"
            row["InterPro_ids"] = ";".join(sorted(ipr[tid]["InterPro_ids"])) or "NA"
            row["GO_terms"] = ";".join(sorted(ipr[tid]["GO_terms"])) or "NA"
        e = egg.get(tid, {})
        row["eggNOG_ortholog"] = e.get("seed_ortholog", e.get("eggNOG_ortholog", "NA"))
        row["COG_category"] = e.get("COG_category", "NA")
        row["KEGG_ko"] = e.get("KEGG_ko", e.get("KEGG_ko", "NA"))
        row["Kofam_ko"] = kofam.get(tid, {}).get("KO", "NA")
        row["SwissProt_best_hit"] = sp.get(tid, {}).get("hit", "NA")
        row["SwissProt_description"] = sp.get(tid, {}).get("description", "NA")
        row["NR_best_hit"] = nr.get(tid, {}).get("hit", "NA")
        row["NR_description"] = nr.get(tid, {}).get("description", "NA")
        out_rows.append(row)
    write_tsv(args.out, fields, out_rows)


if __name__ == "__main__":
    main()
