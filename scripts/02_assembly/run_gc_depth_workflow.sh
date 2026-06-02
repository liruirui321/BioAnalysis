#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run_gc_depth_workflow.sh --genome genome.fa --outdir gc_depth [read mode options]

Run an independent Stage 02 GC-depth assembly QC workflow:
  1. Map WGS paired reads with BWA or long reads with minimap2.
  2. Sort and index the alignment BAM.
  3. Calculate per-base depth and generate a GC-depth plot with an external script.

Required:
  --genome FILE                    Genome FASTA
  --outdir DIR                     Output directory

Read modes, choose exactly one:
  --wgs-r1 FILE                    WGS paired-end R1; repeatable with --wgs-r2
  --wgs-r2 FILE                    WGS paired-end R2; repeatable with --wgs-r1
  --hifi FILE                      PacBio HiFi reads; repeatable
  --ont FILE                       ONT reads; repeatable
  --cyclone FILE                   ONT/Cyclone reads; repeatable alias for --ont

Options:
  --output-name NAME               Output prefix [gc_depth]
  --split-index TEXT               minimap2 split index size [8G]
  --window INT                     Plot window size [1000]
  --step INT                       Plot step size [1000]
  --threads INT                    Threads [16]
  --bwa CMD                        bwa executable [bwa]
  --minimap2 CMD                   minimap2 executable [minimap2]
  --samtools CMD                   samtools executable [samtools]
  --python CMD                     Python executable [python3]
  --gc-depth-script CMD_OR_FILE    GC-depth analysis script [gc_depth_analysis.py]
  --bwa-option TEXT                Additional bwa mem option string; repeatable
  --minimap2-option TEXT           Additional minimap2 option string; repeatable
  --gc-depth-option TEXT           Additional GC-depth script option string; repeatable
  --keep-intermediates             Keep intermediate SAM and unsorted BAM
  -h, --help                       Show this help
USAGE
}

genome=""
outdir=""
wgs_r1=()
wgs_r2=()
hifi=()
ont=()
output_name="gc_depth"
split_index="8G"
window=1000
step=1000
threads=16
bwa_cmd="bwa"
minimap2_cmd="minimap2"
samtools_cmd="samtools"
python_cmd="python3"
gc_depth_script="gc_depth_analysis.py"
bwa_options=()
minimap2_options=()
gc_depth_options=()
keep_intermediates=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --genome) genome=${2:?"Missing value for --genome"}; shift 2 ;;
    --outdir) outdir=${2:?"Missing value for --outdir"}; shift 2 ;;
    --wgs-r1) wgs_r1+=("${2:?"Missing value for --wgs-r1"}"); shift 2 ;;
    --wgs-r2) wgs_r2+=("${2:?"Missing value for --wgs-r2"}"); shift 2 ;;
    --hifi) hifi+=("${2:?"Missing value for --hifi"}"); shift 2 ;;
    --ont|--cyclone) ont+=("${2:?"Missing value for $1"}"); shift 2 ;;
    --output-name) output_name=${2:?"Missing value for --output-name"}; shift 2 ;;
    --split-index) split_index=${2:?"Missing value for --split-index"}; shift 2 ;;
    --window) window=${2:?"Missing value for --window"}; shift 2 ;;
    --step) step=${2:?"Missing value for --step"}; shift 2 ;;
    --threads) threads=${2:?"Missing value for --threads"}; shift 2 ;;
    --bwa) bwa_cmd=${2:?"Missing value for --bwa"}; shift 2 ;;
    --minimap2) minimap2_cmd=${2:?"Missing value for --minimap2"}; shift 2 ;;
    --samtools) samtools_cmd=${2:?"Missing value for --samtools"}; shift 2 ;;
    --python) python_cmd=${2:?"Missing value for --python"}; shift 2 ;;
    --gc-depth-script) gc_depth_script=${2:?"Missing value for --gc-depth-script"}; shift 2 ;;
    --bwa-option) bwa_options+=("${2:?"Missing value for --bwa-option"}"); shift 2 ;;
    --minimap2-option) minimap2_options+=("${2:?"Missing value for --minimap2-option"}"); shift 2 ;;
    --gc-depth-option) gc_depth_options+=("${2:?"Missing value for --gc-depth-option"}"); shift 2 ;;
    --keep-intermediates) keep_intermediates=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ -z "$genome" || -z "$outdir" ]]; then
  echo "Missing required --genome or --outdir" >&2
  usage >&2
  exit 1
fi
for value_name in window step threads; do
  value=${!value_name}
  if [[ ! "$value" =~ ^[0-9]+$ || "$value" -lt 1 ]]; then
    echo "--${value_name//_/-} must be a positive integer" >&2
    exit 1
  fi
done
if [[ ! -s "$genome" ]]; then
  echo "Missing or empty genome FASTA: $genome" >&2
  exit 1
