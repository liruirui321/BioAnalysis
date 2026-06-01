#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections import defaultdict
from pathlib import Path
import statistics
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import open_text, parse_gff_attributes, read_fasta, write_tsv

DETAIL_FIELDS = [
    "seqid", "start0", "end0", "start1", "end1", "length", "strand",
    "gene_id", "transcript_id", "intron_number", "source_feature", "is_short_intron",
    "at_content", "is_at_rich",
]


def split_parents(value: str) -> list[str]:
    return [x for x in value.split(",") if x]


def parse_annotation(gff: str, feature: str):
    segments = defaultdict(list)
    parent_to_gene = {}
    transcript_to_gene = {}
    child_to_transcript = {}

    with open_text(gff) as handle:
        for line in handle:
            if line.startswith("#") or not line.strip():
                continue
            cols = line.rstrip("\n").split("\t")
            if len(cols) < 9:
                continue
            seqid, _source, ftype, start, end, _score, strand, _phase, attr_text = cols
            attrs = parse_gff_attributes(attr_text)
            feature_id = attrs.get("ID")
            parents = split_parents(attrs.get("Parent", ""))
            gene_id = attrs.get("gene_id") or attrs.get("gene")

            if ftype == "gene" and feature_id:
                transcript_to_gene.setdefault(feature_id, feature_id)
            elif ftype in {"mRNA", "transcript"} and feature_id:
                if parents:
                    transcript_to_gene[feature_id] = parents[0]
                elif gene_id:
                    transcript_to_gene[feature_id] = gene_id

            if feature_id and parents:
                child_to_transcript[feature_id] = parents[0]

            if ftype != feature:
                continue
            if not parents:
                continue
            for parent in parents:
                tx = child_to_transcript.get(parent, parent)
                gene = gene_id or transcript_to_gene.get(tx) or transcript_to_gene.get(parent) or parent_to_gene.get(parent, "NA")
                parent_to_gene[tx] = gene
                segments[tx].append({
                    "seqid": seqid,
                    "start1": int(start),
                    "end1": int(end),
                    "strand": strand,
                    "gene_id": gene,
                })
    return segments, parent_to_gene


def at_content(seq: str) -> str:
    seq = seq.upper()
    bases = sum(1 for b in seq if b in {"A", "C", "G", "T"})
    if bases == 0:
        return "NA"
    at = seq.count("A") + seq.count("T")
    return f"{at / bases:.6f}"


def infer_introns(segments, feature, min_short, max_short, genome, at_rich_threshold):
    rows = []
    for tx, segs in segments.items():
        segs.sort(key=lambda x: (x["seqid"], x["start1"], x["end1"]))
        same_chrom = defaultdict(list)
        for seg in segs:
            same_chrom[seg["seqid"]].append(seg)
        for seqid, chrom_segs in same_chrom.items():
            chrom_segs.sort(key=lambda x: x["start1"])
            for idx in range(len(chrom_segs) - 1):
                left = chrom_segs[idx]
                right = chrom_segs[idx + 1]
                start0 = left["end1"]
                end0 = right["start1"] - 1
                if end0 <= start0:
                    continue
                length = end0 - start0
                at_value = "NA"
                is_at_rich = "NA"
                if genome is not None:
                    if seqid not in genome:
                        raise SystemExit(f"GFF seqid {seqid!r} is missing from genome FASTA")
                    at_value = at_content(genome[seqid][start0:end0])
                    is_at_rich = "NA" if at_value == "NA" else str(float(at_value) >= at_rich_threshold)
                rows.append({
                    "seqid": seqid,
                    "start0": start0,
                    "end0": end0,
                    "start1": start0 + 1,
                    "end1": end0,
                    "length": length,
                    "strand": left["strand"],
                    "gene_id": left.get("gene_id", "NA"),
                    "transcript_id": tx,
                    "intron_number": idx + 1,
                    "source_feature": feature,
                    "is_short_intron": str(min_short <= length <= max_short),
                    "at_content": at_value,
                    "is_at_rich": is_at_rich,
                })
    return rows


def unique_rows(rows):
    chosen = {}
    for row in rows:
        key = (row["seqid"], row["start0"], row["end0"], row["strand"])
        current = chosen.get(key)
        if current is None:
            chosen[key] = dict(row)
        else:
            current["transcript_id"] = ",".join(sorted(set(str(current["transcript_id"]).split(",") + [str(row["transcript_id"])])))
            current["gene_id"] = ",".join(sorted(set(str(current["gene_id"]).split(",") + [str(row["gene_id"])])))
    return list(chosen.values())


