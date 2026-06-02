#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run_busco_qc_workflow.sh --input assembly.fa --lineage embryophyta_odb10 --outdir busco_qc [options]

Run an independent Stage 02 BUSCO QC workflow:
  1. Optionally run BUSCO on genome, protein, or transcript inputs.
  2. Summarize BUSCO short_summary JSON/TXT outputs into a stable TSV.

Required for BUSCO run mode:
  --input FILE              Genome/protein/transcript FASTA
  --lineage NAME_OR_PATH    BUSCO lineage dataset name or path
  --outdir DIR              Output directory

Summary-only mode:
  --summary FILE            Existing BUSCO short_summary JSON/TXT; repeatable
  --outdir DIR              Output directory

Options:
  --sample NAME             Sample/output prefix [input basename or busco_summary]
  --mode genome|proteins|transcriptome BUSCO mode [genome]
  --threads INT             BUSCO CPU threads [20]
  --busco CMD               BUSCO executable [busco]
  --python CMD              Python executable [python3]
  --busco-option TEXT       Additional BUSCO option string; repeatable
  --offline                 Pass --offline to BUSCO
  --force                   Pass --force to BUSCO
  --skip-run                Do not run BUSCO; summarize --summary files only
  --skip-assembly-stats     Skip assembly/N50 stats for genome FASTA input
  -h, --help                Show this help
USAGE
}

input=""
lineage=""
outdir=""
sample=""
mode="genome"
threads=20
busco_cmd="busco"
python_cmd="python3"
offline=0
force=0
skip_run=0
skip_assembly_stats=0
busco_options=()
summaries=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input) input=${2:?"Missing value for --input"}; shift 2 ;;
    --lineage) lineage=${2:?"Missing value for --lineage"}; shift 2 ;;
    --outdir) outdir=${2:?"Missing value for --outdir"}; shift 2 ;;
    --sample) sample=${2:?"Missing value for --sample"}; shift 2 ;;
    --mode) mode=${2:?"Missing value for --mode"}; shift 2 ;;
    --threads) threads=${2:?"Missing value for --threads"}; shift 2 ;;
    --busco) busco_cmd=${2:?"Missing value for --busco"}; shift 2 ;;
    --python) python_cmd=${2:?"Missing value for --python"}; shift 2 ;;
    --busco-option) busco_options+=("${2:?"Missing value for --busco-option"}"); shift 2 ;;
    --summary) summaries+=("${2:?"Missing value for --summary"}"); shift 2 ;;
    --offline) offline=1; shift ;;
    --force) force=1; shift ;;
    --skip-run) skip_run=1; shift ;;
    --skip-assembly-stats) skip_assembly_stats=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ -z "$outdir" ]]; then
  echo "Missing required --outdir" >&2
  usage >&2
  exit 1
fi
case "$mode" in
  genome|proteins|transcriptome) ;;
  *) echo "Unsupported --mode: $mode" >&2; exit 1 ;;
esac
for file in "${summaries[@]}"; do
  if [[ ! -s "$file" ]]; then
    echo "Missing or empty BUSCO summary: $file" >&2
    exit 1
  fi
done
if [[ "$skip_run" -eq 0 && ${#summaries[@]} -eq 0 ]]; then
  if [[ -z "$input" || -z "$lineage" ]]; then
    echo "BUSCO run mode requires --input and --lineage" >&2
    usage >&2
    exit 1
  fi
  if [[ ! -s "$input" ]]; then
    echo "Missing or empty BUSCO input: $input" >&2
    exit 1
  fi
  if ! command -v "$busco_cmd" >/dev/null 2>&1; then
    echo "BUSCO executable not found: $busco_cmd" >&2
    exit 1
  fi
fi
if [[ "$skip_run" -eq 1 && ${#summaries[@]} -eq 0 ]]; then
  echo "--skip-run requires at least one --summary" >&2
  exit 1
fi

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
outdir_abs=$(mkdir -p "$outdir" && readlink -f "$outdir")
if [[ -z "$sample" ]]; then
  if [[ -n "$input" ]]; then
    sample=$(basename "$input")
    sample=${sample%.fasta}
    sample=${sample%.fa}
    sample=${sample%.faa}
    sample=${sample%.fna}
  else
    sample="busco_summary"
  fi
fi

if [[ "$skip_run" -eq 0 && ${#summaries[@]} -eq 0 ]]; then
  busco_args=(
    -i "$input"
    -o "$sample"
    -m "$mode"
    -l "$lineage"
    -c "$threads"
    --out_path "$outdir_abs"
  )
  [[ "$offline" -eq 1 ]] && busco_args+=(--offline)
  [[ "$force" -eq 1 ]] && busco_args+=(--force)
  for option in "${busco_options[@]}"; do
    read -r -a option_parts <<< "$option"
    busco_args+=("${option_parts[@]}")
  done
  "$busco_cmd" "${busco_args[@]}"
  while IFS= read -r -d '' file; do
    summaries+=("$file")
  done < <(find "$outdir_abs/$sample" -type f \( -name 'short_summary*.json' -o -name 'short_summary*.txt' \) -print0)
fi

if [[ ${#summaries[@]} -eq 0 ]]; then
  echo "No BUSCO short_summary files found" >&2
  exit 1
fi

summary_args=()
for file in "${summaries[@]}"; do
  summary_args+=(--summary "$file")
done
"$python_cmd" "$script_dir/summarize_busco_results.py" \
  "${summary_args[@]}" \
  --sample "$sample" \
  --input-file "${input:-NA}" \
  --mode "$mode" \
  --lineage "${lineage:-NA}" \
  --out "$outdir_abs/${sample}.busco_summary.tsv"

if [[ "$skip_assembly_stats" -eq 0 && "$mode" == "genome" && -n "$input" && -s "$input" ]]; then
  "$python_cmd" "$script_dir/assembly_stats.py" \
    --fasta "$input" \
    --out "$outdir_abs/${sample}.assembly_stats.tsv" \
    --lengths "$outdir_abs/${sample}.assembly_lengths.tsv"
fi
