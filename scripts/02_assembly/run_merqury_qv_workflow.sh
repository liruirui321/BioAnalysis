#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run_merqury_qv_workflow.sh --genome genome.fa --read reads.fq.gz --outdir merqury_qv [options]

Run an independent Stage 02 Merqury QV assessment workflow:
  1. Estimate or use a supplied k-mer size.
  2. Build and merge meryl databases from read files.
  3. Run merqury.sh for assembly QV/completeness outputs.
  4. Summarize Merqury QV output files into a stable TSV.

Run mode requires:
  --genome FILE                 Genome FASTA
  --read FILE                   Read FASTQ/FASTA file; repeatable
  --outdir DIR                  Output directory

Summary-only mode:
  --merqury-dir DIR             Existing Merqury output directory
  --merqury-file FILE           Existing Merqury output file; repeatable
  --outdir DIR                  Output directory
  --skip-run                    Do not run meryl/merqury

Options:
  --prefix NAME                 Output prefix [genome basename]
  --kmer INT                    Default k-mer size when --best-k is not used [21]
  --best-k                      Estimate k-mer size using best_k.sh when available
  --genome-size INT             Genome size for --best-k; defaults to FASTA total length
  --meryl CMD                   meryl executable [meryl]
  --merqury-sh FILE             merqury.sh path or command [merqury.sh]
  --best-k-sh FILE              best_k.sh path or command [best_k.sh]
  --python CMD                  Python executable [python3]
  --cleanup                     Remove bulky meryl/log/intermediate files after summary
  -h, --help                    Show this help
USAGE
}

genome=""
outdir=""
prefix=""
kmer=21
best_k=0
genome_size=""
meryl_cmd="meryl"
merqury_sh="merqury.sh"
best_k_sh="best_k.sh"
python_cmd="python3"
cleanup=0
skip_run=0
reads=()
merqury_files=()
merqury_dir=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --genome) genome=${2:?"Missing value for --genome"}; shift 2 ;;
    --read) reads+=("${2:?"Missing value for --read"}"); shift 2 ;;
    --outdir) outdir=${2:?"Missing value for --outdir"}; shift 2 ;;
    --prefix) prefix=${2:?"Missing value for --prefix"}; shift 2 ;;
    --kmer) kmer=${2:?"Missing value for --kmer"}; shift 2 ;;
    --best-k) best_k=1; shift ;;
    --genome-size) genome_size=${2:?"Missing value for --genome-size"}; shift 2 ;;
    --meryl) meryl_cmd=${2:?"Missing value for --meryl"}; shift 2 ;;
    --merqury-sh) merqury_sh=${2:?"Missing value for --merqury-sh"}; shift 2 ;;
    --best-k-sh) best_k_sh=${2:?"Missing value for --best-k-sh"}; shift 2 ;;
    --python) python_cmd=${2:?"Missing value for --python"}; shift 2 ;;
    --merqury-file) merqury_files+=("${2:?"Missing value for --merqury-file"}"); shift 2 ;;
    --merqury-dir) merqury_dir=${2:?"Missing value for --merqury-dir"}; shift 2 ;;
    --skip-run) skip_run=1; shift ;;
    --cleanup) cleanup=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ -z "$outdir" ]]; then
  echo "Missing required --outdir" >&2
  usage >&2
  exit 1
fi
if [[ -z "$prefix" ]]; then
  if [[ -n "$genome" ]]; then
    prefix=$(basename "$genome")
    prefix=${prefix%.fasta}
    prefix=${prefix%.fa}
    prefix=${prefix%.fna}
  else
    prefix="genome"
  fi
fi
for file in "${merqury_files[@]}"; do
  if [[ ! -s "$file" ]]; then
    echo "Missing or empty Merqury output file: $file" >&2
    exit 1
  fi
done
if [[ -n "$merqury_dir" && ! -d "$merqury_dir" ]]; then
  echo "Missing Merqury output directory: $merqury_dir" >&2
  exit 1