def write_bed(path, rows, name_field="transcript_id"):
    if not path:
        return
    out = Path(path)
    out.parent.mkdir(parents=True, exist_ok=True)
    with open(out, "w") as handle:
        for row in rows:
            name = f"{row[name_field]}.intron{row['intron_number']}" if name_field == "transcript_id" else row[name_field]
            handle.write(f"{row['seqid']}\t{row['start0']}\t{row['end0']}\t{name}\t{row['length']}\t{row['strand']}\n")


def summary_rows(all_rows, uniq_rows):
    def count_flag(rows, field):
        return sum(1 for row in rows if row.get(field) == "True")

    lengths = [int(row["length"]) for row in all_rows]
    return [
        {"metric": "transcripts_with_introns", "value": len({row["transcript_id"] for row in all_rows})},
        {"metric": "genes_with_introns", "value": len({row["gene_id"] for row in all_rows if row["gene_id"] != "NA"})},
        {"metric": "total_introns", "value": len(all_rows)},
        {"metric": "unique_introns", "value": len(uniq_rows)},
        {"metric": "short_introns", "value": count_flag(all_rows, "is_short_intron")},
        {"metric": "at_rich_introns", "value": count_flag(all_rows, "is_at_rich")},
        {"metric": "total_intron_bp", "value": sum(lengths)},
        {"metric": "mean_intron_length", "value": f"{statistics.mean(lengths):.6f}" if lengths else "0"},
        {"metric": "median_intron_length", "value": f"{statistics.median(lengths):.6f}" if lengths else "0"},
    ]


def chrom_summary(rows):
    by_chrom = defaultdict(list)
    for row in rows:
        by_chrom[row["seqid"]].append(row)
    out = []
    for seqid, vals in sorted(by_chrom.items()):
        lengths = [int(row["length"]) for row in vals]
        at_values = [float(row["at_content"]) for row in vals if row["at_content"] != "NA"]
        at_rich = sum(1 for row in vals if row["is_at_rich"] == "True")
        short = sum(1 for row in vals if row["is_short_intron"] == "True")
        out.append({
            "seqid": seqid,
            "unique_intron_count": len(vals),
            "short_intron_count": short,
            "at_rich_intron_count": at_rich,
            "at_rich_intron_ratio": f"{at_rich / len(vals):.6f}" if vals else "0",
            "total_intron_bp": sum(lengths),
            "mean_intron_length": f"{statistics.mean(lengths):.6f}" if lengths else "0",
            "mean_at_content": f"{statistics.mean(at_values):.6f}" if at_values else "NA",
        })
    return out


def main():
    ap = argparse.ArgumentParser(
        description="Infer introns from exon or CDS features in GFF3 and write BED/TSV summaries. BED output is 0-based half-open."
    )
    ap.add_argument("--gff", required=True)
    ap.add_argument("--out", required=True, help="All introns BED output")
    ap.add_argument("--short-out", default=None, help="Short introns BED output")
    ap.add_argument("--feature", default="exon", choices=["exon", "CDS"])
    ap.add_argument("--min-short", type=int, default=40)
    ap.add_argument("--max-short", type=int, default=65)
    ap.add_argument("--summary", default=None)
    ap.add_argument("--genome", default=None, help="Genome FASTA for intron AT-content calculation")
    ap.add_argument("--details-out", default=None, help="Detailed intron TSV output")
    ap.add_argument("--unique-bed", default=None, help="Deduplicated intron-locus BED output")
    ap.add_argument("--unique-details-out", default=None, help="Deduplicated intron-locus TSV output")
    ap.add_argument("--chrom-summary", default=None, help="Per-sequence intron summary TSV")
    ap.add_argument("--at-rich-threshold", type=float, default=0.70)
    args = ap.parse_args()

    genome = read_fasta(args.genome) if args.genome else None
    segments, _parent_to_gene = parse_annotation(args.gff, args.feature)
    rows = infer_introns(segments, args.feature, args.min_short, args.max_short, genome, args.at_rich_threshold)
    uniq = unique_rows(rows)

    write_bed(args.out, rows)
    if args.short_out:
        write_bed(args.short_out, [row for row in rows if row["is_short_intron"] == "True"])
    if args.unique_bed:
        write_bed(args.unique_bed, uniq, name_field="gene_id")
    if args.details_out:
        write_tsv(args.details_out, DETAIL_FIELDS, rows)
    if args.unique_details_out:
        write_tsv(args.unique_details_out, DETAIL_FIELDS, uniq)
    if args.summary:
        write_tsv(args.summary, ["metric", "value"], summary_rows(rows, uniq))
    if args.chrom_summary:
        write_tsv(args.chrom_summary, [
            "seqid", "unique_intron_count", "short_intron_count", "at_rich_intron_count",
            "at_rich_intron_ratio", "total_intron_bp", "mean_intron_length", "mean_at_content",
        ], chrom_summary(uniq))


if __name__ == "__main__":
    main()
