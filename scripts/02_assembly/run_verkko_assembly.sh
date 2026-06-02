#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run_verkko_assembly.sh --hifi reads.fa --outdir verkko_assembly [options]

Run an independent Stage 02 Verkko assembly workflow:
  1. Run Verkko with HiFi reads and optional ONT/Hi-C reads.
  2. Expose Verkko assembly FASTA as a stable assembly FASTA.
  3. Write stable assembly statistics.

Required:
  --hifi FILE                  HiFi read FASTA/FASTQ; repeatable
  --outdir DIR                 Output directory

Options:
  --prefix NAME                Output prefix [first HiFi basename]
  --nano FILE                  Optional ONT read FASTA/FASTQ; repeatable
  --hic-r1 FILE                Optional Hi-C read 1 passed to Verkko --hic1
  --hic-r2 FILE                Optional Hi-C read 2 passed to Verkko --hic2
  --threads INT                Verkko threads [32]
  --verkko CMD                 Verkko executable [verkko]
  --python CMD                 Python executable [python3]
  --verkko-option TEXT         Additional Verkko option string; repeatable
  --skip-assembly-stats        Skip assembly_stats.py handoff
  -h, --help                   Show this help
USAGE
}

hifi_reads=()
nano_reads=()
outdir=""
prefix=""
hic_r1=""
hic_r2=""
threads=32
verkko_cmd="verkko"
python_cmd="python3"
skip_assembly_stats=0
verkko_options=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --hifi) hifi_reads+=("${2:?"Missing value for --hifi"}"); shift 2 ;;
    --nano) nano_reads+=("${2:?"Missing value for --nano"}"); shift 2 ;;
    --outdir) outdir=${2:?"Missing value for --outdir"}; shift 2 ;;
    --prefix) prefix=${2:?"Missing value for --prefix"}; shift 2 ;;
    --hic-r1) hic_r1=${2:?"Missing value for --hic-r1"}; shift 2 ;;
    --hic-r2) hic_r2=${2:?"Missing value for --hic-r2"}; shift 2 ;;
    --threads) threads=${2:?"Missing value for --threads"}; shift 2 ;;
    --verkko) verkko_cmd=${2:?"Missing value for --verkko"}; shift 2 ;;
    --python) python_cmd=${2:?"Missing value for --python"}; shift 2 ;;
    --verkko-option) verkko_options+=("${2:?"Missing value for --verkko-option"}"); shift 2 ;;
    --skip-assembly-stats) skip_assembly_stats=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ ${#hifi_reads[@]} -eq 0 || -z "$outdir" ]]; then
  echo "Missing required --hifi or --outdir" >&2
  usage >&2
  exit 1
fi
if [[ ! "$threads" =~ ^[0-9]+$ || "$threads" -lt 1 ]]; then
  echo "--threads must be a positive integer" >&2
  exit 1
fi
if [[ -n "$hic_r1" || -n "$hic_r2" ]]; then
  if [[ -z "$hic_r1" || -z "$hic_r2" ]]; then
    echo "Provide --hic-r1 and --hic-r2 together" >&2
    exit 1
  fi
fi
for file in "${hifi_reads[@]}" "${nano_reads[@]}" "$hic_r1" "$hic_r2"; do
  [[ -z "$file" ]] && continue
  if [[ ! -s "$file" ]]; then
    echo "Missing or empty input file: $file" >&2
    exit 1
  fi
done
if ! command -v "$verkko_cmd" >/dev/null 2>&1; then
  echo "Verkko executable not found: $verkko_cmd" >&2
  exit 1
fi

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
outdir_abs=$(mkdir -p "$outdir" && readlink -f "$outdir")
if [[ -z "$prefix" ]]; then
  prefix=$(basename "${hifi_reads[0]}")
  prefix=${prefix%.gz}
  prefix=${prefix%.fasta}
  prefix=${prefix%.fastq}
  prefix=${prefix%.fa}
  prefix=${prefix%.fq}
fi
workdir="$outdir_abs/${prefix}.verkko_work"

verkko_args=(-d "$workdir" --threads "$threads")
for file in "${hifi_reads[@]}"; do
  verkko_args+=(--hifi "$(readlink -f "$file")")
done
for file in "${nano_reads[@]}"; do
  verkko_args+=(--nano "$(readlink -f "$file")")
done
if [[ -n "$hic_r1" ]]; then
  verkko_args+=(--hic1 "$(readlink -f "$hic_r1")" --hic2 "$(readlink -f "$hic_r2")")
fi
for option in "${verkko_options[@]}"; do
  read -r -a option_parts <<< "$option"
  verkko_args+=("${option_parts[@]}")
done
"$verkko_cmd" "${verkko_args[@]}"

candidate_fastas=(
  "$workdir/assembly.fasta"
  "$workdir/assembly/assembly.fasta"
  "$workdir/assembly.haplotype1.fasta"
  "$workdir/assembly.haplotype2.fasta"
)
final_fasta=""
for candidate in "${candidate_fastas[@]}"; do
  if [[ -s "$candidate" ]]; then
    final_fasta="$candidate"
    break
  fi
done
if [[ -z "$final_fasta" ]]; then
  echo "No Verkko final FASTA found. Checked: ${candidate_fastas[*]}" >&2
  exit 1
fi
assembly_fa="$outdir_abs/${prefix}.verkko.assembly.fa"
cp "$final_fasta" "$assembly_fa"
if [[ ! -s "$assembly_fa" ]]; then
  echo "Failed to expose Verkko assembly FASTA" >&2
  exit 1
fi

if [[ "$skip_assembly_stats" -eq 0 ]]; then
  "$python_cmd" "$script_dir/assembly_stats.py" \
    --fasta "$assembly_fa" \
    --out "$outdir_abs/${prefix}.verkko.assembly_stats.tsv" \
    --lengths "$outdir_abs/${prefix}.verkko.assembly_lengths.tsv"
fi
