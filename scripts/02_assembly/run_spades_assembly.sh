#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run_spades_assembly.sh --pe1 reads_1.fq.gz --pe2 reads_2.fq.gz --outdir spades_assembly [options]

Run an independent Stage 02 SPAdes assembly workflow:
  1. Run spades.py with one or more paired-end libraries.
  2. Expose scaffolds.fasta or contigs.fasta as a stable assembly FASTA.
  3. Write stable assembly statistics.

Required:
  --pe1 FILE                   Paired-end read 1; repeatable with --pe2
  --pe2 FILE                   Paired-end read 2; repeatable with --pe1
  --outdir DIR                 Output directory

Options:
  --prefix NAME                Output prefix [spades]
  --threads INT                SPAdes threads [32]
  --memory-gb INT              SPAdes memory in GB [250]
  --isolate                    Pass --isolate to SPAdes
  --careful                    Pass --careful to SPAdes
  --spades CMD                 spades.py executable [spades.py]
  --python CMD                 Python executable [python3]
  --spades-option TEXT         Additional SPAdes option string; repeatable
  --skip-assembly-stats        Skip assembly_stats.py handoff
  -h, --help                   Show this help
USAGE
}

pe1=()
pe2=()
outdir=""
prefix="spades"
threads=32
memory_gb=250
isolate=0
careful=0
spades_cmd="spades.py"
python_cmd="python3"
skip_assembly_stats=0
spades_options=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pe1) pe1+=("${2:?"Missing value for --pe1"}"); shift 2 ;;
    --pe2) pe2+=("${2:?"Missing value for --pe2"}"); shift 2 ;;
    --outdir) outdir=${2:?"Missing value for --outdir"}; shift 2 ;;
    --prefix) prefix=${2:?"Missing value for --prefix"}; shift 2 ;;
    --threads) threads=${2:?"Missing value for --threads"}; shift 2 ;;
    --memory-gb) memory_gb=${2:?"Missing value for --memory-gb"}; shift 2 ;;
    --isolate) isolate=1; shift ;;
    --careful) careful=1; shift ;;
    --spades) spades_cmd=${2:?"Missing value for --spades"}; shift 2 ;;
    --python) python_cmd=${2:?"Missing value for --python"}; shift 2 ;;
    --spades-option) spades_options+=("${2:?"Missing value for --spades-option"}"); shift 2 ;;
    --skip-assembly-stats) skip_assembly_stats=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ -z "$outdir" || ${#pe1[@]} -eq 0 || ${#pe2[@]} -eq 0 ]]; then
  echo "Missing required paired reads or --outdir" >&2
  usage >&2
  exit 1
fi
if [[ ${#pe1[@]} -ne ${#pe2[@]} ]]; then
  echo "Provide the same number of --pe1 and --pe2 values" >&2
  exit 1
fi
for value_name in threads memory_gb; do
  value=${!value_name}
  if [[ ! "$value" =~ ^[0-9]+$ || "$value" -lt 1 ]]; then
    echo "--${value_name//_/-} must be a positive integer" >&2
    exit 1
  fi
done
for file in "${pe1[@]}" "${pe2[@]}"; do
  if [[ ! -s "$file" ]]; then
    echo "Missing or empty read file: $file" >&2
    exit 1
  fi
done
if ! command -v "$spades_cmd" >/dev/null 2>&1; then
  echo "SPAdes executable not found: $spades_cmd" >&2
  exit 1
fi

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
outdir_abs=$(mkdir -p "$outdir" && readlink -f "$outdir")
workdir="$outdir_abs/${prefix}.spades_work"

spades_args=(-o "$workdir" -t "$threads" -m "$memory_gb")
[[ "$isolate" -eq 1 ]] && spades_args+=(--isolate)
[[ "$careful" -eq 1 ]] && spades_args+=(--careful)
for i in "${!pe1[@]}"; do
  library=$((i + 1))
  spades_args+=("--pe${library}-1" "$(readlink -f "${pe1[$i]}")")
  spades_args+=("--pe${library}-2" "$(readlink -f "${pe2[$i]}")")
done
for option in "${spades_options[@]}"; do
  read -r -a option_parts <<< "$option"
  spades_args+=("${option_parts[@]}")
done
"$spades_cmd" "${spades_args[@]}"

candidate_fastas=("$workdir/scaffolds.fasta" "$workdir/contigs.fasta")
final_fasta=""
for candidate in "${candidate_fastas[@]}"; do
  if [[ -s "$candidate" ]]; then
    final_fasta="$candidate"
    break
  fi
done
if [[ -z "$final_fasta" ]]; then
  echo "No SPAdes final FASTA found. Checked: ${candidate_fastas[*]}" >&2
  exit 1
fi
assembly_fa="$outdir_abs/${prefix}.spades.assembly.fa"
cp "$final_fasta" "$assembly_fa"
if [[ ! -s "$assembly_fa" ]]; then
  echo "Failed to expose SPAdes assembly FASTA" >&2
  exit 1
fi

if [[ "$skip_assembly_stats" -eq 0 ]]; then
  "$python_cmd" "$script_dir/assembly_stats.py" \
    --fasta "$assembly_fa" \
    --out "$outdir_abs/${prefix}.spades.assembly_stats.tsv" \
    --lengths "$outdir_abs/${prefix}.spades.assembly_lengths.tsv"
fi
