#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run_gene_family_evolution_workflow.sh --orthofinder-count Orthogroups.GeneCount.tsv --species-tree species_tree.nwk --outdir family_evolution [options]

Chain the Stage 08 gene-family evolution workflow:
  1. Prepare Count input and rejected-family records.
  2. Optionally parse Count gain/loss output and summarize gains/losses by family and node.
  3. Prepare CAFE input and filter CAFE families with removed-family reasons.

Required:
  --orthofinder-count FILE       OrthoFinder Orthogroups.GeneCount.tsv
  --species-tree FILE            Species tree Newick
  --outdir DIR                   Output directory

Options:
  --count-output FILE            Raw Count gain/loss output to parse
  --count-format long|wide       Parsed Count output format [long]
  --family-summary FILE          Orthofinder family summary table from Stage 07
  --functional-annotation FILE   Optional annotation table reserved for downstream joins
  --max-copy INT                 Maximum family copy count for CAFE filtering [100]
  --min-species INT              Minimum species with copies for CAFE filtering [2]
  --keep-all-zero                Do not remove all-zero CAFE families
  --skip-count                   Skip Count input preparation and Count parsing
  --skip-cafe                    Skip CAFE input preparation and filtering
  --python CMD                   Python executable [python3]
  -h, --help                     Show this help
USAGE
}

orthofinder_count=""
species_tree=""
outdir=""
count_output=""
count_format="long"
family_summary=""
functional_annotation=""
max_copy=100
min_species=2
remove_all_zero=1
skip_count=0
skip_cafe=0
python_cmd="python3"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --orthofinder-count) orthofinder_count=${2:?"Missing value for --orthofinder-count"}; shift 2 ;;
    --species-tree) species_tree=${2:?"Missing value for --species-tree"}; shift 2 ;;
    --outdir) outdir=${2:?"Missing value for --outdir"}; shift 2 ;;
    --count-output) count_output=${2:?"Missing value for --count-output"}; shift 2 ;;
    --count-format) count_format=${2:?"Missing value for --count-format"}; shift 2 ;;
    --family-summary) family_summary=${2:?"Missing value for --family-summary"}; shift 2 ;;
    --functional-annotation) functional_annotation=${2:?"Missing value for --functional-annotation"}; shift 2 ;;
    --max-copy) max_copy=${2:?"Missing value for --max-copy"}; shift 2 ;;
    --min-species) min_species=${2:?"Missing value for --min-species"}; shift 2 ;;
    --keep-all-zero) remove_all_zero=0; shift ;;
    --skip-count) skip_count=1; shift ;;
    --skip-cafe) skip_cafe=1; shift ;;
    --python) python_cmd=${2:?"Missing value for --python"}; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

for name in orthofinder_count species_tree outdir; do
  value=${!name}
  if [[ -z "$value" ]]; then
    echo "Missing required --${name//_/-}" >&2
    usage >&2
    exit 1
  fi
done
for file in "$orthofinder_count" "$species_tree" "$count_output" "$family_summary" "$functional_annotation"; do
  if [[ -n "$file" && ! -s "$file" ]]; then
    echo "Missing or empty input file: $file" >&2
    exit 1
  fi
done

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
outdir_abs=$(mkdir -p "$outdir" && readlink -f "$outdir")

if [[ "$skip_count" -eq 0 ]]; then
  "$python_cmd" "$script_dir/prepare_count_input.py" \
    --orthofinder-count "$orthofinder_count" \
    --species-tree "$species_tree" \
    --out "$outdir_abs/count_input.tsv" \
    --rejected "$outdir_abs/count_rejected_families.tsv" \
    --species-order "$outdir_abs/count_species_order.tsv"

  if [[ -n "$count_output" ]]; then
    "$python_cmd" "$script_dir/parse_count_gain_loss.py" \
      --input "$count_output" \
      --format "$count_format" \
      --out "$outdir_abs/count_gain_loss.tsv"
    summary_args=(--count-gain-loss "$outdir_abs/count_gain_loss.tsv" --out "$outdir_abs/family_gain_loss_summary.tsv" --node-summary "$outdir_abs/node_gain_loss_summary.tsv")
    [[ -n "$family_summary" ]] && summary_args+=(--family-summary "$family_summary")
    [[ -n "$functional_annotation" ]] && summary_args+=(--functional-annotation "$functional_annotation")
    "$python_cmd" "$script_dir/summarize_family_gain_loss.py" "${summary_args[@]}"
  fi
fi

if [[ "$skip_cafe" -eq 0 ]]; then
  "$python_cmd" "$script_dir/prepare_cafe_input.py" \
    --orthofinder-count "$orthofinder_count" \
    --species-tree "$species_tree" \
    --out "$outdir_abs/cafe_input.tsv"
  cafe_filter_args=(--input "$outdir_abs/cafe_input.tsv" --max-copy "$max_copy" --min-species "$min_species" --out "$outdir_abs/cafe_input.filtered.tsv" --removed "$outdir_abs/cafe_input.removed.tsv")
  [[ "$remove_all_zero" -eq 1 ]] && cafe_filter_args+=(--remove-all-zero)
  "$python_cmd" "$script_dir/filter_cafe_families.py" "${cafe_filter_args[@]}"
fi
