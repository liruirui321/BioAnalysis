#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from pathlib import Path
import re
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.bioio import read_tsv, write_lines, write_tsv

SOURCE_PRIORITY = ["virus", "bacteria", "fungi", "metazoa", "archaea", "other"]
EVENTS = ["gain", "loss", "expansion", "contraction", "total"]


def source_key(value: str) -> str:
    return (value or "NA").strip()


def source_sort_key(value: str):
    lower = value.casefold()
    if lower in SOURCE_PRIORITY:
        return (SOURCE_PRIORITY.index(lower), lower)
    return (len(SOURCE_PRIORITY), lower)


def majority_source(values):
    counts = Counter(source_key(v) for v in values if v not in {None, "", "NA"})
    if not counts:
        return "NA"
    best_count = max(counts.values())
    tied = [k for k, v in counts.items() if v == best_count]
    return sorted(tied, key=source_sort_key)[0]


def split_members(value):
    if not value or value == "NA":
        return []
    return [part.strip() for part in re.split(r"[,;]\s*", value) if part.strip()]


def split_orthogroup_line(line: str):
    line = line.strip()
    if not line:
        return None, []
    if "\t" in line:
        parts = line.split("\t")
        og = parts[0].rstrip(":")
        members = []
        for value in parts[1:]:
            members.extend(split_members(value))
        return og, members
    if ":" in line:
        og, rest = line.split(":", 1)
        return og.strip(), rest.split()
    parts = line.split()
    return parts[0].rstrip(":"), parts[1:]


def read_orthogroups_text(path):
    groups = {}
    with open(path) as handle:
        for line in handle:
            og, members = split_orthogroup_line(line)
            if og:
                groups[og] = members
    return groups


def strip_source(member: str):
    if "--" in member:
        gene, source = member.rsplit("--", 1)
        return gene, source
    return member, "NA"


def read_count_matrix(path):
    rows = read_tsv(path)
    if not rows:
        return {}, []
    first = list(rows[0].keys())[0]
    matrix = {}
    columns = [c for c in rows[0].keys() if c != first]
    for row in rows:
        family = row[first]
        matrix[family] = {col: to_int(row.get(col)) for col in columns}
    return matrix, columns


def to_int(value):
    try:
        return int(float(value))
    except (TypeError, ValueError):
        return 0


def read_node_list(path):
    rows = []
    with open(path) as handle:
        for line in handle:
            if not line.strip() or line.startswith("#"):
                continue
            parts = line.strip().split()
            if len(parts) < 2:
                continue
            rows.append({"node": parts[0], "parent": parts[1]})
    return rows


def event_from_counts(node_count, parent_count):
    events = []
    if node_count > 0 and parent_count == 0:
        events.append("gain")
    if node_count == 0 and parent_count > 0:
        events.append("loss")
    if node_count > 1 and parent_count == 1:
        events.append("expansion")
    if node_count == 1 and parent_count > 1:
        events.append("contraction")
    if node_count > 0:
        events.append("total")
    return events


def build_all_gene_to_og(all_groups):
    mapping = {}
    sizes = {}
    for og, members in all_groups.items():
        clean = [strip_source(m)[0] for m in members]
        sizes[og] = len(clean)
        for gene in clean:
            mapping[gene] = og
    return mapping, sizes


def method1_flagged(all_groups, hgt_groups, min_ratio):
    hgt_sources = {}
    hgt_genes = set()
    for members in hgt_groups.values():
        for member in members:
            gene, source = strip_source(member)
            hgt_genes.add(gene)
            hgt_sources[gene] = source
    rows = []
    flagged = {}
    for og, members in all_groups.items():
        genes = [strip_source(m)[0] for m in members]
        total = len(genes)
        hgt_in_family = [g for g in genes if g in hgt_genes]
        ratio = len(hgt_in_family) / total if total else 0.0
        source = majority_source([hgt_sources[g] for g in hgt_in_family])
        is_hgt = ratio > min_ratio
        row = {"all_orthogroup": og, "total_genes": total, "hgt_genes": len(hgt_in_family), "hgt_ratio": f"{ratio:.6f}", "majority_source": source, "is_hgt_family": "yes" if is_hgt else "no"}
        rows.append(row)
        if is_hgt:
            flagged[og] = source
    return flagged, rows


def method2_mapping(all_groups, hgt_groups):
    gene_to_all, all_sizes = build_all_gene_to_og(all_groups)
    rows = []
    mapped = {}
    for hgt_og, members in hgt_groups.items():
        genes_sources = [strip_source(m) for m in members]
        genes = [g for g, _ in genes_sources]
        source = majority_source([s for _, s in genes_sources])
        overlaps = Counter(gene_to_all[g] for g in genes if g in gene_to_all)
        if overlaps:
            best_count = max(overlaps.values())
            tied = [og for og, count in overlaps.items() if count == best_count]
            best = sorted(tied, key=lambda og: (-(overlaps[og] / all_sizes.get(og, 1)), og))[0]
            overlap_rate = overlaps[best] / all_sizes.get(best, 1) if all_sizes.get(best, 0) else 0.0
        else:
            best = "NA"
            best_count = 0
            overlap_rate = 0.0
        rows.append({"hgt_orthogroup": hgt_og, "all_orthogroup": best, "overlap_gene_count": best_count, "hgt_gene_count": len(genes), "all_family_size": all_sizes.get(best, 0), "overlap_rate": f"{overlap_rate:.6f}", "majority_source": source})
        if best != "NA":
            mapped[best] = source
    return mapped, rows


