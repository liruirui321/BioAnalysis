#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run_gene_family_workflow.sh --protein-dir protein_dir --orthofinder-results orthofinder_results --outdir gene_family_work [options]

Chain the Stage 07 gene-family workflow:
  1. Optionally prefix one protein FASTA before OrthoFinder setup.
  2. Optionally run OrthoFinder on a protein directory.
  3. Summarize OrthoFinder gene families and family classes.
  4. Optionally extract selected orthogroup member lists.
  5. Optionally concatenate trimmed alignments for species-tree supermatrix handoff.

Required:
  --outdir DIR                  Output directory
  --gene-count FILE             OrthoFinder Orthogroups.GeneCount.tsv

Options:
  --protein-dir DIR             Protein FASTA directory for optional OrthoFinder run
  --run-orthofinder             Run OrthoFinder on --protein-dir
  --orthofinder CMD             OrthoFinder executable [orthofinder]
  --threads INT                 OrthoFinder -t and -a threads [32]
  --orthogroups FILE            OrthoFinder Orthogroups.tsv
  --species-list FILE           Species list for summaries or supermatrix
  --prefix-input FILE           Protein FASTA to prefix before OrthoFinder setup
  --prefix NAME                 Prefix for --prefix-input
  --prefix-sep STRING           Prefix separator [|]
  --target-list FILE            Orthogroup IDs to extract
  --id-map FILE                 Species gene ID map for member extraction
  --alignment-dir DIR           Trimmed alignment directory for supermatrix
  --alignment-suffix STRING     Trimmed alignment suffix [.trimmed.fa]
  --python CMD                  Python executable [python3]
  -h, --help                    Show this help
USAGE
}

outdir=""
gene_count=""
protein_dir=""
run_orthofinder=0
orthofinder_cmd="orthofinder"
threads=32
orthogroups=""
species_list=""
prefix_input=""
prefix_name=""
prefix_sep="|"
target_list=""
id_map=""
alignment_dir=""
alignment_suffix=".trimmed.fa"
python_cmd="python3"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --outdir) outdir=${2:?"Missing value for --outdir"}; shift 2 ;;
    --gene-count) gene_count=${2:?"Missing value for --gene-count"}; shift 2 ;;
    --protein-dir) protein_dir=${2:?"Missing value for --protein-dir"}; shift 2 ;;
    --run-orthofinder) run_orthofinder=1; shift ;;
    --orthofinder) orthofinder_cmd=${2:?"Missing value for --orthofinder"}; shift 2 ;;
    --threads) threads=${2:?"Missing value for --threads"}; shift 2 ;;
    --orthogroups) orthogroups=${2:?"Missing value for --orthogroups"}; shift 2 ;;
    --species-list) species_list=${2:?"Missing value for --species-list"}; shift 2 ;;
    --prefix-input) prefix_input=${2:?"Missing value for --prefix-input"}; shift 2 ;;
    --prefix) prefix_name=${2:?"Missing value for --prefix"}; shift 2 ;;
    --prefix-sep) prefix_sep=${2:?"Missing value for --prefix-sep"}; shift 2 ;;
    --target-list) target_list=${2:?"Missing value for --target-list"}; shift 2 ;;
    --id-map) id_map=${2:?"Missing value for --id-map"}; shift 2 ;;
    --alignment-dir) alignment_dir=${2:?"Missing value for --alignment-dir"}; shift 2 ;;
    --alignment-suffix) alignment_suffix=${2:?"Missing value for --alignment-suffix"}; shift 2 ;;
    --python) python_cmd=${2:?"Missing value for --python"}; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

for name in outdir gene_count; do
  value=${!name}
  if [[ -z "$value" ]]; then
    echo "Missing required --${name//_/-}" >&2
    usage >&2
    exit 1
  fi
done
if [[ ! -s "$gene_count" ]]; then
  echo "Missing or empty gene-count table: $gene_count" >&2
  exit 1
fi
for file in "$orthogroups" "$species_list" "$prefix_input" "$target_list" "$id_map"; do
  if [[ -n "$file" && ! -s "$file" ]]; then
    echo "Missing or empty input file: $file" >&2
    exit 1
  fi
done
if [[ "$run_orthofinder" -eq 1 ]]; then
  if [[ -z "$protein_dir" || ! -d "$protein_dir" ]]; then
    echo "--run-orthofinder requires --protein-dir" >&2
    exit 1
  fi
  if ! command -v "$orthofinder_cmd" >/dev/null 2>&1; then
    echo "OrthoFinder executable not found: $orthofinder_cmd" >&2
    exit 1
  fi
fi
if [[ -n "$prefix_input" && -z "$prefix_name" ]]; then
  echo "--prefix-input requires --prefix" >&2
  exit 1
fi
if [[ -n "$target_list" && -z "$orthogroups" ]]; then
  echo "--target-list requires --orthogroups" >&2
  exit 1
fi
if [[ -n "$alignment_dir" ]]; then
  if [[ ! -d "$alignment_dir" ]]; then
    echo "Missing alignment directory: $alignment_dir" >&2
    exit 1
  fi
  if [[ -z "$species_list" ]]; then
    echo "--alignment-dir requires --species-list" >&2
    exit 1
  fi
fi

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
outdir_abs=$(mkdir -p "$outdir" && readlink -f "$outdir")

if [[ -n "$prefix_input" ]]; then
  "$python_cmd" "$script_dir/prefix_fasta_ids.py" \
    --input "$prefix_input" \
    --prefix "$prefix_name" \
    --sep "$prefix_sep" \
    --out "$outdir_abs/${prefix_name}.protein.prefixed.fa" \
    --map "$outdir_abs/${prefix_name}.species_gene_id_map.tsv"
fi

if [[ "$run_orthofinder" -eq 1 ]]; then
  "$orthofinder_cmd" -f "$protein_dir" -t "$threads" -a "$threads"
fi

summary_args=(--gene-count "$gene_count" --out "$outdir_abs/orthofinder_gene_family_summary.tsv" --single-copy-list "$outdir_abs/single_copy_orthogroups.list" --core-list "$outdir_abs/core_orthogroups.list" --lineage-specific-list "$outdir_abs/lineage_specific_orthogroups.list")
[[ -n "$orthogroups" ]] && summary_args+=(--orthogroups "$orthogroups")
[[ -n "$species_list" ]] && summary_args+=(--species-list "$species_list")
"$python_cmd" "$script_dir/summarize_orthofinder_gene_families.py" "${summary_args[@]}"

if [[ -n "$target_list" ]]; then
  extract_args=(--orthogroups "$orthogroups" --target-list "$target_list" --outdir "$outdir_abs/orthogroup_member_lists" --summary "$outdir_abs/orthogroup_member_summary.tsv")
  [[ -n "$id_map" ]] && extract_args+=(--id-map "$id_map")
  "$python_cmd" "$script_dir/extract_orthogroup_members.py" "${extract_args[@]}"
fi

if [[ -n "$alignment_dir" ]]; then
  "$python_cmd" "$script_dir/concat_alignments.py" \
    --input-dir "$alignment_dir" \
    --suffix "$alignment_suffix" \
    --species-list "$species_list" \
    --out-fasta "$outdir_abs/supermatrix.fa" \
    --out-partition "$outdir_abs/partition.txt" \
    --out-stats "$outdir_abs/occupancy.tsv"
fi
