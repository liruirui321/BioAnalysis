#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run_hgt_family_integration_workflow.sh --candidates hgt.candidates.tsv --outdir hgt_family [options]

Chain the Stage 10 HGT-family integration workflow:
  1. Refine HGT donor taxonomy using optional local taxonomy/lineage tables.
  2. Integrate HGT candidates with orthogroups, target-family evidence, and Count/CAFE gain-loss outputs.

Required:
  --candidates FILE          HGT candidate table
  --outdir DIR               Output directory

Options:
  --prefix NAME              Output prefix [HGT candidate basename]
  --taxonomy FILE            Optional local donor taxonomy table
  --rank NAME                Preferred taxonomy rank column [genus]
  --orthogroups FILE         OrthoFinder Orthogroups.tsv or compatible membership table
  --target-evidence FILE     Target-family evidence table from Stage 07
  --family-gain-loss FILE    Family/node gain-loss table from Stage 08
  --python CMD               Python executable [python3]
  -h, --help                 Show this help
USAGE
}

candidates=""
outdir=""
prefix=""
taxonomy=""
rank="genus"
orthogroups=""
target_evidence=""
family_gain_loss=""
python_cmd="python3"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --candidates) candidates=${2:?"Missing value for --candidates"}; shift 2 ;;
    --outdir) outdir=${2:?"Missing value for --outdir"}; shift 2 ;;
    --prefix) prefix=${2:?"Missing value for --prefix"}; shift 2 ;;
    --taxonomy) taxonomy=${2:?"Missing value for --taxonomy"}; shift 2 ;;
    --rank) rank=${2:?"Missing value for --rank"}; shift 2 ;;
    --orthogroups) orthogroups=${2:?"Missing value for --orthogroups"}; shift 2 ;;
    --target-evidence) target_evidence=${2:?"Missing value for --target-evidence"}; shift 2 ;;
    --family-gain-loss) family_gain_loss=${2:?"Missing value for --family-gain-loss"}; shift 2 ;;
    --python) python_cmd=${2:?"Missing value for --python"}; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

for name in candidates outdir; do
  value=${!name}
  if [[ -z "$value" ]]; then
    echo "Missing required --${name}" >&2
    usage >&2
    exit 1
  fi
done
for file in "$candidates" "$taxonomy" "$orthogroups" "$target_evidence" "$family_gain_loss"; do
  if [[ -n "$file" && ! -s "$file" ]]; then
    echo "Missing or empty input file: $file" >&2
    exit 1
  fi
done

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
outdir_abs=$(mkdir -p "$outdir" && readlink -f "$outdir")
prefix=${prefix:-$(basename "$candidates")}
prefix=${prefix%.tsv}

refined="$outdir_abs/${prefix}.donor_taxonomy.tsv"
refined_summary="$outdir_abs/${prefix}.donor_taxonomy_summary.tsv"
integration="$outdir_abs/${prefix}.hgt_family_evolution.tsv"
integration_summary="$outdir_abs/${prefix}.hgt_family_evolution_summary.tsv"

refine_args=(
  --candidates "$candidates"
  --out "$refined"
  --summary "$refined_summary"
  --rank "$rank"
)
[[ -n "$taxonomy" ]] && refine_args+=(--taxonomy "$taxonomy")
"$python_cmd" "$script_dir/refine_hgt_donor_taxonomy.py" "${refine_args[@]}"

integrate_args=(
  --candidates "$candidates"
  --refined-donors "$refined"
  --out "$integration"
  --summary "$integration_summary"
)
[[ -n "$orthogroups" ]] && integrate_args+=(--orthogroups "$orthogroups")
[[ -n "$target_evidence" ]] && integrate_args+=(--target-evidence "$target_evidence")
[[ -n "$family_gain_loss" ]] && integrate_args+=(--family-gain-loss "$family_gain_loss")
"$python_cmd" "$script_dir/integrate_hgt_family_evolution.py" "${integrate_args[@]}"