fi
mode_count=0
[[ ${#wgs_r1[@]} -gt 0 || ${#wgs_r2[@]} -gt 0 ]] && mode_count=$((mode_count + 1))
[[ ${#hifi[@]} -gt 0 ]] && mode_count=$((mode_count + 1))
[[ ${#ont[@]} -gt 0 ]] && mode_count=$((mode_count + 1))
if [[ "$mode_count" -ne 1 ]]; then
  echo "Choose exactly one read mode: WGS paired reads, HiFi reads, or ONT/Cyclone reads" >&2
  exit 1
fi
if [[ ${#wgs_r1[@]} -gt 0 || ${#wgs_r2[@]} -gt 0 ]]; then
  if [[ ${#wgs_r1[@]} -eq 0 || ${#wgs_r2[@]} -eq 0 || ${#wgs_r1[@]} -ne ${#wgs_r2[@]} ]]; then
    echo "The number of --wgs-r1 and --wgs-r2 files must match" >&2
    exit 1
  fi
fi
for file in "${wgs_r1[@]}" "${wgs_r2[@]}" "${hifi[@]}" "${ont[@]}"; do
  if [[ ! -s "$file" ]]; then
    echo "Missing or empty read file: $file" >&2
    exit 1
  fi
done
required_cmds=("$samtools_cmd" "$python_cmd")
if [[ ${#wgs_r1[@]} -gt 0 ]]; then
  required_cmds+=("$bwa_cmd")
else
  required_cmds+=("$minimap2_cmd")
fi
for cmd in "${required_cmds[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required executable not found: $cmd" >&2
    exit 1
  fi
done
if [[ ! -f "$gc_depth_script" ]] && ! command -v "$gc_depth_script" >/dev/null 2>&1; then
  echo "GC-depth analysis script not found: $gc_depth_script" >&2
  exit 1
fi

outdir_abs=$(mkdir -p "$outdir" && readlink -f "$outdir")
workdir="$outdir_abs/${output_name}.gc_depth_work"
mkdir -p "$workdir"
genome_abs=$(readlink -f "$genome")
work_genome="$workdir/genome.fa"
cp "$genome_abs" "$work_genome"

sam="$workdir/${output_name}.aln.sam"
unsorted_bam="$workdir/${output_name}.aln.bam"
sorted_bam="$workdir/${output_name}.aln.sorted.bam"
stable_bam="$outdir_abs/${output_name}.gc_depth.sorted.bam"
coverage_tsv="$outdir_abs/${output_name}.gc_depth.coverage.tsv"
flagstat_txt="$outdir_abs/${output_name}.gc_depth.flagstat.txt"
plot_png="$outdir_abs/${output_name}.gc_depth.png"
runtime_log="$outdir_abs/${output_name}.gc_depth_running_time.txt"
read_mode="NA"
if [[ ${#wgs_r1[@]} -gt 0 ]]; then
  read_mode="wgs"
elif [[ ${#hifi[@]} -gt 0 ]]; then
  read_mode="hifi"
else
  read_mode="ont"
fi

gc_depth_script_resolved="$gc_depth_script"
if [[ ! -f "$gc_depth_script_resolved" ]]; then
  gc_depth_script_resolved=$(command -v "$gc_depth_script")
fi

map_with_bwa() {
  "$bwa_cmd" index "$work_genome"
  local args=(mem -t "$threads")
  for option in "${bwa_options[@]}"; do
    read -r -a option_parts <<< "$option"
    args+=("${option_parts[@]}")
  done
  args+=("$work_genome")
  args+=("${wgs_r1[@]}" "${wgs_r2[@]}")
  "$bwa_cmd" "${args[@]}" > "$sam"
}

map_with_minimap2() {
  local preset=$1
  shift
  local reads=("$@")
  local args=(-ax "$preset" -I "$split_index" -t "$threads")
  for option in "${minimap2_options[@]}"; do
    read -r -a option_parts <<< "$option"
    args+=("${option_parts[@]}")
  done
  args+=("$work_genome" "${reads[@]}")
  "$minimap2_cmd" "${args[@]}" > "$sam"
}

{
  printf '[%s] Workflow started\n' "$(date)"
  start=$(date +%s)
  if [[ ${#wgs_r1[@]} -gt 0 ]]; then
    map_with_bwa
  elif [[ ${#hifi[@]} -gt 0 ]]; then
    map_with_minimap2 map-hifi "${hifi[@]}"
  else
    map_with_minimap2 map-ont "${ont[@]}"
  fi
  "$samtools_cmd" view -Sb --threads "$threads" -o "$unsorted_bam" "$sam"
  "$samtools_cmd" sort --threads "$threads" -o "$sorted_bam" "$unsorted_bam"
  "$samtools_cmd" index "$sorted_bam"
  cp "$sorted_bam" "$stable_bam"
  cp "$sorted_bam.bai" "$stable_bam.bai"
  "$samtools_cmd" depth --threads "$threads" "$sorted_bam" > "$coverage_tsv"
  "$samtools_cmd" flagstat "$sorted_bam" > "$flagstat_txt"
  gc_args=("$genome_abs" "$coverage_tsv" -w "$window" -s "$step" -o "$plot_png")
  for option in "${gc_depth_options[@]}"; do
    read -r -a option_parts <<< "$option"
    gc_args+=("${option_parts[@]}")
  done
  "$python_cmd" "$gc_depth_script_resolved" "${gc_args[@]}"
  if [[ "$keep_intermediates" -eq 0 ]]; then
    rm -f "$sam" "$unsorted_bam"
  fi
  duration=$(( $(date +%s) - start ))
  awk -v s="$duration" 'BEGIN {printf "[%s] Duration: %.4f hours\n", strftime("%Y-%m-%d %H:%M:%S"), s/3600}'
} | tee -a "$runtime_log"

cat > "$outdir_abs/${output_name}.gc_depth_manifest.tsv" <<MANIFEST
field	value
output_name	$output_name
genome	$genome_abs
read_mode	${read_mode:-NA}
threads	$threads
split_index	$split_index
window	$window
step	$step
workdir	$workdir
bam	$stable_bam
coverage_tsv	$coverage_tsv
flagstat	$flagstat_txt
plot	$plot_png
runtime_log	$runtime_log
gc_depth_script	$gc_depth_script_resolved
MANIFEST
