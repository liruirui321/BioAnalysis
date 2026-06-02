#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run_genome_features_workflow.sh --gff annotation.gff3 --genome genome.fa --outdir genome_features [options]

Chain the Stage 05 genome-feature workflow:
  1. Extract all, short, unique, detailed, and per-chromosome intron outputs.
  2. Optionally run the external Introner-elements workflow.

Required:
  --gff FILE              Annotation GFF/GFF3
  --genome FILE           Genome FASTA
  --outdir DIR            Output directory

Options:
  --prefix NAME           Output prefix [GFF basename]
  --feature exon|CDS      Feature type used to infer introns [exon]
  --min-short INT         Minimum short intron length [40]
  --max-short INT         Maximum short intron length [65]
  --at-rich-threshold F   AT-rich threshold [0.70]
  --introner-tool-dir DIR External Introner-elements directory
  --directory-list FILE   Introner-elements directory_list.tsv
  --python CMD            Python executable [python3]
  --skip-introner         Do not run Introner-elements even if tool inputs are present
  -h, --help              Show this help
USAGE
}

gff=""
genome=""
outdir=""
prefix=""
feature="exon"
min_short=40
max_short=65
at_rich_threshold="0.70"
introner_tool_dir=""
directory_list=""
python_cmd="python3"
skip_introner=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --gff) gff=${2:?"Missing value for --gff"}; shift 2 ;;
    --genome) genome=${2:?"Missing value for --genome"}; shift 2 ;;
    --outdir) outdir=${2:?"Missing value for --outdir"}; shift 2 ;;
    --prefix) prefix=${2:?"Missing value for --prefix"}; shift 2 ;;
    --feature) feature=${2:?"Missing value for --feature"}; shift 2 ;;
    --min-short) min_short=${2:?"Missing value for --min-short"}; shift 2 ;;
    --max-short) max_short=${2:?"Missing value for --max-short"}; shift 2 ;;
    --at-rich-threshold) at_rich_threshold=${2:?"Missing value for --at-rich-threshold"}; shift 2 ;;
    --introner-tool-dir) introner_tool_dir=${2:?"Missing value for --introner-tool-dir"}; shift 2 ;;
    --directory-list) directory_list=${2:?"Missing value for --directory-list"}; shift 2 ;;
    --python) python_cmd=${2:?"Missing value for --python"}; shift 2 ;;
    --skip-introner) skip_introner=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

for name in gff genome outdir; do
  value=${!name}
  if [[ -z "$value" ]]; then
    echo "Missing required --${name}" >&2
    usage >&2
    exit 1
  fi
done
for file in "$gff" "$genome"; do
  if [[ ! -s "$file" ]]; then
    echo "Missing or empty input file: $file" >&2
    exit 1
  fi
done
if [[ "$skip_introner" -eq 0 && ( -n "$introner_tool_dir" || -n "$directory_list" ) ]]; then
  if [[ -z "$introner_tool_dir" || -z "$directory_list" ]]; then
    echo "Provide both --introner-tool-dir and --directory-list for Introner-elements" >&2
    exit 1
  fi
fi

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
outdir_abs=$(mkdir -p "$outdir" && readlink -f "$outdir")
prefix=${prefix:-$(basename "$gff")}
prefix=${prefix%.gff3}
prefix=${prefix%.gff}

"$python_cmd" "$script_dir/extract_introns.py" \
  --gff "$gff" \
  --genome "$genome" \
  --feature "$feature" \
  --min-short "$min_short" \
  --max-short "$max_short" \
  --at-rich-threshold "$at_rich_threshold" \
  --out "$outdir_abs/${prefix}.introns.bed" \
  --short-out "$outdir_abs/${prefix}.short_introns_${min_short}_${max_short}bp.bed" \
  --details-out "$outdir_abs/${prefix}.introns.details.tsv" \
  --unique-bed "$outdir_abs/${prefix}.introns.unique.bed" \
  --unique-details-out "$outdir_abs/${prefix}.introns.unique.details.tsv" \
  --chrom-summary "$outdir_abs/${prefix}.introns.chrom_summary.tsv" \
  --summary "$outdir_abs/${prefix}.introns.summary.tsv"

if [[ "$skip_introner" -eq 0 && -n "$introner_tool_dir" ]]; then
  bash "$script_dir/run_introner_elements.sh" \
    --gff "$gff" \
    --directory-list "$directory_list" \
    --tool-dir "$introner_tool_dir" \
    --python "$python_cmd"
fi
