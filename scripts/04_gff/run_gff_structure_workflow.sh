#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run_gff_structure_workflow.sh --outdir gff_structure [options]

Chain the Stage 04 GFF structure-statistics workflow:
  1. Summarize gene, transcript, exon, CDS, intron, isoform, chromosome, and feature statistics.
  2. Optionally compare multiple species through a manifest or repeated comparison inputs.
  3. Prepare plot-ready handoff tables for external plotting tools.
  4. Create base-R PDF plots when Rscript is available.

Input modes:
  --gff FILE --species NAME       Main species GFF/GFF3
  --manifest FILE                 TSV with species, gff, and optional genome columns

Options:
  --genome FILE                   Optional genome FASTA for main --gff QC
  --compare-species NAME          Comparison species name; repeatable with --compare-gff
  --compare-gff FILE              Comparison GFF/GFF3; repeatable with --compare-species
  --outdir DIR                    Output directory [required]
  --prefix NAME                   Output prefix [gff_structure]
  --python CMD                    Python executable [python3]
  --rscript CMD                   Rscript executable [Rscript]
  --skip-r-plots                  Skip base-R PDF plots
  --skip-plot-handoff             Skip plot-ready handoff tables
  -h, --help                      Show this help
USAGE
}

gff=""
species=""
genome=""
manifest=""
outdir=""
prefix="gff_structure"
python_cmd="python3"
rscript_cmd="Rscript"
skip_r_plots=0
skip_plot_handoff=0
compare_species=()
compare_gff=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --gff) gff=${2:?"Missing value for --gff"}; shift 2 ;;
    --species) species=${2:?"Missing value for --species"}; shift 2 ;;
    --genome) genome=${2:?"Missing value for --genome"}; shift 2 ;;
    --manifest) manifest=${2:?"Missing value for --manifest"}; shift 2 ;;
    --compare-species) compare_species+=("${2:?"Missing value for --compare-species"}"); shift 2 ;;
    --compare-gff) compare_gff+=("${2:?"Missing value for --compare-gff"}"); shift 2 ;;
    --outdir) outdir=${2:?"Missing value for --outdir"}; shift 2 ;;
    --prefix) prefix=${2:?"Missing value for --prefix"}; shift 2 ;;
    --python) python_cmd=${2:?"Missing value for --python"}; shift 2 ;;
    --rscript) rscript_cmd=${2:?"Missing value for --rscript"}; shift 2 ;;
    --skip-r-plots) skip_r_plots=1; shift ;;
    --skip-plot-handoff) skip_plot_handoff=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ -z "$outdir" ]]; then
  echo "Missing required --outdir" >&2
  usage >&2
  exit 1
fi
if [[ -z "$manifest" && -z "$gff" ]]; then
  echo "Provide --manifest or --gff" >&2
  usage >&2
  exit 1
fi
if [[ -n "$gff" && -z "$species" ]]; then
  echo "--gff requires --species" >&2
  exit 1
fi
if [[ -n "$gff" && ! -s "$gff" ]]; then
  echo "Missing or empty GFF: $gff" >&2
  exit 1
fi
if [[ -n "$genome" && ! -s "$genome" ]]; then
  echo "Missing or empty genome FASTA: $genome" >&2
  exit 1
fi
if [[ -n "$manifest" && ! -s "$manifest" ]]; then
  echo "Missing or empty manifest: $manifest" >&2
  exit 1
fi
if [[ ${#compare_species[@]} -ne ${#compare_gff[@]} ]]; then
  echo "Provide matching repeated --compare-species and --compare-gff values" >&2
  exit 1
fi
for file in "${compare_gff[@]}"; do
  if [[ ! -s "$file" ]]; then
    echo "Missing or empty comparison GFF: $file" >&2
    exit 1
  fi
done
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
outdir_abs=$(mkdir -p "$outdir" && readlink -f "$outdir")
work_manifest="$outdir_abs/${prefix}.manifest.tsv"

if [[ -n "$manifest" ]]; then
  cp "$manifest" "$work_manifest"
else
  printf 'species\tgff\tgenome\n' > "$work_manifest"
fi
if [[ -n "$gff" ]]; then
  printf '%s\t%s\t%s\n' "$species" "$gff" "${genome:-NA}" >> "$work_manifest"
fi
for idx in "${!compare_species[@]}"; do
  printf '%s\t%s\tNA\n' "${compare_species[$idx]}" "${compare_gff[$idx]}" >> "$work_manifest"
done

out_prefix="$outdir_abs/${prefix}"
"$python_cmd" "$script_dir/summarize_gff_structure.py" \
  --manifest "$work_manifest" \
  --out-prefix "$out_prefix"

if [[ "$skip_plot_handoff" -eq 0 ]]; then
  "$python_cmd" "$script_dir/prepare_gff_structure_plot_handoff.py" \
    --metrics "$out_prefix.metrics.tsv" \
    --distributions "$out_prefix.distributions.tsv" \
    --out-prefix "$out_prefix.plot_handoff"
fi

if [[ "$skip_r_plots" -eq 0 ]]; then
  if command -v "$rscript_cmd" >/dev/null 2>&1; then
    "$rscript_cmd" "$script_dir/plot_gff_structure.R" \
      --metrics "$out_prefix.metrics.tsv" \
      --distributions "$out_prefix.distributions.tsv" \
      --out-prefix "$out_prefix.plots"
  else
    echo "Rscript executable not found; skipped PDF plots" >&2
  fi
fi
