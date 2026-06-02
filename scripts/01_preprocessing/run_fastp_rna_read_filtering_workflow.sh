#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run_fastp_rna_read_filtering_workflow.sh --sample sample --r1 RNA_R1.fq.gz --outdir rna_fastp [options]

Run an independent Stage 01 fastp RNA-seq raw-read filtering workflow:
  1. Optionally run FastQC before filtering.
  2. Run fastp on single-end or paired-end RNA-seq reads.
  3. Optionally run FastQC after filtering.

Required:
  --sample NAME                    Sample name
  --r1 FILE                        Read 1 FASTQ
  --outdir DIR                     Output directory

Options:
  --r2 FILE                        Read 2 FASTQ; enables paired-end mode
  --qualified-quality-phred INT    fastp -q [15]
  --unqualified-percent-limit INT  fastp -u [40]
  --average-qual INT               fastp -e [20]
  --length-required INT            fastp -l [50]
  --adapter-fasta FILE             Adapter FASTA for --adapter_fasta
  --detect-adapter-for-pe          Enable --detect_adapter_for_pe in PE mode
  --merge                          Enable read merging and merged output
  --dedup                          Enable duplicate removal
  --trim-poly-g                    Enable polyG trimming
  --trim-poly-x                    Enable polyX trimming
  --low-complexity-filter          Enable low-complexity filtering
  --complexity-threshold INT       fastp --complexity_threshold
  --correction                     Enable overlap correction
  --umi                            Enable UMI handling
  --umi-loc TEXT                   fastp --umi_loc
  --umi-len INT                    fastp --umi_len
  --umi-prefix TEXT                fastp --umi_prefix
  --overrepresentation-analysis    Enable overrepresentation analysis
  --threads INT                    Threads [10]
  --compression-level INT          Compression level [9]
  --fastp CMD                      fastp executable [fastp]
  --fastqc CMD                     FastQC executable [fastqc]
  --java CMD                       Java executable passed to FastQC with -j
  --fastp-option TEXT              Additional fastp option string; repeatable
  --fastqc-option TEXT             Additional FastQC option string; repeatable
  --skip-fastqc                    Skip before/after FastQC
  -h, --help                       Show this help
USAGE
}

sample=""
r1=""
r2=""
outdir=""
qualified_quality_phred=15
unqualified_percent_limit=40
average_qual=20
length_required=50
adapter_fasta=""
detect_adapter_for_pe=0
merge=0
dedup=0
trim_poly_g=0
trim_poly_x=0
low_complexity_filter=0
complexity_threshold=""
correction=0
umi=0
umi_loc=""
umi_len=""
umi_prefix=""
overrepresentation_analysis=0
threads=10
compression_level=9
fastp_cmd="fastp"
fastqc_cmd="fastqc"
java_cmd=""
fastp_options=()
fastqc_options=()
skip_fastqc=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sample) sample=${2:?"Missing value for --sample"}; shift 2 ;;
    --r1) r1=${2:?"Missing value for --r1"}; shift 2 ;;
    --r2) r2=${2:?"Missing value for --r2"}; shift 2 ;;
    --outdir) outdir=${2:?"Missing value for --outdir"}; shift 2 ;;
    --qualified-quality-phred) qualified_quality_phred=${2:?"Missing value for --qualified-quality-phred"}; shift 2 ;;
    --unqualified-percent-limit) unqualified_percent_limit=${2:?"Missing value for --unqualified-percent-limit"}; shift 2 ;;
    --average-qual) average_qual=${2:?"Missing value for --average-qual"}; shift 2 ;;
    --length-required) length_required=${2:?"Missing value for --length-required"}; shift 2 ;;
    --adapter-fasta) adapter_fasta=${2:?"Missing value for --adapter-fasta"}; shift 2 ;;
    --detect-adapter-for-pe) detect_adapter_for_pe=1; shift ;;
    --merge) merge=1; shift ;;
    --dedup) dedup=1; shift ;;
    --trim-poly-g) trim_poly_g=1; shift ;;
    --trim-poly-x) trim_poly_x=1; shift ;;
    --low-complexity-filter) low_complexity_filter=1; shift ;;
    --complexity-threshold) complexity_threshold=${2:?"Missing value for --complexity-threshold"}; shift 2 ;;
    --correction) correction=1; shift ;;
    --umi) umi=1; shift ;;
    --umi-loc) umi_loc=${2:?"Missing value for --umi-loc"}; shift 2 ;;
    --umi-len) umi_len=${2:?"Missing value for --umi-len"}; shift 2 ;;
    --umi-prefix) umi_prefix=${2:?"Missing value for --umi-prefix"}; shift 2 ;;
    --overrepresentation-analysis) overrepresentation_analysis=1; shift ;;
    --threads) threads=${2:?"Missing value for --threads"}; shift 2 ;;
    --compression-level) compression_level=${2:?"Missing value for --compression-level"}; shift 2 ;;
    --fastp) fastp_cmd=${2:?"Missing value for --fastp"}; shift 2 ;;
    --fastqc) fastqc_cmd=${2:?"Missing value for --fastqc"}; shift 2 ;;
    --java) java_cmd=${2:?"Missing value for --java"}; shift 2 ;;
    --fastp-option) fastp_options+=("${2:?"Missing value for --fastp-option"}"); shift 2 ;;
    --fastqc-option) fastqc_options+=("${2:?"Missing value for --fastqc-option"}"); shift 2 ;;
    --skip-fastqc) skip_fastqc=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ -z "$sample" || -z "$r1" || -z "$outdir" ]]; then
  echo "Missing required --sample, --r1, or --outdir" >&2
  usage >&2
  exit 1