fi
if [[ "$skip_run" -eq 0 ]]; then
  if [[ -z "$genome" || ${#reads[@]} -eq 0 ]]; then
    echo "Run mode requires --genome and at least one --read" >&2
    usage >&2
    exit 1
  fi
  if [[ ! -s "$genome" ]]; then
    echo "Missing or empty genome FASTA: $genome" >&2
    exit 1
  fi
  for file in "${reads[@]}"; do
    if [[ ! -s "$file" ]]; then
      echo "Missing or empty read file: $file" >&2
      exit 1
    fi
  done
  if ! command -v "$meryl_cmd" >/dev/null 2>&1; then
    echo "meryl executable not found: $meryl_cmd" >&2
    exit 1
  fi
  if ! command -v "$merqury_sh" >/dev/null 2>&1 && [[ ! -f "$merqury_sh" ]]; then
    echo "merqury.sh not found: $merqury_sh" >&2
    exit 1
  fi
fi

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
outdir_abs=$(mkdir -p "$outdir" && readlink -f "$outdir")
workdir="$outdir_abs/${prefix}.merqury_work"

resolve_script() {
  local script=$1
  if [[ -f "$script" ]]; then
    readlink -f "$script"
  else
    command -v "$script"
  fi
}

fasta_total_length() {
  "$python_cmd" - "$1" <<'PY'
from pathlib import Path
import sys
length = 0
with open(sys.argv[1]) as handle:
    for line in handle:
        if not line.startswith(">"):
            length += len(line.strip())
print(length)
PY
}

normalize_kmer() {
  local value=$1
  local fallback=$2
  if [[ ! "$value" =~ ^[0-9]+$ || "$value" -lt 1 ]]; then
    value=$fallback
  fi
  if (( value % 2 == 0 )); then
    value=$((value - 1))
  fi
  if (( value < 15 )); then
    value=15
  elif (( value > 31 )); then
    value=31
  fi
  printf '%s\n' "$value"
}

if [[ "$skip_run" -eq 0 ]]; then
  mkdir -p "$workdir"
  genome_abs=$(readlink -f "$genome")
  merqury_sh_resolved=$(resolve_script "$merqury_sh")
  best_k_sh_resolved=$(resolve_script "$best_k_sh" || true)
  read_abs=()
  for file in "${reads[@]}"; do
    read_abs+=("$(readlink -f "$file")")
  done
  final_kmer=$kmer
  (
    cd "$workdir"
    if [[ "$best_k" -eq 1 ]]; then
      if [[ -z "$genome_size" ]]; then
        genome_size=$(fasta_total_length "$genome_abs")
      fi
      if [[ -n "$best_k_sh_resolved" ]]; then
        sh "$best_k_sh_resolved" "$genome_size" 0.001 > best_k_result.txt
        calculated_k=$(tail -n 1 best_k_result.txt | tr -d '[:space:]')
        calculated_k=${calculated_k%.*}
        final_kmer=$(normalize_kmer "${calculated_k:-$kmer}" "$kmer")
      else
        printf 'best_k.sh not found; using supplied k-mer %s\n' "$kmer" > best_k_result.txt
        final_kmer=$(normalize_kmer "$kmer" "$kmer")
      fi
    else
      final_kmer=$(normalize_kmer "$kmer" "$kmer")
      printf 'Using supplied k-mer %s\n' "$final_kmer" > best_k_result.txt
    fi

    meryl_dirs=()
    for file in "${read_abs[@]}"; do
      base=$(basename "$file")
      base=${base%.gz}
      base=${base%.fastq}
      base=${base%.fq}
      base=${base%.fasta}
      base=${base%.fa}
      db="${base}.meryl"
      "$meryl_cmd" k="$final_kmer" count output "$db" "$file"
      meryl_dirs+=("$db")
    done
    if [[ ${#meryl_dirs[@]} -gt 1 ]]; then
      "$meryl_cmd" union-sum output reads.meryl "${meryl_dirs[@]}"
    else
      mv "${meryl_dirs[0]}" reads.meryl
    fi
    sh "$merqury_sh_resolved" reads.meryl "$genome_abs" "$prefix"
    printf '%s\n' "$final_kmer" > final_kmer.txt
  )
  merqury_dir="$workdir"
fi

summary_args=(--sample "$prefix" --out "$outdir_abs/${prefix}.merqury_qv_summary.tsv")
for file in "${merqury_files[@]}"; do
  summary_args+=(--input "$file")
done
[[ -n "$merqury_dir" ]] && summary_args+=(--dir "$merqury_dir")
"$python_cmd" "$script_dir/summarize_merqury_qv.py" "${summary_args[@]}"

if [[ "$cleanup" -eq 1 && "$skip_run" -eq 0 ]]; then
  find "$workdir" -maxdepth 1 -type d -name '*.meryl' -exec rm -rf {} +
  find "$workdir" -maxdepth 1 -type f \( -name '*filt*' -o -name '*logs*' -o -name '*stats*' -o -name '*ploidy*' -o -name '*.bed' \) -delete
fi
