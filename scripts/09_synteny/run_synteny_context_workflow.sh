#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run_synteny_context_workflow.sh --input synteny.anchors --format anchor --outdir synteny_context [options]

Chain the Stage 09 synteny-context workflow:
  1. Normalize MCScanX/JCVI anchor, simple, or table outputs.
  2. Build a heatmap-ready pairwise matrix from synteny summaries.
  3. Optionally compare synteny support in target versus background regions.

Required:
  --input FILE             MCScanX/JCVI synteny file
  --format anchor|simple|table
  --outdir DIR             Output directory

Options:
  --prefix NAME            Output prefix [synteny]
  --pair-label LABEL       Species pair label, e.g. Arabidopsis_thaliana.Arabidopsis_lyrata
  --ref-species NAME       Reference species label
  --query-species NAME     Query species label
  --matrix-metric NAME     Matrix metric [blocks]
  --symmetric              Mirror heatmap matrix values across species pairs
  --gene-bed FILE          Gene BED for region comparison
  --target-bed FILE        Target BED for region comparison
  --background-bed FILE    Optional background BED for region comparison
  --python CMD             Python executable [python3]
  -h, --help               Show this help
USAGE
}

input=""
format=""
outdir=""
prefix="synteny"
pair_label=""
ref_species=""
query_species=""
matrix_metric="blocks"
symmetric=0
gene_bed=""
target_bed=""
background_bed=""
python_cmd="python3"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input) input=${2:?"Missing value for --input"}; shift 2 ;;
    --format) format=${2:?"Missing value for --format"}; shift 2 ;;
    --outdir) outdir=${2:?"Missing value for --outdir"}; shift 2 ;;
    --prefix) prefix=${2:?"Missing value for --prefix"}; shift 2 ;;
    --pair-label) pair_label=${2:?"Missing value for --pair-label"}; shift 2 ;;
    --ref-species) ref_species=${2:?"Missing value for --ref-species"}; shift 2 ;;
    --query-species) query_species=${2:?"Missing value for --query-species"}; shift 2 ;;
    --matrix-metric) matrix_metric=${2:?"Missing value for --matrix-metric"}; shift 2 ;;
    --symmetric) symmetric=1; shift ;;
    --gene-bed) gene_bed=${2:?"Missing value for --gene-bed"}; shift 2 ;;
    --target-bed) target_bed=${2:?"Missing value for --target-bed"}; shift 2 ;;
    --background-bed) background_bed=${2:?"Missing value for --background-bed"}; shift 2 ;;
    --python) python_cmd=${2:?"Missing value for --python"}; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

for name in input format outdir; do
  value=${!name}
  if [[ -z "$value" ]]; then
    echo "Missing required --${name}" >&2
    usage >&2
    exit 1
  fi
done
if [[ ! -s "$input" ]]; then
  echo "Missing or empty synteny input: $input" >&2
  exit 1
fi
case "$format" in
  anchor|simple|table) ;;
  *) echo "Unsupported --format: $format" >&2; exit 1 ;;
esac
for file in "$gene_bed" "$target_bed" "$background_bed"; do
  if [[ -n "$file" && ! -s "$file" ]]; then
    echo "Missing or empty input file: $file" >&2
    exit 1
  fi
done
if [[ -n "$gene_bed" || -n "$target_bed" || -n "$background_bed" ]]; then
  if [[ -z "$gene_bed" || -z "$target_bed" ]]; then
    echo "Region comparison requires both --gene-bed and --target-bed" >&2
    exit 1
  fi
fi

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
outdir_abs=$(mkdir -p "$outdir" && readlink -f "$outdir")
normalized="$outdir_abs/${prefix}.synteny.tsv"
summary="$outdir_abs/${prefix}.synteny_summary.tsv"
matrix="$outdir_abs/${prefix}.synteny_${matrix_metric}_matrix.tsv"

normalize_args=(--input "$input" --format "$format" --out "$normalized" --summary "$summary")
[[ -n "$pair_label" ]] && normalize_args+=(--pair-label "$pair_label")
[[ -n "$ref_species" ]] && normalize_args+=(--ref-species "$ref_species")
[[ -n "$query_species" ]] && normalize_args+=(--query-species "$query_species")
"$python_cmd" "$script_dir/summarize_mcscan_jcvi_synteny.py" "${normalize_args[@]}"

matrix_args=(--summary "$summary" --metric "$matrix_metric" --out "$matrix")
[[ "$symmetric" -eq 1 ]] && matrix_args+=(--symmetric)
"$python_cmd" "$script_dir/build_synteny_heatmap_matrix.py" "${matrix_args[@]}"

if [[ -n "$gene_bed" ]]; then
  compare_args=(
    --synteny "$normalized"
    --gene-bed "$gene_bed"
    --target-bed "$target_bed"
    --out "$outdir_abs/${prefix}.region_synteny_summary.tsv"
    --details "$outdir_abs/${prefix}.region_synteny_details.tsv"
  )
  [[ -n "$background_bed" ]] && compare_args+=(--background-bed "$background_bed")
  "$python_cmd" "$script_dir/compare_region_synteny.py" "${compare_args[@]}"
fi
