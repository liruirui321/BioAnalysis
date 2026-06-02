#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run_nextdenovo_assembly.sh --read reads.fa --genome-size 200m --outdir nextdenovo_assembly [options]

Run an independent Stage 02 NextDenovo assembly workflow:
  1. Write a clean input.fofn and run.cfg.
  2. Run nextDenovo run.cfg.
  3. Expose nd.asm.fasta as a stable assembly FASTA.
  4. Write stable assembly statistics.

Required:
  --genome-size SIZE           Estimated genome size, for example 200m
  --outdir DIR                 Output directory
  and either:
  --read FILE                  Long-read FASTA/FASTQ; repeatable
  or:
  --input-fofn FILE            Existing FOFN of read files

Options:
  --prefix NAME                Output prefix [nextdenovo]
  --read-type clr|ont|hifi     Read type [ont]
  --job-type local|sge|pbs     NextDenovo job_type [local]
  --parallel-jobs INT          NextDenovo parallel_jobs [4]
  --rewrite yes|no             NextDenovo rewrite setting [yes]
  --rerun INT                  NextDenovo rerun setting [3]
  --read-cutoff VALUE          NextDenovo read_cutoff [1k]
  --sort-memory VALUE          ovl_sort memory [20G]
  --sort-threads INT           ovl_sort threads [8]
  --minimap-threads INT        minimap2-nd threads [8]
  --split-memory VALUE         split memory [20G]
  --split-threads INT          split threads [8]
  --pa-correction INT          pa_correction [3]
  --nextgraph-options TEXT     nextgraph_options [-a 1]
  --nextdenovo CMD             nextDenovo executable [nextDenovo]
  --python CMD                 Python executable [python3]
  --config-option SECTION.KEY=VALUE  Additional run.cfg override; repeatable
  --skip-assembly-stats        Skip assembly_stats.py handoff
  -h, --help                   Show this help
USAGE
}

reads=()
input_fofn=""
genome_size=""
outdir=""
prefix="nextdenovo"
read_type="ont"
job_type="local"
parallel_jobs=4
rewrite="yes"
rerun=3
read_cutoff="1k"
sort_memory="20G"
sort_threads=8
minimap_threads=8
split_memory="20G"
split_threads=8
pa_correction=3
nextgraph_options="-a 1"
nextdenovo_cmd="nextDenovo"
python_cmd="python3"
skip_assembly_stats=0
config_options=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --read) reads+=("${2:?"Missing value for --read"}"); shift 2 ;;
    --input-fofn) input_fofn=${2:?"Missing value for --input-fofn"}; shift 2 ;;
    --genome-size) genome_size=${2:?"Missing value for --genome-size"}; shift 2 ;;
    --outdir) outdir=${2:?"Missing value for --outdir"}; shift 2 ;;
    --prefix) prefix=${2:?"Missing value for --prefix"}; shift 2 ;;
    --read-type) read_type=${2:?"Missing value for --read-type"}; shift 2 ;;
    --job-type) job_type=${2:?"Missing value for --job-type"}; shift 2 ;;
    --parallel-jobs) parallel_jobs=${2:?"Missing value for --parallel-jobs"}; shift 2 ;;
    --rewrite) rewrite=${2:?"Missing value for --rewrite"}; shift 2 ;;
    --rerun) rerun=${2:?"Missing value for --rerun"}; shift 2 ;;
    --read-cutoff) read_cutoff=${2:?"Missing value for --read-cutoff"}; shift 2 ;;
    --sort-memory) sort_memory=${2:?"Missing value for --sort-memory"}; shift 2 ;;
    --sort-threads) sort_threads=${2:?"Missing value for --sort-threads"}; shift 2 ;;
    --minimap-threads) minimap_threads=${2:?"Missing value for --minimap-threads"}; shift 2 ;;
    --split-memory) split_memory=${2:?"Missing value for --split-memory"}; shift 2 ;;
    --split-threads) split_threads=${2:?"Missing value for --split-threads"}; shift 2 ;;
    --pa-correction) pa_correction=${2:?"Missing value for --pa-correction"}; shift 2 ;;
    --nextgraph-options) nextgraph_options=${2:?"Missing value for --nextgraph-options"}; shift 2 ;;
    --nextdenovo) nextdenovo_cmd=${2:?"Missing value for --nextdenovo"}; shift 2 ;;
    --python) python_cmd=${2:?"Missing value for --python"}; shift 2 ;;
    --config-option) config_options+=("${2:?"Missing value for --config-option"}"); shift 2 ;;
    --skip-assembly-stats) skip_assembly_stats=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ -z "$genome_size" || -z "$outdir" ]]; then
  echo "Missing required --genome-size or --outdir" >&2
  usage >&2
  exit 1
