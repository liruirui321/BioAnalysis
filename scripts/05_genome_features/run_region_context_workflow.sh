#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run_region_context_workflow.sh --target-bed target_regions.bed --outdir region_context [options]

Chain Stage 05 region-context workflows:
  1. Compare target regions against BED/GFF feature tracks and optional background regions.
  2. Summarize Bismark CX methylation over target regions using upstream/body/downstream bins.

Required:
  --target-bed FILE          Target region BED file
  --outdir DIR               Output directory

Options:
  --prefix NAME              Output prefix [target BED basename]
  --features FILE            Feature BED or GFF file for enrichment summaries
  --feature-format bed|gff   Format for --features
  --feature-types LIST       Comma-separated GFF feature types to keep
  --background-bed FILE      Optional background BED regions for enrichment contrast
  --cx FILE                  Bismark CX report for methylation summaries
  --bins LIST                Upstream,body,downstream bin counts [25,100,25]
  --flank-bp INT             Upstream/downstream flank size for methylation bins [2000]
  --min-coverage INT         Minimum CX coverage per cytosine [1]
  --python CMD               Python executable [python3]
  --skip-feature-enrichment  Skip feature enrichment even if --features is supplied
  --skip-methylation         Skip methylation summaries even if --cx is supplied
  -h, --help                 Show this help
USAGE
}

target_bed=""
outdir=""
prefix=""
features=""
feature_format=""
feature_types=""
background_bed=""
cx=""
bins="25,100,25"
flank_bp=2000
min_coverage=1
python_cmd="python3"
skip_feature_enrichment=0
skip_methylation=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-bed) target_bed=${2:?"Missing value for --target-bed"}; shift 2 ;;
    --outdir) outdir=${2:?"Missing value for --outdir"}; shift 2 ;;
    --prefix) prefix=${2:?"Missing value for --prefix"}; shift 2 ;;
    --features) features=${2:?"Missing value for --features"}; shift 2 ;;
    --feature-format) feature_format=${2:?"Missing value for --feature-format"}; shift 2 ;;
    --feature-types) feature_types=${2:?"Missing value for --feature-types"}; shift 2 ;;
    --background-bed) background_bed=${2:?"Missing value for --background-bed"}; shift 2 ;;
    --cx) cx=${2:?"Missing value for --cx"}; shift 2 ;;
    --bins) bins=${2:?"Missing value for --bins"}; shift 2 ;;
    --flank-bp) flank_bp=${2:?"Missing value for --flank-bp"}; shift 2 ;;
    --min-coverage) min_coverage=${2:?"Missing value for --min-coverage"}; shift 2 ;;
    --python) python_cmd=${2:?"Missing value for --python"}; shift 2 ;;
    --skip-feature-enrichment) skip_feature_enrichment=1; shift ;;
    --skip-methylation) skip_methylation=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

for name in target_bed outdir; do
  value=${!name}
  if [[ -z "$value" ]]; then
    echo "Missing required --${name//_/-}" >&2
    usage >&2
    exit 1
  fi
done
if [[ ! -s "$target_bed" ]]; then
  echo "Missing or empty target BED: $target_bed" >&2
  exit 1
fi
if [[ -n "$background_bed" && ! -s "$background_bed" ]]; then
  echo "Missing or empty background BED: $background_bed" >&2
  exit 1
fi
if [[ "$skip_feature_enrichment" -eq 0 && -n "$features" ]]; then
  if [[ ! -s "$features" ]]; then
    echo "Missing or empty feature file: $features" >&2
    exit 1
  fi
  case "$feature_format" in
    bed|gff) ;;
    "") echo "--feature-format is required when --features is supplied" >&2; exit 1 ;;
    *) echo "Unsupported --feature-format: $feature_format" >&2; exit 1 ;;
  esac
fi
if [[ "$skip_feature_enrichment" -eq 0 && -z "$features" && -n "$feature_format" ]]; then
  echo "--features is required when --feature-format is supplied" >&2
  exit 1
fi
if [[ "$skip_methylation" -eq 0 && -n "$cx" && ! -s "$cx" ]]; then
  echo "Missing or empty Bismark CX report: $cx" >&2
  exit 1
fi
if [[ "$skip_feature_enrichment" -eq 0 && -z "$features" && "$skip_methylation" -eq 0 && -z "$cx" ]]; then
  echo "Provide --features, --cx, or a skip option that leaves no work to run" >&2
  exit 1
fi

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
outdir_abs=$(mkdir -p "$outdir" && readlink -f "$outdir")
prefix=${prefix:-$(basename "$target_bed")}
prefix=${prefix%.bed}

if [[ "$skip_feature_enrichment" -eq 0 && -n "$features" ]]; then
  feature_args=(
    --target-bed "$target_bed"
    --features "$features"
    --feature-format "$feature_format"
    --out "$outdir_abs/${prefix}.feature_enrichment.tsv"
    --details "$outdir_abs/${prefix}.feature_enrichment.details.tsv"
  )
  [[ -n "$feature_types" ]] && feature_args+=(--feature-types "$feature_types")
  [[ -n "$background_bed" ]] && feature_args+=(--background-bed "$background_bed")
  "$python_cmd" "$script_dir/compare_region_feature_enrichment.py" "${feature_args[@]}"
fi

if [[ "$skip_methylation" -eq 0 && -n "$cx" ]]; then
  "$python_cmd" "$script_dir/summarize_bismark_cx_regions.py" \
    --cx "$cx" \
    --regions-bed "$target_bed" \
    --out "$outdir_abs/${prefix}.methylation_bins.tsv" \
    --summary "$outdir_abs/${prefix}.methylation_context_summary.tsv" \
    --bins "$bins" \
    --flank-bp "$flank_bp" \
    --min-coverage "$min_coverage"
fi
