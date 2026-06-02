#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run_hisat2_rnaseq_alignment_workflow.sh --masked-genome genome.fa --pe1 reads_R1.fq.gz --pe2 reads_R2.fq.gz --outdir rnaseq_alignment [options]

Run an independent Stage 04 HISAT2 RNA-seq alignment workflow:
  1. Build a HISAT2 index from the masked genome.
  2. Align one or more paired-end RNA-seq libraries.
  3. Sort and index the RNA evidence BAM for gene prediction.

Required:
  --masked-genome FILE             Masked genome FASTA
  --pe1 FILE                       Forward RNA-seq reads; repeatable
  --pe2 FILE                       Reverse RNA-seq reads; repeatable
  --outdir DIR                     Output directory

Options:
  --output-name NAME               Output prefix [rnaseq]
  --threads INT                    Threads [16]
  --dta                            Pass --dta to HISAT2
  --hisat2-build CMD               hisat2-build executable [hisat2-build]
  --hisat2 CMD                     hisat2 executable [hisat2]
  --samtools CMD                   samtools executable [samtools]
  --hisat2-build-option TEXT       Additional hisat2-build option string; repeatable
  --hisat2-option TEXT             Additional hisat2 option string; repeatable
  --sort-option TEXT               Additional samtools sort option string; repeatable
  -h, --help                       Show this help
USAGE
}

masked_genome=""
pe1=()
pe2=()
outdir=""
output_name="rnaseq"
threads=16
dta=0
hisat2_build_cmd="hisat2-build"
hisat2_cmd="hisat2"
samtools_cmd="samtools"
hisat2_build_options=()
hisat2_options=()
sort_options=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --masked-genome) masked_genome=${2:?"Missing value for --masked-genome"}; shift 2 ;;
    --pe1) pe1+=("${2:?"Missing value for --pe1"}"); shift 2 ;;
    --pe2) pe2+=("${2:?"Missing value for --pe2"}"); shift 2 ;;
    --outdir) outdir=${2:?"Missing value for --outdir"}; shift 2 ;;
    --output-name) output_name=${2:?"Missing value for --output-name"}; shift 2 ;;
    --threads) threads=${2:?"Missing value for --threads"}; shift 2 ;;
    --dta) dta=1; shift ;;
    --hisat2-build) hisat2_build_cmd=${2:?"Missing value for --hisat2-build"}; shift 2 ;;
    --hisat2) hisat2_cmd=${2:?"Missing value for --hisat2"}; shift 2 ;;
    --samtools) samtools_cmd=${2:?"Missing value for --samtools"}; shift 2 ;;
    --hisat2-build-option) hisat2_build_options+=("${2:?"Missing value for --hisat2-build-option"}"); shift 2 ;;
    --hisat2-option) hisat2_options+=("${2:?"Missing value for --hisat2-option"}"); shift 2 ;;
    --sort-option) sort_options+=("${2:?"Missing value for --sort-option"}"); shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ -z "$masked_genome" || ${#pe1[@]} -eq 0 || -z "$outdir" ]]; then
  echo "Missing required HISAT2 input" >&2
  usage >&2
  exit 1
fi
if [[ ${#pe1[@]} -ne ${#pe2[@]} ]]; then
  echo "The number of --pe1 and --pe2 files must match" >&2
  exit 1
fi
if [[ ! "$threads" =~ ^[0-9]+$ || "$threads" -lt 1 ]]; then
  echo "--threads must be a positive integer" >&2
  exit 1
fi
if [[ ! -s "$masked_genome" ]]; then
  echo "Missing or empty masked genome FASTA: $masked_genome" >&2
  exit 1
fi
for file in "${pe1[@]}" "${pe2[@]}"; do
  if [[ ! -s "$file" ]]; then
    echo "Missing or empty RNA-seq read file: $file" >&2
    exit 1
  fi
done
for cmd in "$hisat2_build_cmd" "$hisat2_cmd" "$samtools_cmd"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required executable not found: $cmd" >&2
    exit 1
  fi
done

outdir_abs=$(mkdir -p "$outdir" && readlink -f "$outdir")
workdir="$outdir_abs/${output_name}.hisat2_work"
mkdir -p "$workdir"
masked_genome_abs=$(readlink -f "$masked_genome")

pe1_abs=()
pe2_abs=()
for file in "${pe1[@]}"; do
  pe1_abs+=("$(readlink -f "$file")")
done
for file in "${pe2[@]}"; do
  pe2_abs+=("$(readlink -f "$file")")
done
pe1_csv=$(IFS=,; printf '%s' "${pe1_abs[*]}")
pe2_csv=$(IFS=,; printf '%s' "${pe2_abs[*]}")

index_prefix="$workdir/genome"
build_log="$outdir_abs/${output_name}.hisat2_build.log"
align_log="$outdir_abs/${output_name}.hisat2_align.log"
runtime_log="$outdir_abs/${output_name}.hisat2_rnaseq_running_time.txt"
bam_out="$outdir_abs/${output_name}.rnaseq.sorted.bam"

build_args=(-p "$threads")
for option in "${hisat2_build_options[@]}"; do
  read -r -a option_parts <<< "$option"
  build_args+=("${option_parts[@]}")
done
build_args+=("$masked_genome_abs" "$index_prefix")

align_args=(-p "$threads" -x "$index_prefix")
[[ "$dta" -eq 1 ]] && align_args+=(--dta)
for option in "${hisat2_options[@]}"; do
  read -r -a option_parts <<< "$option"
  align_args+=("${option_parts[@]}")
done
align_args+=(-1 "$pe1_csv" -2 "$pe2_csv")

sort_args=(-@ "$threads" -o "$bam_out")
for option in "${sort_options[@]}"; do
  read -r -a option_parts <<< "$option"
  sort_args+=("${option_parts[@]}")
done

{
  printf '[%s] Workflow started\n' "$(date)"
  start=$(date +%s)
  "$hisat2_build_cmd" "${build_args[@]}" > "$build_log" 2>&1
  "$hisat2_cmd" "${align_args[@]}" 2> "$align_log" | "$samtools_cmd" sort "${sort_args[@]}"
  "$samtools_cmd" index "$bam_out"
  duration=$(( $(date +%s) - start ))
  awk -v s="$duration" 'BEGIN {printf "[%s] Duration: %.4f hours\n", strftime("%Y-%m-%d %H:%M:%S"), s/3600}'
} | tee -a "$runtime_log"

cat > "$outdir_abs/${output_name}.hisat2_rnaseq_manifest.tsv" <<MANIFEST
field	value
output_name	$output_name
masked_genome	$masked_genome_abs
pe_library_count	${#pe1_abs[@]}
threads	$threads
dta	$dta
workdir	$workdir
bam	$bam_out
bam_index	$bam_out.bai
build_log	$build_log
align_log	$align_log
runtime_log	$runtime_log
MANIFEST
