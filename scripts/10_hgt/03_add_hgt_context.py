#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections import defaultdict
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import open_text, parse_gff_attributes, read_tsv, write_tsv

FIELDS = [
    "query_id", "gene_id", "transcript_id", "seqid", "start", "end", "strand",
    "best_donor_taxon", "best_donor_group", "alien_index", "bitscore_delta",
    "Pfam_ids", "KEGG_ko", "description", "intron_count", "short_intron_count",
    "mean_intron_at", "at_rich_intron_ratio", "synteny_support_status",
    "missing_data_note", "validation_priority",
]


def get_first(row, names, default="NA"):
    for name in names:
        if name in row and row[name] not in {"", None}:
            return row[name]
    return default


def parse_gff_coords(path):
    coords = {}
    with open_text(path) as handle:
        for line in handle:
            if line.startswith("#") or not line.strip():
                continue
            cols = line.rstrip("\n").split("\t")
            if len(cols) < 9:
                continue
            if cols[2] not in {"gene", "mRNA", "transcript"}:
                continue
            attrs = parse_gff_attributes(cols[8])
            ids = [attrs.get("ID"), attrs.get("Name")]
            if attrs.get("Parent"):
                ids.extend(attrs.get("Parent", "").split(","))
            for item in ids:
                if item:
                    coords[item] = {"seqid": cols[0], "start": cols[3], "end": cols[4], "strand": cols[6]}
    return coords


def load_annotation(path):
    if not path:
        return {}
    out = {}
    for row in read_tsv(path):
        key = get_first(row, ["gene_id", "transcript_id", "query_id", "ID"])
        if key != "NA":
            out[key] = row
    return out


def load_intron(path):
    if not path:
        return {}
    vals = defaultdict(list)
    for row in read_tsv(path):
        for key in [row.get("gene_id"), row.get("transcript_id")]:
            if key and key != "NA":
                vals[key].append(row)
    return vals


def load_synteny(path):
    if not path:
        return {}
    status = {}
    for row in read_tsv(path):
        gene = get_first(row, ["gene_id", "query_id", "transcript_id"])
        if gene != "NA":
            status[gene] = get_first(row, ["synteny_support_status", "status", "support"], "present")
    return status


def intron_metrics(rows):
    if not rows:
        return {"intron_count": "NA", "short_intron_count": "NA", "mean_intron_at": "NA", "at_rich_intron_ratio": "NA"}
    short = sum(1 for row in rows if row.get("is_short_intron") == "True")
    at_vals = [float(row["at_content"]) for row in rows if row.get("at_content") not in {None, "", "NA"}]
    at_rich_vals = [row for row in rows if row.get("is_at_rich") in {"True", "False"}]
    at_rich = sum(1 for row in at_rich_vals if row.get("is_at_rich") == "True")
    return {
        "intron_count": len(rows),
        "short_intron_count": short,
        "mean_intron_at": f"{sum(at_vals) / len(at_vals):.6f}" if at_vals else "NA",
        "at_rich_intron_ratio": f"{at_rich / len(at_rich_vals):.6f}" if at_rich_vals else "NA",
    }


def main():
    ap = argparse.ArgumentParser(description="Merge HGT candidate calls with genomic, annotation, intron, and synteny context.")
    ap.add_argument("--candidates", required=True)
    ap.add_argument("--gff", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--bed", default=None)
    ap.add_argument("--summary", default=None)
    ap.add_argument("--functional-annotation", default=None)
    ap.add_argument("--intron-details", default=None)
    ap.add_argument("--synteny", default=None)
    args = ap.parse_args()

    coords = parse_gff_coords(args.gff)
    anno = load_annotation(args.functional_annotation)
    introns = load_intron(args.intron_details)
    synteny = load_synteny(args.synteny)
    rows = []
    bed_rows = []

    for cand in read_tsv(args.candidates):
        query = cand["query_id"]
        ann = anno.get(query, {})
        gene = get_first(ann, ["gene_id"], query)
        transcript = get_first(ann, ["transcript_id"], query)
        loc = coords.get(query) or coords.get(gene) or coords.get(transcript) or {"seqid": "NA", "start": "NA", "end": "NA", "strand": "NA"}
        intron = intron_metrics(introns.get(query) or introns.get(gene) or introns.get(transcript) or [])
        missing = []
        if not args.functional_annotation:
            missing.append("functional_annotation")
        if not args.intron_details:
            missing.append("intron_details")
        if not args.synteny:
            missing.append("synteny")
        syn_status = synteny.get(query) or synteny.get(gene) or synteny.get(transcript) or ("missing" if args.synteny else "not_tested")
        priority = "high" if cand.get("candidate_status") == "candidate" and syn_status in {"absent", "missing", "not_tested"} else "review"
        row = {
            "query_id": query,
            "gene_id": gene,
            "transcript_id": transcript,
            "seqid": loc["seqid"],
            "start": loc["start"],
            "end": loc["end"],
            "strand": loc["strand"],
            "best_donor_taxon": cand.get("best_donor_taxon", "NA"),
            "best_donor_group": cand.get("best_donor_group", "NA"),
            "alien_index": cand.get("alien_index", "NA"),
            "bitscore_delta": cand.get("bitscore_delta", "NA"),
            "Pfam_ids": get_first(ann, ["Pfam_ids", "pfam", "Pfam"], "NA"),
            "KEGG_ko": get_first(ann, ["KEGG_ko", "KO", "ko"], "NA"),
            "description": get_first(ann, ["description", "SwissProt_description", "eggnog_desc"], "NA"),
            "synteny_support_status": syn_status,
            "missing_data_note": ";".join(missing) if missing else "none",
            "validation_priority": priority,
            **intron,
        }
        rows.append(row)
        if loc["seqid"] != "NA":
            bed_rows.append(row)

    write_tsv(args.out, FIELDS, rows)
    if args.bed:
        out = Path(args.bed)
        out.parent.mkdir(parents=True, exist_ok=True)
        with open(out, "w") as handle:
            for row in bed_rows:
                handle.write(f"{row['seqid']}\t{int(row['start']) - 1}\t{row['end']}\t{row['query_id']}\t0\t{row['strand']}\n")
    if args.summary:
        counts = defaultdict(int)
        for row in rows:
            counts[row["validation_priority"]] += 1
        write_tsv(args.summary, ["metric", "value"], [{"metric": k, "value": v} for k, v in sorted(counts.items())])


if __name__ == "__main__":
    main()
