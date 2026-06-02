#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run_haphic_scaffolding.sh --assembly assembly.fa --hic-r1 hic_R1.fq.gz --hic-r2 hic_R2.fq.gz --groups 12 --outdir haphic_scaffolding [options]

Run an independent Stage 02 HapHiC Hi-C scaffolding workflow:
  1. Index the input assembly and align Hi-C reads with chromap.
  2. Produce a coordinate-sorted BAM for HapHiC.
  3. Run HapHiC scaffolding as a downstream post-assembly step.
  4. Expose stable scaffold FASTA/AGP handoff files when produced and write stats.

Required:
  --assembly FILE              Input assembly FASTA
  --hic-r1 FILE                Hi-C read 1
  --hic-r2 FILE                Hi-C read 2
  --groups INT                 Expected chromosome/group count for HapHiC
  --outdir DIR                 Output directory

Options:
  --prefix NAME                Output prefix [assembly basename]
  --threads INT                Threads for chromap/samtools [32]
  --chromap CMD                chromap executable [chromap]
  --samtools CMD               samtools executable [samtools]
  --haphic CMD                 HapHiC executable or script [HapHiC]
  --python CMD                 Python executable [python3]
  --chromap-option TEXT        Additional chromap option string; repeatable
  --haphic-option TEXT         Additional HapHiC option string; repeatable
  --skip-assembly-stats        Skip scaffold stats handoff
  -h, --help                   Show this help
USAGE
}

assembly=""
hic_r1=""
hic_r2=""
groups=""
outdir=""
prefix=""
threads=32
chromap_cmd="chromap"
samtools_cmd="samtools"
haphic_cmd="HapHiC"
python_cmd="python3"
skip_assembly_stats=0
chromap_options=()
haphic_options=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --assembly) assembly=${2:?"Missing value for --assembly"}; shift 2 ;;
    --hic-r1) hic_r1=${2:?"Missing value for --hic-r1"}; shift 2 ;;
    --hic-r2) hic_r2=${2:?"Missing value for --hic-r2"}; shift 2 ;;
    --groups) groups=${2:?"Missing value for --groups"}; shift 2 ;;
    --outdir) outdir=${2:?"Missing value for --outdir"}; shift 2 ;;
    --prefix) prefix=${2:?"Missing value for --prefix"}; shift 2 ;;
    --threads) threads=${2:?"Missing value for --threads"}; shift 2 ;;
    --chromap) chromap_cmd=${2:?"Missing value for --chromap"}; shift 2 ;;
    --samtools) samtools_cmd=${2:?"Missing value for --samtools"}; shift 2 ;;
    --haphic) haphic_cmd=${2:?"Missing value for --haphic"}; shift 2 ;;
    --python) python_cmd=${2:?"Missing value for --python"}; shift 2 ;;
    --chromap-option) chromap_options+=("${2:?"Missing value for --chromap-option"}"); shift 2 ;;
    --haphic-option) haphic_options+=("${2:?"Missing value for --haphic-option"}"); shift 2 ;;
    --skip-assembly-stats) skip_assembly_stats=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

for name in assembly hic_r1 hic_r2 groups outdir; do
  value=${!name}
  if [[ -z "$value" ]]; then
    echo "Missing required --${name//_/-}" >&2
    usage >&2
    exit 1
  fi
done
for value_name in threads groups; do
  value=${!value_name}
  if [[ ! "$value" =~ ^[0-9]+$ || "$value" -lt 1 ]]; then
    echo "--${value_name//_/-} must be a positive integer" >&2
    exit 1
  fi
done
for file in "$assembly" "$hic_r1" "$hic_r2"; do
  if [[ ! -s "$file" ]]; then
    echo "Missing or empty input file: $file" >&2
    exit 1
  fi
done
for cmd in "$chromap_cmd" "$samtools_cmd"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required executable not found: $cmd" >&2
    exit 1
  fi
done
if ! command -v "$haphic_cmd" >/dev/null 2>&1 && [[ ! -f "$haphic_cmd" ]]; then
  echo "HapHiC executable or script not found: $haphic_cmd" >&2
  exit 1
fi

resolve_cmd() {
  local cmd=$1
  if [[ -f "$cmd" ]]; then
    readlink -f "$cmd"
  else
    command -v "$cmd"
  fi
}

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
outdir_abs=$(mkdir -p "$outdir" && readlink -f "$outdir")
if [[ -z "$prefix" ]]; then
  prefix=$(basename "$assembly")
  prefix=${prefix%.gz}
  prefix=${prefix%.fasta}
  prefix=${prefix%.fa}
  prefix=${prefix%.fna}
fi
workdir="$outdir_abs/${prefix}.haphic_work"
mkdir -p "$workdir"
assembly_abs=$(readlink -f "$assembly")
hic_r1_abs=$(readlink -f "$hic_r1")
hic_r2_abs=$(readlink -f "$hic_r2")
haphic_resolved=$(resolve_cmd "$haphic_cmd")

(
  cd "$workdir"
  "$samtools_cmd" faidx "$assembly_abs"
  "$chromap_cmd" -i -r "$assembly_abs" -o contigs.index
  chromap_args=(--preset hic -r "$assembly_abs" -x contigs.index --remove-pcr-duplicates -1 "$hic_r1_abs" -2 "$hic_r2_abs" --SAM -o aligned.sam -t "$threads")
  for option in "${chromap_options[@]}"; do
    read -r -a option_parts <<< "$option"
    chromap_args+=("${option_parts[@]}")
  done
  "$chromap_cmd" "${chromap_args[@]}"
  "$samtools_cmd" view -bh aligned.sam | "$samtools_cmd" sort -@ "$threads" -o aligned.sorted.bam
  "$samtools_cmd" index aligned.sorted.bam
  rm -f aligned.sam
  haphic_args=(scaffold --fasta "$assembly_abs" --bam aligned.sorted.bam --groups "$groups" --outdir haphic.out --threads "$threads")
  for option in "${haphic_options[@]}"; do
    read -r -a option_parts <<< "$option"
    haphic_args+=("${option_parts[@]}")
  done
  "$haphic_resolved" "${haphic_args[@]}"
)

scaffold_fa=""
while IFS= read -r -d '' candidate; do
  scaffold_fa="$candidate"
  break
done < <(find "$workdir" -type f \( -name '*scaffold*.fa' -o -name '*scaffold*.fasta' -o -name '*scaffolds*.fa' -o -name '*scaffolds*.fasta' \) -print0 | sort -z)
agp=""
while IFS= read -r -d '' candidate; do
  agp="$candidate"
  break
done < <(find "$workdir" -type f -name '*.agp' -print0 | sort -z)
if [[ -z "$scaffold_fa" ]]; then
  echo "HapHiC scaffold FASTA was not found; keeping native outputs in $workdir" >&2
else
  handoff_fa="$outdir_abs/${prefix}.haphic.scaffolds.fa"
  cp "$scaffold_fa" "$handoff_fa"
  if [[ "$skip_assembly_stats" -eq 0 ]]; then
    "$python_cmd" "$script_dir/assembly_stats.py" \
      --fasta "$handoff_fa" \
      --out "$outdir_abs/${prefix}.haphic.scaffolds_stats.tsv" \
      --lengths "$outdir_abs/${prefix}.haphic.scaffolds_lengths.tsv"
  fi
fi
if [[ -n "$agp" ]]; then
  cp "$agp" "$outdir_abs/${prefix}.haphic.agp"
fi
