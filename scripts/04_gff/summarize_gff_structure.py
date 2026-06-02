#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from pathlib import Path
import statistics
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import open_text, parse_gff_attributes, read_fasta, write_tsv

METRIC_FIELDS = ["species", "metric", "value"]
DISTRIBUTION_FIELDS = ["species", "category", "feature_id", "parent_id", "seqid", "length", "count", "note"]
CHROM_FIELDS = ["species", "seqid", "gene_count", "transcript_count", "gene_bp", "mean_gene_length", "gene_density_per_mb"]
FEATURE_FIELDS = ["species", "feature_type", "count", "total_bp", "mean_length", "median_length"]
QC_FIELDS = ["species", "check", "status", "details"]
REFERENCE_DISTRIBUTION_FIELDS = ["species", "category", "bin_start", "percent", "raw_count", "total_count", "bin_size"]


def to_int(value, default=None):
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def parent_ids(value):
    return [item for item in value.split(",") if item]


def parse_gff(path):
    features = []
    id_counts = Counter()
    seen_ids = set()
    duplicate_ids = set()
    missing_parent = 0
    with open_text(path) as handle:
        for line in handle:
            if not line.strip() or line.startswith("#"):
                continue
            cols = line.rstrip("\n").split("\t")
            if len(cols) < 9:
                continue
            start = to_int(cols[3])
            end = to_int(cols[4])
            if start is None or end is None:
                continue
            attrs = parse_gff_attributes(cols[8])
            fid = attrs.get("ID") or "NA"
            parents = parent_ids(attrs.get("Parent", ""))
            if fid != "NA":
                id_counts[fid] += 1
                if fid in seen_ids:
                    duplicate_ids.add(fid)
                seen_ids.add(fid)
            if cols[2] not in {"gene", "mRNA", "transcript"} and not parents:
                missing_parent += 1
            features.append({
                "seqid": cols[0],
                "source": cols[1],
                "type": cols[2],
                "start": start,
                "end": end,
                "strand": cols[6],
                "attrs": attrs,
                "id": fid,
                "parents": parents,
                "length": max(0, end - start + 1),
            })
    return features, {"duplicate_ids": duplicate_ids, "missing_parent": missing_parent}


def transcript_types(value):
    return value in {"mRNA", "transcript"} or value.endswith("RNA")


def percentile(values, q):
    if not values:
        return "NA"
    values = sorted(values)
    idx = (len(values) - 1) * q
    lo = int(idx)
    hi = min(lo + 1, len(values) - 1)
    if lo == hi:
        return values[lo]
    return values[lo] + (values[hi] - values[lo]) * (idx - lo)


def number(value):
    if value == "NA":
        return value
    if isinstance(value, float):
        return f"{value:.6f}"
    return value


def length_stats(values):
    if not values:
        return {"count": 0, "total_bp": 0, "mean_length": "NA", "median_length": "NA"}
    return {
        "count": len(values),
        "total_bp": sum(values),
        "mean_length": f"{statistics.mean(values):.6f}",
        "median_length": f"{statistics.median(values):.6f}",
    }


def binned_distribution(species, category, values, bin_size, add_zero=False):
    values = [int(value) for value in values if value is not None]
    total = len(values)
    rows = []
    if add_zero:
        rows.append({"species": species, "category": category, "bin_start": 0, "percent": "0.00000", "raw_count": 0, "total_count": total, "bin_size": bin_size})
    if total == 0:
        return rows
    counts = Counter(int(value / bin_size) for value in values)
    for bucket in sorted(counts):
        rows.append({
            "species": species,
            "category": category,
            "bin_start": bucket * bin_size,
            "percent": f"{counts[bucket] / total * 100:.5f}",
            "raw_count": counts[bucket],
            "total_count": total,
            "bin_size": bin_size,
        })
    return rows


def representative_gene_id(feature, transcript_to_gene):
    if feature["type"] == "gene":
        return feature["id"]
    if transcript_types(feature["type"]):
        return feature["parents"][0] if feature["parents"] else feature["id"]
    for parent in feature["parents"]:
        if parent in transcript_to_gene:
            return transcript_to_gene[parent]
    return feature["parents"][0] if feature["parents"] else "NA"


