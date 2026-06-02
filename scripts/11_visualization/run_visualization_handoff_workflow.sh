#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run_visualization_handoff_workflow.sh --outdir visualization_handoff [options]

Chain the Stage 11 visualization handoff workflow:
  1. Build UpSet/Venn-style gene-set membership matrices from repeated NAME=FILE inputs.
  2. Prepare target-family, expression, evolution, and HGT-family visualization matrices.

Required:
  --outdir DIR                   Output directory

Options:
  --prefix NAME                  Output prefix [visualization]
  --gene-set NAME=FILE           Gene ID set for membership matrix; repeatable
  --expression-summary FILE      Stage 07 family expression summary
  --target-evolution FILE        Stage 08 target-family evolution table
  --hgt-family FILE              Stage 10 HGT-family integration table
  --python CMD                   Python executable [python3]
  -h, --help                     Show this help
USAGE
}

outdir=""
prefix="visualization"
gene_sets=()
expression_summary=""
target_evolution=""
hgt_family=""
python_cmd="python3"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --outdir) outdir=${2:?"Missing value for --outdir"}; shift 2 ;;
    --prefix) prefix=${2:?"Missing value for --prefix"}; shift 2 ;;
    --gene-set) gene_sets+=("${2:?"Missing value for --gene-set"}"); shift 2 ;;
    --expression-summary) expression_summary=${2:?"Missing value for --expression-summary"}; shift 2 ;;
    --target-evolution) target_evolution=${2:?"Missing value for --target-evolution"}; shift 2 ;;
    --hgt-family) hgt_family=${2:?"Missing value for --hgt-family"}; shift 2 ;;
    --python) python_cmd=${2:?"Missing value for --python"}; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ -z "$outdir" ]]; then
  echo "Missing required --outdir" >&2
  usage >&2
  exit 1
fi
for item in "${gene_sets[@]}"; do
  if [[ "$item" != *=* ]]; then
    echo "--gene-set must be NAME=FILE" >&2
    exit 1
  fi
  file=${item#*=}
  if [[ ! -s "$file" ]]; then
    echo "Missing or empty gene-set file: $file" >&2
    exit 1
  fi
done
for file in "$expression_summary" "$target_evolution" "$hgt_family"; do
  if [[ -n "$file" && ! -s "$file" ]]; then
    echo "Missing or empty input file: $file" >&2
    exit 1
  fi
done
if [[ ${#gene_sets[@]} -eq 0 && -z "$expression_summary" && -z "$target_evolution" && -z "$hgt_family" ]]; then
  echo "Provide at least one --gene-set or matrix source file" >&2
  exit 1
fi

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
outdir_abs=$(mkdir -p "$outdir" && readlink -f "$outdir")

if [[ ${#gene_sets[@]} -gt 0 ]]; then
  set_args=()
  for item in "${gene_sets[@]}"; do
    set_args+=(--set "$item")
  done
  "$python_cmd" "$script_dir/build_gene_set_matrix.py" \
    "${set_args[@]}" \
    --out "$outdir_abs/${prefix}.gene_set_membership_matrix.tsv" \
    --summary "$outdir_abs/${prefix}.gene_set_summary.tsv"
fi

if [[ -n "$expression_summary" || -n "$target_evolution" || -n "$hgt_family" ]]; then
  family_args=(--out-prefix "$outdir_abs/${prefix}.family_visualization")
  [[ -n "$expression_summary" ]] && family_args+=(--expression-summary "$expression_summary")
  [[ -n "$target_evolution" ]] && family_args+=(--target-evolution "$target_evolution")
  [[ -n "$hgt_family" ]] && family_args+=(--hgt-family "$hgt_family")
  "$python_cmd" "$script_dir/prepare_family_visualization_matrices.py" "${family_args[@]}"
fi
