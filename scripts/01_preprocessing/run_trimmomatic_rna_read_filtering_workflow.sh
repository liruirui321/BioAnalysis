#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run_trimmomatic_rna_read_filtering_workflow.sh --sample sample --outdir rna_trimmomatic [read mode options]

Run an independent Stage 01 Trimmomatic RNA-seq raw-read filtering workflow:
  1. Run Trimmomatic in PE or SE mode.
  2. Apply optional adapter clipping and repeatable trimmer steps.
  3. Expose stable filtered FASTQ, summary, work script, runtime, and manifest outputs.

Required:
  --sample NAME                    Sample name
  --outdir DIR                     Output directory

Read modes, choose exactly one:
  --pe1 FILE                       Paired-end read 1
  --pe2 FILE                       Paired-end read 2
  --single-read FILE               Single-end read

Options:
  --phred33                        Use -phred33 [default]
  --phred64                        Use -phred64
  --adapter-file FILE              Adapter FASTA used in ILLUMINACLIP
  --adapter-name NAME              Adapter label recorded in manifest
  --trimmer TEXT                   Trimmer step; repeatable [SLIDINGWINDOW:4:20, MINLEN:36]
  --threads INT                    Threads [4]
  --trimmomatic CMD                Trimmomatic executable [trimmomatic]
  --trimmomatic-option TEXT        Additional Trimmomatic option string; repeatable
  -h, --help                       Show this help
USAGE
}

sample=""
outdir=""
pe1=""
pe2=""
single_read=""
phred="-phred33"
adapter_file=""
adapter_name="NA"
trimmers=()
threads=4
trimmomatic_cmd="trimmomatic"
trimmomatic_options=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sample) sample=${2:?"Missing value for --sample"}; shift 2 ;;
    --outdir) outdir=${2:?"Missing value for --outdir"}; shift 2 ;;
    --pe1) pe1=${2:?"Missing value for --pe1"}; shift 2 ;;
    --pe2) pe2=${2:?"Missing value for --pe2"}; shift 2 ;;
    --single-read) single_read=${2:?"Missing value for --single-read"}; shift 2 ;;
    --phred33) phred="-phred33"; shift ;;
    --phred64) phred="-phred64"; shift ;;
    --adapter-file) adapter_file=${2:?"Missing value for --adapter-file"}; shift 2 ;;
    --adapter-name) adapter_name=${2:?"Missing value for --adapter-name"}; shift 2 ;;
    --trimmer) trimmers+=("${2:?"Missing value for --trimmer"}"); shift 2 ;;
    --threads) threads=${2:?"Missing value for --threads"}; shift 2 ;;
    --trimmomatic) trimmomatic_cmd=${2:?"Missing value for --trimmomatic"}; shift 2 ;;
    --trimmomatic-option) trimmomatic_options+=("${2:?"Missing value for --trimmomatic-option"}"); shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ -z "$sample" || -z "$outdir" ]]; then
  echo "Missing required --sample or --outdir" >&2
  usage >&2
  exit 1
fi
if [[ ! "$threads" =~ ^[0-9]+$ || "$threads" -lt 1 ]]; then
  echo "--threads must be a positive integer" >&2
  exit 1
fi
mode_count=0
[[ -n "$pe1" || -n "$pe2" ]] && mode_count=$((mode_count + 1))
[[ -n "$single_read" ]] && mode_count=$((mode_count + 1))
if [[ "$mode_count" -ne 1 ]]; then
  echo "Choose exactly one read mode: --pe1/--pe2 or --single-read" >&2
  exit 1
fi
if [[ -n "$pe1" || -n "$pe2" ]]; then
  if [[ -z "$pe1" || -z "$pe2" ]]; then
    echo "Paired-end mode requires both --pe1 and --pe2" >&2
    exit 1
  fi
  for file in "$pe1" "$pe2"; do
    if [[ ! -s "$file" ]]; then
      echo "Missing or empty paired-end read file: $file" >&2
      exit 1
    fi
  done
else
  if [[ ! -s "$single_read" ]]; then
    echo "Missing or empty single-end read file: $single_read" >&2
    exit 1
  fi
fi
if [[ -n "$adapter_file" && ! -s "$adapter_file" ]]; then
  echo "Missing or empty adapter FASTA: $adapter_file" >&2
  exit 1
fi
if ! command -v "$trimmomatic_cmd" >/dev/null 2>&1; then
  echo "Trimmomatic executable not found: $trimmomatic_cmd" >&2
  exit 1
fi
if [[ ${#trimmers[@]} -eq 0 ]]; then
  trimmers=("SLIDINGWINDOW:4:20" "MINLEN:36")
fi

outdir_abs=$(mkdir -p "$outdir" && readlink -f "$outdir")
runtime_log="$outdir_abs/${sample}.rna_trimmomatic_running_time.txt"
summary="$outdir_abs/${sample}.rna.trimmomatic.summary"
work_script="$outdir_abs/${sample}.rna_trimmomatic_work.sh"
manifest="$outdir_abs/${sample}.rna_trimmomatic_manifest.tsv"
adapter_abs=""
[[ -n "$adapter_file" ]] && adapter_abs=$(readlink -f "$adapter_file")

run_args=()
mode="SE"
if [[ -n "$pe1" ]]; then
  mode="PE"
  pe1_abs=$(readlink -f "$pe1")
  pe2_abs=$(readlink -f "$pe2")
  out_1_paired="$outdir_abs/${sample}.rna_1_paired.fq.gz"
  out_1_unpaired="$outdir_abs/${sample}.rna_1_unpaired.fq.gz"
  out_2_paired="$outdir_abs/${sample}.rna_2_paired.fq.gz"
  out_2_unpaired="$outdir_abs/${sample}.rna_2_unpaired.fq.gz"
  run_args=(PE -threads "$threads" "$phred" -summary "$summary" "$pe1_abs" "$pe2_abs" "$out_1_paired" "$out_1_unpaired" "$out_2_paired" "$out_2_unpaired")
else
  single_abs=$(readlink -f "$single_read")
  out_single="$outdir_abs/${sample}.rna.fq.gz"
  run_args=(SE -threads "$threads" "$phred" -summary "$summary" "$single_abs" "$out_single")
fi
for option in "${trimmomatic_options[@]}"; do
  read -r -a option_parts <<< "$option"
  run_args+=("${option_parts[@]}")
done
[[ -n "$adapter_abs" ]] && run_args+=("ILLUMINACLIP:${adapter_abs}:2:30:10")
run_args+=("${trimmers[@]}")

{
  printf '#!/usr/bin/env bash\n'
  printf 'set -euo pipefail\n'
  printf '%q' "$trimmomatic_cmd"
  for arg in "${run_args[@]}"; do
    printf ' %q' "$arg"
  done
  printf '\n'
} > "$work_script"
chmod +x "$work_script"

{
  printf '[%s] Workflow started\n' "$(date)"
  start=$(date +%s)
  "$work_script"
  duration=$(( $(date +%s) - start ))
  awk -v s="$duration" 'BEGIN {printf "[%s] Duration: %.4f hours\n", strftime("%Y-%m-%d %H:%M:%S"), s/3600}'
} | tee -a "$runtime_log"

cat > "$manifest" <<MANIFEST
field	value
sample	$sample
read_type	rna
mode	$mode
phred	$phred
threads	$threads
adapter_file	${adapter_abs:-NA}
adapter_name	$adapter_name
summary	$summary
work_script	$work_script
runtime_log	$runtime_log
MANIFEST