def infer_introns(transcripts, child_by_tx):
    rows = []
    for tx, rec in transcripts.items():
        segments = [child for child in child_by_tx.get(tx, []) if child["type"] in {"exon", "CDS"}]
        exon_segments = [child for child in segments if child["type"] == "exon"] or [child for child in segments if child["type"] == "CDS"]
        exon_segments.sort(key=lambda row: (row["seqid"], row["start"], row["end"]))
        for idx in range(len(exon_segments) - 1):
            left = exon_segments[idx]
            right = exon_segments[idx + 1]
            if left["seqid"] != right["seqid"]:
                continue
            start = left["end"] + 1
            end = right["start"] - 1
            if end >= start:
                rows.append({
                    "transcript_id": tx,
                    "gene_id": rec["gene_id"],
                    "seqid": left["seqid"],
                    "length": end - start + 1,
                })
    return rows


def summarize_species(species, gff_path, genome_path=None):
    features, parse_qc = parse_gff(gff_path)
    genome = read_fasta(genome_path) if genome_path else None
    genome_lengths = {seqid: len(seq) for seqid, seq in genome.items()} if genome else {}
    feature_ids = {f["id"] for f in features if f["id"] != "NA"}
    genes = {}
    transcripts = {}
    transcript_to_gene = {}
    child_by_tx = defaultdict(list)
    children_by_gene = defaultdict(list)
    feature_lengths = defaultdict(list)
    out_of_bounds = 0

    for feature in features:
        feature_lengths[feature["type"]].append(feature["length"])
        if genome_lengths and (feature["seqid"] not in genome_lengths or feature["end"] > genome_lengths.get(feature["seqid"], 0) or feature["start"] < 1):
            out_of_bounds += 1
        if feature["type"] == "gene" and feature["id"] != "NA":
            genes[feature["id"]] = feature
        elif transcript_types(feature["type"]) and feature["id"] != "NA":
            gene_id = feature["parents"][0] if feature["parents"] else "NA"
            transcripts[feature["id"]] = {**feature, "gene_id": gene_id}
            transcript_to_gene[feature["id"]] = gene_id

    for feature in features:
        if feature["type"] in {"gene", "mRNA", "transcript"}:
            continue
        for parent in feature["parents"]:
            child_by_tx[parent].append(feature)

    for feature in features:
        gene_id = representative_gene_id(feature, transcript_to_gene)
        if gene_id != "NA":
            children_by_gene[gene_id].append(feature)

    introns = infer_introns(transcripts, child_by_tx)
    isoforms_by_gene = defaultdict(set)
    for tx, rec in transcripts.items():
        if rec["gene_id"] != "NA":
            isoforms_by_gene[rec["gene_id"]].add(tx)
    exon_count_by_tx = defaultdict(int)
    cds_count_by_tx = defaultdict(int)
    for tx, children in child_by_tx.items():
        exon_count_by_tx[tx] = sum(1 for child in children if child["type"] == "exon")
        cds_count_by_tx[tx] = sum(1 for child in children if child["type"] == "CDS")

    gene_lengths = [feature["length"] for feature in genes.values()]
    tx_lengths = [feature["length"] for feature in transcripts.values()]
    exon_lengths = feature_lengths.get("exon", [])
    cds_lengths = feature_lengths.get("CDS", [])
    intron_lengths = [row["length"] for row in introns]
    isoform_counts = [len(vals) for vals in isoforms_by_gene.values()]
    exon_counts = list(exon_count_by_tx.values())
    cds_counts = list(cds_count_by_tx.values())

    metrics = []
    for metric, value in [
        ("feature_records", len(features)),
        ("genes", len(genes)),
        ("transcripts", len(transcripts)),
        ("exons", len(exon_lengths)),
        ("cds_features", len(cds_lengths)),
        ("introns", len(intron_lengths)),
        ("single_exon_transcripts", sum(1 for value in exon_counts if value == 1)),
        ("multi_exon_transcripts", sum(1 for value in exon_counts if value > 1)),
        ("genes_with_isoforms", sum(1 for value in isoform_counts if value > 1)),
        ("mean_gene_length", statistics.mean(gene_lengths) if gene_lengths else "NA"),
        ("median_gene_length", statistics.median(gene_lengths) if gene_lengths else "NA"),
        ("mean_transcript_length", statistics.mean(tx_lengths) if tx_lengths else "NA"),
        ("mean_exon_length", statistics.mean(exon_lengths) if exon_lengths else "NA"),
        ("mean_cds_feature_length", statistics.mean(cds_lengths) if cds_lengths else "NA"),
        ("mean_intron_length", statistics.mean(intron_lengths) if intron_lengths else "NA"),
        ("median_intron_length", statistics.median(intron_lengths) if intron_lengths else "NA"),
        ("mean_exons_per_transcript", statistics.mean(exon_counts) if exon_counts else "NA"),
        ("mean_isoforms_per_gene", statistics.mean(isoform_counts) if isoform_counts else "NA"),
    ]:
        metrics.append({"species": species, "metric": metric, "value": number(value)})

    reference_distribution = []
    reference_distribution.extend(binned_distribution(species, "mRNA_length", tx_lengths, 50))
    reference_distribution.extend(binned_distribution(species, "CDS_length", cds_lengths, 50))
    reference_distribution.extend(binned_distribution(species, "exon_length", exon_lengths, 10))
    reference_distribution.extend(binned_distribution(species, "intron_length", intron_lengths, 10))
    reference_distribution.extend(binned_distribution(species, "exon_number", exon_counts, 1, add_zero=True))

    distribution = []
    for gid, feature in sorted(genes.items()):
        distribution.append({"species": species, "category": "gene_length", "feature_id": gid, "parent_id": "NA", "seqid": feature["seqid"], "length": feature["length"], "count": "NA", "note": "NA"})
    for tx, feature in sorted(transcripts.items()):
        distribution.append({"species": species, "category": "mRNA_length", "feature_id": tx, "parent_id": feature["gene_id"], "seqid": feature["seqid"], "length": feature["length"], "count": "NA", "note": "NA"})
        distribution.append({"species": species, "category": "transcript_length", "feature_id": tx, "parent_id": feature["gene_id"], "seqid": feature["seqid"], "length": feature["length"], "count": "NA", "note": "alias_of_mRNA_length"})
        distribution.append({"species": species, "category": "exons_per_transcript", "feature_id": tx, "parent_id": feature["gene_id"], "seqid": feature["seqid"], "length": "NA", "count": exon_count_by_tx.get(tx, 0), "note": "NA"})
        distribution.append({"species": species, "category": "cds_features_per_transcript", "feature_id": tx, "parent_id": feature["gene_id"], "seqid": feature["seqid"], "length": "NA", "count": cds_count_by_tx.get(tx, 0), "note": "NA"})
    for feature in features:
        if feature["type"] in {"exon", "CDS"}:
            distribution.append({"species": species, "category": f"{feature['type']}_length", "feature_id": feature["id"], "parent_id": ";".join(feature["parents"]) or "NA", "seqid": feature["seqid"], "length": feature["length"], "count": "NA", "note": "NA"})
    for row in introns:
        distribution.append({"species": species, "category": "intron_length", "feature_id": row["transcript_id"], "parent_id": row["gene_id"], "seqid": row["seqid"], "length": row["length"], "count": "NA", "note": "NA"})
    for gid, txs in sorted(isoforms_by_gene.items()):
        distribution.append({"species": species, "category": "isoforms_per_gene", "feature_id": gid, "parent_id": "NA", "seqid": genes.get(gid, {}).get("seqid", "NA"), "length": "NA", "count": len(txs), "note": "NA"})

    chrom = []
    genes_by_seq = defaultdict(list)
    tx_by_seq = defaultdict(list)
    for feature in genes.values():
        genes_by_seq[feature["seqid"]].append(feature)
    for feature in transcripts.values():
        tx_by_seq[feature["seqid"]].append(feature)
    for seqid in sorted(set(genes_by_seq) | set(tx_by_seq) | set(genome_lengths)):
        vals = genes_by_seq.get(seqid, [])
        lengths = [row["length"] for row in vals]
        span = genome_lengths.get(seqid) or max([row["end"] for row in vals], default=0)
        chrom.append({
            "species": species,
            "seqid": seqid,
            "gene_count": len(vals),
            "transcript_count": len(tx_by_seq.get(seqid, [])),
            "gene_bp": sum(lengths),
            "mean_gene_length": f"{statistics.mean(lengths):.6f}" if lengths else "NA",
            "gene_density_per_mb": f"{len(vals) / (span / 1_000_000):.6f}" if span else "NA",
        })

    feature_summary = []
    for feature_type, lengths in sorted(feature_lengths.items()):
        stats = length_stats(lengths)
        feature_summary.append({"species": species, "feature_type": feature_type, **stats})

    missing_parent_refs = sorted({parent for feature in features for parent in feature["parents"] if parent not in feature_ids})
    qc = [
        {"species": species, "check": "duplicate_ids", "status": "fail" if parse_qc["duplicate_ids"] else "pass", "details": ";".join(sorted(parse_qc["duplicate_ids"])) or "none"},
        {"species": species, "check": "child_features_without_parent", "status": "warn" if parse_qc["missing_parent"] else "pass", "details": str(parse_qc["missing_parent"])},
        {"species": species, "check": "missing_parent_references", "status": "fail" if missing_parent_refs else "pass", "details": ";".join(missing_parent_refs[:50]) or "none"},
        {"species": species, "check": "seqids_in_genome", "status": "pass" if not genome_path or out_of_bounds == 0 else "fail", "details": str(out_of_bounds) if genome_path else "not_tested"},
    ]
    return metrics, distribution, chrom, feature_summary, qc, reference_distribution