def summarize_events(method_name, source_by_og, count_all, node_rows, outdir):
    detail = []
    summary = defaultdict(Counter)
    source_breakdown = defaultdict(Counter)
    lists_dir = outdir / "HGT_gain_expansion_OG"
    lists_dir.mkdir(parents=True, exist_ok=True)
    by_node_event = defaultdict(list)
    for og, source in source_by_og.items():
        counts = count_all.get(og, {})
        for item in node_rows:
            node = item["node"]
            parent = item["parent"]
            node_count = counts.get(node, 0)
            parent_count = counts.get(parent, 0)
            for event in event_from_counts(node_count, parent_count):
                detail.append({"method": method_name, "node": node, "parent": parent, "all_orthogroup": og, "majority_source": source, "event": event, "node_count": node_count, "parent_count": parent_count})
                summary[(node, parent)][event] += 1
                source_breakdown[(node, event)][source] += 1
                if event in {"gain", "expansion"}:
                    by_node_event[(node, event)].append(f"{og}\t{source}")
    for (node, event), lines in by_node_event.items():
        write_lines(lists_dir / f"{node}.hgt_driven.{event}.og", sorted(lines))
    summary_rows = []
    for (node, parent), counts in sorted(summary.items()):
        row = {"method": method_name, "node": node, "parent": parent}
        for event in EVENTS:
            row[event] = counts.get(event, 0)
        row["hgt_gain_expansion"] = counts.get("gain", 0) + counts.get("expansion", 0)
        summary_rows.append(row)
    source_rows = []
    for (node, event), counts in sorted(source_breakdown.items()):
        for source, count in sorted(counts.items(), key=lambda kv: source_sort_key(kv[0])):
            source_rows.append({"method": method_name, "node": node, "event": event, "majority_source": source, "orthogroup_count": count})
    return detail, summary_rows, source_rows


def main():
    ap = argparse.ArgumentParser(description="Summarize gene-centric or family-centric HGT-driven gain/expansion events across nodes or species.")
    ap.add_argument("--method", choices=["m1", "m2"], required=True)
    ap.add_argument("--count-all", required=True, help="ALL orthogroup count matrix")
    ap.add_argument("--node-list", required=True, help="Two-column node/species parent table")
    ap.add_argument("--txt-hgt", required=True, help="Orthogroups.HGT.txt style HGT orthogroup membership with gene--source IDs")
    ap.add_argument("--txt-all", required=True, help="Orthogroups.all.txt style all-gene orthogroup membership")
    ap.add_argument("--outdir", required=True)
    ap.add_argument("--count-hgt", default=None, help="HGT orthogroup count matrix; recorded for method m2 provenance")
    ap.add_argument("--min-hgt-ratio", type=float, default=0.3, help="Method m1 HGT family ratio cutoff; requires ratio > cutoff")
    args = ap.parse_args()

    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    all_groups = read_orthogroups_text(args.txt_all)
    hgt_groups = read_orthogroups_text(args.txt_hgt)
    count_all, _ = read_count_matrix(args.count_all)
    node_rows = read_node_list(args.node_list)

    if args.method == "m1":
        source_by_og, flag_rows = method1_flagged(all_groups, hgt_groups, args.min_hgt_ratio)
        write_tsv(outdir / "M1_Flagged_OG_Source_Breakdown.tsv", ["all_orthogroup", "total_genes", "hgt_genes", "hgt_ratio", "majority_source", "is_hgt_family"], flag_rows)
        method_name = "M1_gene_centric"
    else:
        source_by_og, map_rows = method2_mapping(all_groups, hgt_groups)
        write_tsv(outdir / "HGT_Global_Mapping.tsv", ["hgt_orthogroup", "all_orthogroup", "overlap_gene_count", "hgt_gene_count", "all_family_size", "overlap_rate", "majority_source"], map_rows)
        method_name = "M2_family_centric"

    detail, summary, source_rows = summarize_events(method_name, source_by_og, count_all, node_rows, outdir)
    prefix = "M1" if args.method == "m1" else "M2"
    write_tsv(outdir / f"{prefix}_Event_Detail.tsv", ["method", "node", "parent", "all_orthogroup", "majority_source", "event", "node_count", "parent_count"], detail)
    write_tsv(outdir / f"{prefix}_Summary_Evolution.tsv", ["method", "node", "parent", *EVENTS, "hgt_gain_expansion"], summary)
    write_tsv(outdir / f"{prefix}_HGT_Source_Breakdown.tsv", ["method", "node", "event", "majority_source", "orthogroup_count"], source_rows)
    write_tsv(outdir / f"{prefix}_hgt_family_event_manifest.tsv", ["field", "value"], [
        {"field": "method", "value": args.method},
        {"field": "count_all", "value": args.count_all},
        {"field": "count_hgt", "value": args.count_hgt or "NA"},
        {"field": "node_list", "value": args.node_list},
        {"field": "txt_hgt", "value": args.txt_hgt},
        {"field": "txt_all", "value": args.txt_all},
        {"field": "min_hgt_ratio", "value": args.min_hgt_ratio},
        {"field": "hgt_family_count", "value": len(source_by_og)},
    ])


if __name__ == "__main__":
    main()