fi
for value_name in qualified_quality_phred unqualified_percent_limit average_qual length_required threads compression_level; do
  value=${!value_name}
  if [[ ! "$value" =~ ^[0-9]+$ || "$value" -lt 1 ]]; then
    echo "--${value_name//_/-} must be a positive integer" >&2
    exit 1
  fi
done
for optional_int in complexity_threshold umi_len; do
  value=${!optional_int}
  if [[ -n "$value" && (! "$value" =~ ^[0-9]+$ || "$value" -lt 1) ]]; then
    echo "--${optional_int//_/-} must be a positive integer" >&2
    exit 1
  fi
done
if [[ ! -s "$r1" ]]; then
  echo "Missing or empty R1 file: $r1" >&2
  exit 1
fi
if [[ -n "$r2" && ! -s "$r2" ]]; then
  echo "Missing or empty R2 file: $r2" >&2
  exit 1
fi
if [[ -n "$adapter_fasta" && ! -s "$adapter_fasta" ]]; then
  echo "Missing or empty adapter FASTA: $adapter_fasta" >&2
  exit 1
fi
if ! command -v "$fastp_cmd" >/dev/null 2>&1; then
  echo "fastp executable not found: $fastp_cmd" >&2
  exit 1
fi
if [[ "$skip_fastqc" -eq 0 ]] && ! command -v "$fastqc_cmd" >/dev/null 2>&1; then
  echo "FastQC executable not found: $fastqc_cmd" >&2
  exit 1
fi
if [[ -n "$java_cmd" ]] && ! command -v "$java_cmd" >/dev/null 2>&1; then
  echo "Java executable not found: $java_cmd" >&2
  exit 1
fi

outdir_abs=$(mkdir -p "$outdir" && readlink -f "$outdir")
fastqc_dir="$outdir_abs/fastqc"
mkdir -p "$fastqc_dir"
r1_abs=$(readlink -f "$r1")
r2_abs=""
[[ -n "$r2" ]] && r2_abs=$(readlink -f "$r2")
adapter_abs=""
[[ -n "$adapter_fasta" ]] && adapter_abs=$(readlink -f "$adapter_fasta")

out_r1="$outdir_abs/${sample}.rna.clean_R1.fastq.gz"
out_r2="$outdir_abs/${sample}.rna.clean_R2.fastq.gz"
merged_out="$outdir_abs/${sample}.rna.merged.fastq.gz"
html_report="$outdir_abs/${sample}.rna.fastp.html"
json_report="$outdir_abs/${sample}.rna.fastp.json"
fastp_log="$outdir_abs/${sample}.rna.fastp.log"
runtime_log="$outdir_abs/${sample}.rna_fastp_running_time.txt"
manifest="$outdir_abs/${sample}.rna_fastp_manifest.tsv"