def read_manifest(path):
    rows = []
    with open_text(path) as handle:
        header = handle.readline().rstrip("\n").split("\t")
        for line in handle:
            if not line.strip():
                continue
            row = dict(zip(header, line.rstrip("\n").split("\t")))
            species = row.get("species") or row.get("species_id") or row.get("name")
            gff = row.get("gff") or row.get("annotation_gff") or row.get("input_gff")
            genome = row.get("genome") or row.get("genome_fasta") or row.get("fasta") or None
            if species and gff:
                rows.append((species, gff, genome if genome and genome != "NA" else None))
    return rows


def main():
    ap = argparse.ArgumentParser(description="Summarize GFF/GFF3 gene-structure statistics and QC metrics for one or more species.")
    ap.add_argument("--gff", default=None)
    ap.add_argument("--species", default=None)
    ap.add_argument("--genome", default=None, help="Optional genome FASTA for seqid and out-of-bounds QC")
    ap.add_argument("--manifest", default=None, help="Optional TSV with species, gff, and optional genome columns")
    ap.add_argument("--out-prefix", required=True)
    args = ap.parse_args()

    inputs = []
    if args.manifest:
        inputs.extend(read_manifest(args.manifest))
    if args.gff:
        inputs.append((args.species or Path(args.gff).stem, args.gff, args.genome))
    if not inputs:
        raise SystemExit("Provide --gff or --manifest")

    all_metrics = []
    all_distribution = []
    all_chrom = []
    all_features = []
    all_qc = []
    all_reference_distribution = []
    for species, gff, genome in inputs:
        metrics, distribution, chrom, feature_summary, qc, reference_distribution = summarize_species(species, gff, genome)
        all_metrics.extend(metrics)
        all_distribution.extend(distribution)
        all_chrom.extend(chrom)
        all_features.extend(feature_summary)
        all_qc.extend(qc)
        all_reference_distribution.extend(reference_distribution)

    write_tsv(f"{args.out_prefix}.metrics.tsv", METRIC_FIELDS, all_metrics)
    write_tsv(f"{args.out_prefix}.distributions.tsv", DISTRIBUTION_FIELDS, all_distribution)
    write_tsv(f"{args.out_prefix}.chrom_summary.tsv", CHROM_FIELDS, all_chrom)
    write_tsv(f"{args.out_prefix}.feature_summary.tsv", FEATURE_FIELDS, all_features)
    write_tsv(f"{args.out_prefix}.qc.tsv", QC_FIELDS, all_qc)
    write_tsv(f"{args.out_prefix}.reference_distribution.tsv", REFERENCE_DISTRIBUTION_FIELDS, all_reference_distribution)


if __name__ == "__main__":
    main()
