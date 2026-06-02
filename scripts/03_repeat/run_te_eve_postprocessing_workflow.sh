#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run_te_eve_postprocessing_workflow.sh --outdir repeat_postprocess [options]

Chain Stage 03 TE/EVE post-processing handoffs:
  1. Standardize external EVE/GEVE calls into BED and TSV handoff files.
  2. Parse TEsorter domain FASTA headers into normalized domain tables.
  3. Compare parsed domains against target EVE/GEVE and optional background regions.
  4. Summarize RepeatMasker divergence and optional insertion-time estimates.

Required:
  --outdir DIR                    Output directory

Options:
  --prefix NAME                   Output prefix [repeat_postprocess]
  --tesorter-domains FILE         TEsorter domain FASTA, commonly rexdb.dom.faa
  --target-bed FILE               Target EVE/GEVE BED regions for TEsorter overlap summaries; defaults to standardized EVE BED when --eve-input is supplied
  --background-bed FILE           Optional background BED regions for contrast labels
  --repeatmasker-out FILE         RepeatMasker .out file for divergence summaries
  --substitution-rate FLOAT       Substitutions/site/year for insertion-time estimates
  --eve-input FILE                External EVE/GEVE call input to standardize
  --eve-format bed|gff|tsv        Format for --eve-input
  --eve-source NAME               Source label for standardized EVE/GEVE calls [external_eve_geve_caller]
  --eve-region-type NAME          Region type label for standardized calls [EVE_GEVE_region]
  --eve-feature-types LIST        Comma-separated GFF feature types to keep
  --skip-tesorter                 Skip TEsorter parsing and region summaries
  --skip-repeatmasker             Skip RepeatMasker divergence summaries
  --skip-eve-standardize          Skip EVE/GEVE standardization
  -h, --help                      Show this help
USAGE
}

outdir=""
prefix="repeat_postprocess"
tesorter_domains=""
target_bed=""
background_bed=""
repeatmasker_out=""
substitution_rate=""
eve_input=""
eve_format=""
eve_source="external_eve_geve_caller"
eve_region_type="EVE_GEVE_region"
eve_feature_types=""
skip_tesorter=0
skip_repeatmasker=0
skip_eve_standardize=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --outdir) outdir=${2:?"Missing value for --outdir"}; shift 2 ;;
    --prefix) prefix=${2:?"Missing value for --prefix"}; shift 2 ;;
    --tesorter-domains) tesorter_domains=${2:?"Missing value for --tesorter-domains"}; shift 2 ;;
    --target-bed) target_bed=${2:?"Missing value for --target-bed"}; shift 2 ;;
    --background-bed) background_bed=${2:?"Missing value for --background-bed"}; shift 2 ;;
    --repeatmasker-out) repeatmasker_out=${2:?"Missing value for --repeatmasker-out"}; shift 2 ;;
    --substitution-rate) substitution_rate=${2:?"Missing value for --substitution-rate"}; shift 2 ;;
    --eve-input) eve_input=${2:?"Missing value for --eve-input"}; shift 2 ;;
    --eve-format) eve_format=${2:?"Missing value for --eve-format"}; shift 2 ;;
    --eve-source) eve_source=${2:?"Missing value for --eve-source"}; shift 2 ;;
    --eve-region-type) eve_region_type=${2:?"Missing value for --eve-region-type"}; shift 2 ;;
    --eve-feature-types) eve_feature_types=${2:?"Missing value for --eve-feature-types"}; shift 2 ;;
    --skip-tesorter) skip_tesorter=1; shift ;;
    --skip-repeatmasker) skip_repeatmasker=1; shift ;;
    --skip-eve-standardize) skip_eve_standardize=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ -z "$outdir" ]]; then
  echo "Missing required --outdir" >&2
  usage >&2
  exit 1
fi