run_fastqc() {
  local label=$1
  shift
  local args=("$@" -t "$threads" -o "$fastqc_dir")
  [[ -n "$java_cmd" ]] && args+=(-j "$java_cmd")
  for option in "${fastqc_options[@]}"; do
    read -r -a option_parts <<< "$option"
    args+=("${option_parts[@]}")
  done
  "$fastqc_cmd" "${args[@]}" > "$outdir_abs/${sample}.rna.fastqc_${label}.log" 2>&1
}

fastp_args=(-i "$r1_abs" -o "$out_r1" -q "$qualified_quality_phred" -u "$unqualified_percent_limit" -e "$average_qual" -l "$length_required" -w "$threads" -z "$compression_level" -h "$html_report" -j "$json_report" --verbose)
if [[ -n "$r2_abs" ]]; then
  fastp_args+=(-I "$r2_abs" -O "$out_r2")
  [[ "$detect_adapter_for_pe" -eq 1 ]] && fastp_args+=(--detect_adapter_for_pe)
fi
[[ -n "$adapter_abs" ]] && fastp_args+=(--adapter_fasta "$adapter_abs")
[[ "$merge" -eq 1 ]] && fastp_args+=(--merge --merged_out "$merged_out")
[[ "$dedup" -eq 1 ]] && fastp_args+=(--dedup)
[[ "$trim_poly_g" -eq 1 ]] && fastp_args+=(--trim_poly_g)
[[ "$trim_poly_x" -eq 1 ]] && fastp_args+=(--trim_poly_x)
[[ "$low_complexity_filter" -eq 1 ]] && fastp_args+=(--low_complexity_filter)
[[ -n "$complexity_threshold" ]] && fastp_args+=(--complexity_threshold "$complexity_threshold")
[[ "$correction" -eq 1 ]] && fastp_args+=(--correction)
if [[ "$umi" -eq 1 ]]; then
  fastp_args+=(--umi)
  [[ -n "$umi_loc" ]] && fastp_args+=(--umi_loc "$umi_loc")
  [[ -n "$umi_len" ]] && fastp_args+=(--umi_len "$umi_len")
  [[ -n "$umi_prefix" ]] && fastp_args+=(--umi_prefix "$umi_prefix")
fi
[[ "$overrepresentation_analysis" -eq 1 ]] && fastp_args+=(--overrepresentation_analysis)
for option in "${fastp_options[@]}"; do
  read -r -a option_parts <<< "$option"
  fastp_args+=("${option_parts[@]}")
done

{
  printf '[%s] Workflow started\n' "$(date)"
  start=$(date +%s)
  if [[ "$skip_fastqc" -eq 0 ]]; then
    if [[ -n "$r2_abs" ]]; then
      run_fastqc before "$r1_abs" "$r2_abs"
    else
      run_fastqc before "$r1_abs"
    fi
  fi
  "$fastp_cmd" "${fastp_args[@]}" 2> "$fastp_log"
  if [[ "$skip_fastqc" -eq 0 ]]; then
    if [[ -n "$r2_abs" ]]; then
      run_fastqc after "$out_r1" "$out_r2"
    else
      run_fastqc after "$out_r1"
    fi
  fi
  duration=$(( $(date +%s) - start ))
  awk -v s="$duration" 'BEGIN {printf "[%s] Duration: %.4f hours\n", strftime("%Y-%m-%d %H:%M:%S"), s/3600}'
} | tee -a "$runtime_log"

cat > "$manifest" <<MANIFEST
field	value
sample	$sample
mode	$([[ -n "$r2_abs" ]] && printf 'PE' || printf 'SE')
read_type	rna
r1	$r1_abs
r2	${r2_abs:-NA}
out_r1	$out_r1
out_r2	$([[ -n "$r2_abs" ]] && printf '%s' "$out_r2" || printf 'NA')
merged_out	$([[ "$merge" -eq 1 ]] && printf '%s' "$merged_out" || printf 'NA')
fastp_html	$html_report
fastp_json	$json_report
fastp_log	$fastp_log
fastqc_dir	$([[ "$skip_fastqc" -eq 0 ]] && printf '%s' "$fastqc_dir" || printf 'skipped')
runtime_log	$runtime_log
MANIFEST