fi
if [[ ${#reads[@]} -gt 0 && -n "$input_fofn" ]]; then
  echo "Use either --read or --input-fofn, not both" >&2
  exit 1
fi
if [[ ${#reads[@]} -eq 0 && -z "$input_fofn" ]]; then
  echo "Provide --read or --input-fofn" >&2
  exit 1
fi
case "$read_type" in
  clr|ont|hifi) ;;
  *) echo "Unsupported --read-type: $read_type" >&2; exit 1 ;;
esac
case "$rewrite" in
  yes|no) ;;
  *) echo "--rewrite must be yes or no" >&2; exit 1 ;;
esac
for value_name in parallel_jobs rerun sort_threads minimap_threads split_threads pa_correction; do
  value=${!value_name}
  if [[ ! "$value" =~ ^[0-9]+$ || "$value" -lt 1 ]]; then
    echo "--${value_name//_/-} must be a positive integer" >&2
    exit 1
  fi
done
for file in "${reads[@]}" "$input_fofn"; do
  [[ -z "$file" ]] && continue
  if [[ ! -s "$file" ]]; then
    echo "Missing or empty input file: $file" >&2
    exit 1
  fi
done
if ! command -v "$nextdenovo_cmd" >/dev/null 2>&1; then
  echo "NextDenovo executable not found: $nextdenovo_cmd" >&2
  exit 1
fi

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
outdir_abs=$(mkdir -p "$outdir" && readlink -f "$outdir")
workdir="$outdir_abs/${prefix}.nextdenovo_work"
mkdir -p "$workdir"
fofn="$workdir/input.fofn"
if [[ -n "$input_fofn" ]]; then
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    if [[ ! -s "$file" ]]; then
      echo "Missing or empty read listed in FOFN: $file" >&2
      exit 1
    fi
    readlink -f "$file"
  done < "$input_fofn" > "$fofn"
else
  : > "$fofn"
  for file in "${reads[@]}"; do
    readlink -f "$file" >> "$fofn"
  done
fi

cat > "$workdir/run.cfg" <<CFG
[General]
job_type = $job_type
job_prefix = NextDenovo
task = all
rewrite = $rewrite
rerun = $rerun
parallel_jobs = $parallel_jobs
input_type = raw
read_type = $read_type
input_fofn = $fofn
workdir = $workdir

[correct_option]
read_cutoff = $read_cutoff
genome_size = $genome_size
sort_options = -m $sort_memory -t $sort_threads
minimap2_options_raw = -t $minimap_threads
pa_correction = $pa_correction
split_options = -m $split_memory -t $split_threads

[assemble_option]
minimap2_options_cns = -t $minimap_threads
nextgraph_options = $nextgraph_options
CFG

for override in "${config_options[@]}"; do
  if [[ "$override" != *.*=* ]]; then
    echo "Invalid --config-option, expected SECTION.KEY=VALUE: $override" >&2
    exit 1
  fi
  printf '# user_override	%s\n' "$override" >> "$workdir/run.cfg"
done

(
  cd "$workdir"
  "$nextdenovo_cmd" run.cfg
)

candidate_fastas=(
  "$workdir/03.ctg_graph/nd.asm.fasta"
  "$workdir/03.ctg_graph/nd.asm.fasta.gz"
  "$workdir/03.ctg_graph/nd.asm.p.fasta"
)
final_fasta=""
for candidate in "${candidate_fastas[@]}"; do
  if [[ -s "$candidate" ]]; then
    final_fasta="$candidate"
    break
  fi
done
if [[ -z "$final_fasta" ]]; then
  echo "No NextDenovo final FASTA found. Checked: ${candidate_fastas[*]}" >&2
  exit 1
fi
assembly_fa="$outdir_abs/${prefix}.nextdenovo.assembly.fa"
if [[ "$final_fasta" == *.gz ]]; then
  gzip -dc "$final_fasta" > "$assembly_fa"
else
  cp "$final_fasta" "$assembly_fa"
fi
if [[ ! -s "$assembly_fa" ]]; then
  echo "Failed to expose NextDenovo assembly FASTA" >&2
  exit 1
fi

if [[ "$skip_assembly_stats" -eq 0 ]]; then
  "$python_cmd" "$script_dir/assembly_stats.py" \
    --fasta "$assembly_fa" \
    --out "$outdir_abs/${prefix}.nextdenovo.assembly_stats.tsv" \
    --lengths "$outdir_abs/${prefix}.nextdenovo.assembly_lengths.tsv"
fi
