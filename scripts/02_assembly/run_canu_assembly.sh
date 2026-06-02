#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run_canu_assembly.sh --read reads.fq.gz --read-type nanopore --genome-size 200m --outdir canu_assembly [options]

Run an independent Stage 02 Canu assembly workflow:
  1. Run Canu with ONT, PacBio CLR, or PacBio HiFi reads.
  2. Expose Canu contigs as a stable assembly FASTA.
  3. Write stable assembly statistics.

Required:
  --read FILE                  Read FASTA/FASTQ; repeatable
  --read-type TYPE             nanopore|pacbio|pacbio-hifi
  --genome-size SIZE           Estimated genome size, for example 200m
  --outdir DIR                 Output directory

Options:
  --prefix NAME                Output prefix [first read basename]
  --threads INT                Canu maxThreads [32]
  --memory-gb INT              Canu maxMemory [250]
  --max-input-coverage VALUE   Optional Canu maxInputCoverage
  --canu CMD                   Canu executable [canu]
  --python CMD                 Python executable [python3]
  --canu-option KEY=VALUE      Additional Canu key=value option; repeatable
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
memory_gb=250
max_input_coverage=""
canu_cmd="canu"
python_cmd="python3"
skip_assembly_stats=0
canu_options=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --read) reads+=("${2:?"Missing value for --read"}"); shift 2 ;;
    --read-type) read_type=${2:?"Missing value for --read-type"}; shift 2 ;;
    --genome-size) genome_size=${2:?"Missing value for --genome-size"}; shift 2 ;;
    --outdir) outdir=${2:?"Missing value for --outdir"}; shift 2 ;;
    --prefix) prefix=${2:?"Missing value for --prefix"}; shift 2 ;;
    --threads) threads=${2:?"Missing value for --threads"}; shift 2 ;;
    --memory-gb) memory_gb=${2:?"Missing value for --memory-gb"}; shift 2 ;;
    --max-input-coverage) max_input_coverage=${2:?"Missing value for --max-input-coverage"}; shift 2 ;;
    --canu) canu_cmd=${2:?"Missing value for --canu"}; shift 2 ;;
    --python) python_cmd=${2:?"Missing value for --python"}; shift 2 ;;
    --canu-option) canu_options+=("${2:?"Missing value for --canu-option"}"); shift 2 ;;
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
  nanopore|pacbio|pacbio-hifi) ;;
  *) echo "Unsupported --read-type: $read_type" >&2; exit 1 ;;
esac
for value_name in threads memory_gb; do
  value=${!value_name}
  if [[ ! "$value" =~ ^[0-9]+$ || "$value" -lt 1 ]]; then
    echo "--${value_name//_/-} must be a positive integer" >&2
    exit 1
  fi
done
for file in "${reads[@]}"; do
  if [[ ! -s "$file" ]]; then
    echo "Missing or empty read file: $file" >&2
    exit 1
  fi
done
if ! command -v "$canu_cmd" >/dev/null 2>&1; then
  echo "Canu executable not found: $canu_cmd" >&2
  exit 1
fi
for option in "${canu_options[@]}"; do
  if [[ "$option" != *=* ]]; then
    echo "Invalid --canu-option, expected KEY=VALUE: $option" >&2
    exit 1
  fi
done

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
workdir="$outdir_abs/${prefix}.canu_work"
read_abs=()
for file in "${reads[@]}"; do
  read_abs+=("$(readlink -f "$file")")
done
read_flag="-$read_type"
canu_args=(-p "$prefix" -d "$workdir" "genomeSize=$genome_size" "maxThreads=$threads" "maxMemory=$memory_gb")
[[ -n "$max_input_coverage" ]] && canu_args+=("maxInputCoverage=$max_input_coverage")
canu_args+=("${canu_options[@]}")
canu_args+=("$read_flag" "${read_abs[@]}")
"$canu_cmd" "${canu_args[@]}"

candidate_fastas=("$workdir/${prefix}.contigs.fasta" "$workdir/${prefix}.contigs.fa")
final_fasta=""
for candidate in "${candidate_fastas[@]}"; do
  if [[ -s "$candidate" ]]; then
    final_fasta="$candidate"
    break
  fi
done
if [[ -z "$final_fasta" ]]; then
  echo "No Canu contig FASTA found. Checked: ${candidate_fastas[*]}" >&2
  exit 1
fi
assembly_fa="$outdir_abs/${prefix}.canu.assembly.fa"
cp "$final_fasta" "$assembly_fa"
if [[ ! -s "$assembly_fa" ]]; then
  echo "Failed to expose Canu assembly FASTA" >&2
  exit 1
fi

if [[ "$skip_assembly_stats" -eq 0 ]]; then
  "$python_cmd" "$script_dir/assembly_stats.py" \
    --fasta "$assembly_fa" \
    --out "$outdir_abs/${prefix}.canu.assembly_stats.tsv" \
    --lengths "$outdir_abs/${prefix}.canu.assembly_lengths.tsv"
fi
