#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections import defaultdict
from pathlib import Path
import re
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import open_text, read_id_set, read_tsv, write_lines, write_tsv

EVIDENCE_FIELDS = [
    "gene_id", "family_id", "family_name", "evidence_type", "source_field", "rule_id",
    "matched_value", "evidence_score", "annotation_status",
]
SUMMARY_FIELDS = ["family_id", "family_name", "selected_genes", "evidence_rows", "evidence_types"]


def split_terms(value):
    if not value or value == "NA":
        return []
    return [part.strip() for part in re.split(r"[;,|]\s*", value) if part.strip() and part.strip() != "NA"]


def load_rules(path):
    rules = []
    for i, row in enumerate(read_tsv(path), start=1):
        family_id = row.get("family_id") or row.get("target_family") or row.get("family")
        if not family_id:
            continue
        rules.append({
            "rule_id": row.get("rule_id") or f"rule_{i}",
            "family_id": family_id,
            "family_name": row.get("family_name") or family_id,
            "evidence_type": (row.get("evidence_type") or row.get("type") or "keyword").lower(),
            "field": row.get("field") or row.get("source_field") or "description",
            "pattern": row.get("pattern") or row.get("value") or row.get("term") or "",
            "match_mode": (row.get("match_mode") or "contains").lower(),
            "score": row.get("score") or "1",
        })
    return rules


def row_id(row, id_column):
    return row.get(id_column) or row.get("transcript_id") or row.get("gene_id") or row.get("query") or row.get("#query") or "NA"


def matches(value, pattern, mode):
    if not pattern:
        return False
    value = value or ""
    if mode == "regex":
        return re.search(pattern, value, re.I) is not None
    if mode == "exact":
        return value.casefold() == pattern.casefold()
    if mode == "token":
        return pattern.casefold() in {term.casefold() for term in split_terms(value)}
    return pattern.casefold() in value.casefold()


def annotation_evidence(annotation, rules, id_column):
    rows = []
    for ann in annotation:
        gid = row_id(ann, id_column)
        if gid == "NA":
            continue
        for rule in rules:
            if rule["evidence_type"] not in {"keyword", "pfam", "interpro", "ko", "go", "annotation"}:
                continue
            field = rule["field"]
            if field == "description":
                value = "\t".join(str(v) for v in ann.values())
            elif field == "ko":
                value = ";".join([ann.get("KEGG_ko", ""), ann.get("Kofam_ko", ""), ann.get("KO_ids", "")])
            else:
                value = ann.get(field, "")
            mode = "token" if rule["evidence_type"] in {"pfam", "interpro", "ko", "go"} and rule["match_mode"] == "contains" else rule["match_mode"]
            if matches(value, rule["pattern"], mode):
                rows.append({
                    "gene_id": gid,
                    "family_id": rule["family_id"],
                    "family_name": rule["family_name"],
                    "evidence_type": rule["evidence_type"],
                    "source_field": field,
                    "rule_id": rule["rule_id"],
                    "matched_value": rule["pattern"],
                    "evidence_score": rule["score"],
                    "annotation_status": "matched",
                })
    return rows


def blast_evidence(path, rules, max_evalue, min_bitscore):
    if not path:
        return []
    blast_rules = [rule for rule in rules if rule["evidence_type"] in {"blast", "diamond"}]
    if not blast_rules:
        return []
    rows = []
    with open_text(path) as handle:
        for line in handle:
            if not line.strip() or line.startswith("#"):
                continue
            cols = line.rstrip("\n").split("\t")
            if len(cols) < 12:
                continue
            try:
                evalue = float(cols[10])
                bitscore = float(cols[11])
            except ValueError:
                continue
            if max_evalue is not None and evalue > max_evalue:
                continue
            if min_bitscore is not None and bitscore < min_bitscore:
                continue
            query, subject = cols[0], cols[1]
            for rule in blast_rules:
                value = subject if rule["field"] in {"subject", "subject_id", "description"} else "\t".join(cols)
                if matches(value, rule["pattern"], rule["match_mode"]):
                    rows.append({
                        "gene_id": query,
                        "family_id": rule["family_id"],
                        "family_name": rule["family_name"],
                        "evidence_type": rule["evidence_type"],
                        "source_field": rule["field"],
                        "rule_id": rule["rule_id"],
                        "matched_value": subject,
                        "evidence_score": f"{bitscore:.6f}",
                        "annotation_status": f"evalue={evalue:g}",
                    })
    return rows


def seed_evidence(seed_ids, rules):
    if not seed_ids:
        return []
    seed_rules = [rule for rule in rules if rule["evidence_type"] in {"seed", "candidate"}]
    if not seed_rules:
        return []
    ids = read_id_set(seed_ids)
    rows = []
    for gid in sorted(ids):
        for rule in seed_rules:
            if rule["pattern"] and not matches(gid, rule["pattern"], rule["match_mode"]):
                continue
            rows.append({
                "gene_id": gid,
                "family_id": rule["family_id"],
                "family_name": rule["family_name"],
                "evidence_type": rule["evidence_type"],
                "source_field": "seed_ids",
                "rule_id": rule["rule_id"],
                "matched_value": gid,
                "evidence_score": rule["score"],
                "annotation_status": "seed_list",
            })
    return rows


def summarize(rows):
    grouped = defaultdict(list)
    for row in rows:
        grouped[(row["family_id"], row["family_name"])].append(row)
    out = []
    for (family_id, family_name), vals in sorted(grouped.items()):
        out.append({
            "family_id": family_id,
            "family_name": family_name,
            "selected_genes": len({row["gene_id"] for row in vals}),
            "evidence_rows": len(vals),
            "evidence_types": ";".join(sorted({row["evidence_type"] for row in vals})),
        })
    return out


def main():
    ap = argparse.ArgumentParser(description="Merge rule-table, annotation, BLAST/DIAMOND, and seed evidence for target functional families.")
    ap.add_argument("--annotation", required=True)
    ap.add_argument("--rules", required=True, help="Target-family rule TSV")
    ap.add_argument("--out", required=True, help="Evidence TSV")
    ap.add_argument("--target-ids", required=True, help="Selected gene ID list")
    ap.add_argument("--summary", required=True)
    ap.add_argument("--blast-hits", default=None)
    ap.add_argument("--seed-ids", default=None)
    ap.add_argument("--id-column", default="transcript_id")
    ap.add_argument("--max-evalue", type=float, default=1e-5)
    ap.add_argument("--min-bitscore", type=float, default=None)
    args = ap.parse_args()

    rules = load_rules(args.rules)
    annotation = read_tsv(args.annotation)
    rows = []
    rows.extend(annotation_evidence(annotation, rules, args.id_column))
    rows.extend(blast_evidence(args.blast_hits, rules, args.max_evalue, args.min_bitscore))
    rows.extend(seed_evidence(args.seed_ids, rules))
    rows.sort(key=lambda row: (row["family_id"], row["gene_id"], row["evidence_type"], row["rule_id"]))
    write_tsv(args.out, EVIDENCE_FIELDS, rows)
    write_lines(args.target_ids, sorted({row["gene_id"] for row in rows}))
    write_tsv(args.summary, SUMMARY_FIELDS, summarize(rows))


if __name__ == "__main__":
    main()