if [[ "$skip_tesorter" -eq 0 ]]; then
  if [[ -z "$tesorter_domains" ]]; then
    echo "--tesorter-domains is required unless --skip-tesorter is used" >&2
    exit 1
  fi
  if [[ ! -s "$tesorter_domains" ]]; then
    echo "Missing or empty TEsorter domain FASTA: $tesorter_domains" >&2
    exit 1
  fi
  if [[ -z "$target_bed" && "$skip_eve_standardize" -eq 1 ]]; then
    echo "--target-bed is required for TEsorter region summaries unless --eve-input is standardized in the same run" >&2
    exit 1
  fi
  if [[ -n "$target_bed" && ! -s "$target_bed" ]]; then
    echo "Missing or empty target BED: $target_bed" >&2
    exit 1
  fi
  if [[ -n "$background_bed" && ! -s "$background_bed" ]]; then
    echo "Missing or empty background BED: $background_bed" >&2
    exit 1
  fi
fi

if [[ "$skip_repeatmasker" -eq 0 ]]; then
  if [[ -z "$repeatmasker_out" ]]; then
    echo "--repeatmasker-out is required unless --skip-repeatmasker is used" >&2
    exit 1
  fi
  if [[ ! -s "$repeatmasker_out" ]]; then
    echo "Missing or empty RepeatMasker output: $repeatmasker_out" >&2
    exit 1
  fi
fi

if [[ "$skip_eve_standardize" -eq 0 ]]; then
  if [[ -z "$eve_input" || -z "$eve_format" ]]; then
    echo "--eve-input and --eve-format are required unless --skip-eve-standardize is used" >&2
    exit 1
  fi
  if [[ ! -s "$eve_input" ]]; then
    echo "Missing or empty EVE/GEVE input: $eve_input" >&2
    exit 1
  fi
  case "$eve_format" in
    bed|gff|tsv) ;;
    *) echo "Unsupported --eve-format: $eve_format" >&2; exit 1 ;;
  esac
fi

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
outdir_abs=$(mkdir -p "$outdir" && readlink -f "$outdir")

tesorter_table="$outdir_abs/${prefix}.tesorter_domains.tsv"
tesorter_summary="$outdir_abs/${prefix}.tesorter_domain_summary.tsv"
tesorter_region_summary="$outdir_abs/${prefix}.tesorter_region_summary.tsv"
tesorter_region_details="$outdir_abs/${prefix}.tesorter_region_details.tsv"
te_divergence="$outdir_abs/${prefix}.repeatmasker_divergence.tsv"
te_divergence_summary="$outdir_abs/${prefix}.repeatmasker_divergence_summary.tsv"
eve_bed="$outdir_abs/${prefix}.eve_geve_regions.bed"
eve_tsv="$outdir_abs/${prefix}.eve_geve_regions.tsv"

if [[ "$skip_eve_standardize" -eq 0 ]]; then
  eve_args=(
    --input "$eve_input"
    --format "$eve_format"
    --out-bed "$eve_bed"
    --out-tsv "$eve_tsv"
    --source "$eve_source"
    --region-type "$eve_region_type"
  )
  [[ -n "$eve_feature_types" ]] && eve_args+=(--feature-types "$eve_feature_types")
  python3 "$script_dir/standardize_eve_geve_regions.py" "${eve_args[@]}"
fi

if [[ "$skip_tesorter" -eq 0 ]]; then
  python3 "$script_dir/parse_tesorter_domains.py" \
    --domains "$tesorter_domains" \
    --out "$tesorter_table" \
    --summary "$tesorter_summary"

  target_bed_for_summary=${target_bed:-$eve_bed}
  region_args=(
    --domains "$tesorter_table"
    --target-bed "$target_bed_for_summary"
    --out "$tesorter_region_summary"
    --details "$tesorter_region_details"
  )
  [[ -n "$background_bed" ]] && region_args+=(--background-bed "$background_bed")
  python3 "$script_dir/summarize_tesorter_regions.py" "${region_args[@]}"
fi

if [[ "$skip_repeatmasker" -eq 0 ]]; then
  divergence_args=(
    --repeatmasker-out "$repeatmasker_out"
    --out "$te_divergence"
    --summary "$te_divergence_summary"
  )
  [[ -n "$substitution_rate" ]] && divergence_args+=(--substitution-rate "$substitution_rate")
  python3 "$script_dir/summarize_te_divergence.py" "${divergence_args[@]}"
fi
