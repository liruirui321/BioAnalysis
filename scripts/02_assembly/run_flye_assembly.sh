#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run_flye_assembly.sh --read reads.fq.gz --read-type nano-raw --genome-size 200m --outdir flye_assembly [options]

Run an independent Stage 02 Flye assembly workflow:
  1. Run Flye with ONT, PacBio, or HiFi reads.
  2. Expose assembly.fasta as a stable assembly FASTA.
  3. Write stable assembly statistics.

Required:
  --read FILE                  Read FASTA/FASTQ; repeatable
  --read-type TYPE             nano-raw|nano-hq|pacbio-raw|pacbio-hifi
  --genome-size SIZE           Estimated genome size, for example 200m
  --outdir DIR                 Output directory

Options:
  --prefix NAME                Output prefix [first read basename]
  --threads INT                Flye threads [32]
  --flye CMD                   Flye executable [flye]
  --python CMD                 Python executable [python3]
  --flye-option TEXT           Additional Flye option string; repeatable
  --skip-assembly-stats        Skip assembly_stats.py handoff
  -h, --help                   Show this help
USAGE
}

reads=()
read_type=""
genome_size=""
outdir=""
prefix=""
threads=32
flye_cmd="flye"
python_cmd="python3"
skip_assembly_stats=0
flye_options=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --read) reads+=("${2:?"Missing value for --read"}"); shift 2 ;;
    --read-type) read_type=${2:?"Missing value for --read-type"}; shift 2 ;;
    --genome-size) genome_size=${2:?"Missing value for --genome-size"}; shift 2 ;;
    --outdir) outdir=${2:?"Missing value for --outdir"}; shift 2 ;;
    --prefix) prefix=${2:?"Missing value for --prefix"}; shift 2 ;;
    --threads) threads=${2:?"Missing value for --threads"}; shift 2 ;;
    --flye) flye_cmd=${2:?"Missing value for --flye"}; shift 2 ;;
    --python) python_cmd=${2:?"Missing value for --python"}; shift 2 ;;
    --flye-option) flye_options+=("${2:?"Missing value for --flye-option"}"); shift 2 ;;
    --skip-assembly-stats) skip_assembly_stats=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ ${#reads[@]} -eq 0 || -z "$read_type" || -z "$genome_size" || -z "$outdir" ]]; then
  echo "Missing required --read, --read-type, --genome-size, or --outdir" >&2
  usage >&2
  exit 1
fi
case "$read_type" in
  nano-raw|nano-hq|pacbio-raw|pacbio-hifi) ;;
  *) echo "Unsupported --read-type: $read_type" >&2; exit 1 ;;
esac
if [[ ! "$threads" =~ ^[0-9]+$ || "$threads" -lt 1 ]]; then
  echo "--threads must be a positive integer" >&2
  exit 1
fi
for file in "${reads[@]}"; do
  if [[ ! -s "$file" ]]; then
    echo "Missing or empty read file: $file" >&2
    exit 1
  fi
done
if ! command -v "$flye_cmd" >/dev/null 2>&1; then
  echo "Flye executable not found: $flye_cmd" >&2
  exit 1
fi

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
outdir_abs=$(mkdir -p "$outdir" && readlink -f "$outdir")
if [[ -z "$prefix" ]]; then
  prefix=$(basename "${reads[0]}")
  prefix=${prefix%.gz}
  prefix=${prefix%.fastq}
  prefix=${prefix%.fasta}
  prefix=${prefix%.fq}
  prefix=${prefix%.fa}
fi
workdir="$outdir_abs/${prefix}.flye_work"
read_abs=()
for file in "${reads[@]}"; do
  read_abs+=("$(readlink -f "$file")")
done
flye_args=(--genome-size "$genome_size" --threads "$threads" --out-dir "$workdir" "--$read_type" "${read_abs[@]}")
for option in "${flye_options[@]}"; do
  read -r -a option_parts <<< "$option"
  flye_args+=("${option_parts[@]}")
done
"$flye_cmd" "${flye_args[@]}"

final_fasta="$workdir/assembly.fasta"
if [[ ! -s "$final_fasta" ]]; then
  echo "No Flye final FASTA found: $final_fasta" >&2
  exit 1
fi
assembly_fa="$outdir_abs/${prefix}.flye.assembly.fa"
cp "$final_fasta" "$assembly_fa"
if [[ ! -s "$assembly_fa" ]]; then
  echo "Failed to expose Flye assembly FASTA" >&2
  exit 1
fi

if [[ "$skip_assembly_stats" -eq 0 ]]; then
  "$python_cmd" "$script_dir/assembly_stats.py" \
    --fasta "$assembly_fa" \
    --out "$outdir_abs/${prefix}.flye.assembly_stats.tsv" \
    --lengths "$outdir_abs/${prefix}.flye.assembly_lengths.tsv"
fi
