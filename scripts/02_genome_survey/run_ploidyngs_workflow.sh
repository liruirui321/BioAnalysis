#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run_ploidyngs_workflow.sh --bam sorted.bam --outdir ploidy_ngs [options]

Run an independent Stage 02 ploidyNGS WGS/BAM ploidy estimation workflow:
  1. Copy or link a coordinate-sorted BAM into a ploidyNGS work directory.
  2. Run ploidyNGS.py with optional --guess_ploidy and user-supplied options.
  3. Generate a histogram PDF with ploidyNGS_generateHistogram.R when available.
  4. Record runtime and stable output handoff paths.

Required:
  --bam FILE                   Coordinate-sorted BAM file
  --outdir DIR                 Output directory

Options:
  --prefix NAME                Output prefix [ploidyNGS]
  --ploidyngs CMD              ploidyNGS.py executable [ploidyNGS.py]
  --histogram-r FILE           ploidyNGS_generateHistogram.R path or command [ploidyNGS_generateHistogram.R]
  --rscript CMD                Rscript executable [Rscript]
  --guess-ploidy               Pass --guess_ploidy to ploidyNGS.py
  --option TEXT                Additional ploidyNGS option string; repeatable
  --histogram-tab FILE         Histogram table to plot after ploidyNGS [ploidyNGS_MaxDepth100_MinCov0.tab]
  --copy-bam                   Copy BAM into workdir instead of symlinking
  --keep-work-bam              Keep workdir sorted.bam after run
  --skip-histogram             Skip R histogram PDF generation
  -h, --help                   Show this help
USAGE
}

bam=""
outdir=""
prefix="ploidyNGS"
ploidyngs_cmd="ploidyNGS.py"
histogram_r="ploidyNGS_generateHistogram.R"
rscript_cmd="Rscript"
guess_ploidy=0
copy_bam=0
keep_work_bam=0
skip_histogram=0
histogram_tab="ploidyNGS_MaxDepth100_MinCov0.tab"
options=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bam) bam=${2:?"Missing value for --bam"}; shift 2 ;;
    --outdir) outdir=${2:?"Missing value for --outdir"}; shift 2 ;;
    --prefix) prefix=${2:?"Missing value for --prefix"}; shift 2 ;;
    --ploidyngs) ploidyngs_cmd=${2:?"Missing value for --ploidyngs"}; shift 2 ;;
    --histogram-r) histogram_r=${2:?"Missing value for --histogram-r"}; shift 2 ;;
    --rscript) rscript_cmd=${2:?"Missing value for --rscript"}; shift 2 ;;
    --guess-ploidy) guess_ploidy=1; shift ;;
    --option) options+=("${2:?"Missing value for --option"}"); shift 2 ;;
    --histogram-tab) histogram_tab=${2:?"Missing value for --histogram-tab"}; shift 2 ;;
    --copy-bam) copy_bam=1; shift ;;
    --keep-work-bam) keep_work_bam=1; shift ;;
    --skip-histogram) skip_histogram=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ -z "$bam" || -z "$outdir" ]]; then
  echo "Missing required --bam or --outdir" >&2
  usage >&2
  exit 1
fi
if [[ ! -s "$bam" ]]; then
  echo "Missing or empty BAM file: $bam" >&2
  exit 1
fi
if ! command -v "$ploidyngs_cmd" >/dev/null 2>&1; then
  echo "Required executable not found: $ploidyngs_cmd" >&2
  exit 1
fi
if [[ "$skip_histogram" -eq 0 ]]; then
  if ! command -v "$rscript_cmd" >/dev/null 2>&1; then
    echo "Required executable not found: $rscript_cmd" >&2
    exit 1
  fi
  if [[ ! -f "$histogram_r" ]] && ! command -v "$histogram_r" >/dev/null 2>&1; then
    echo "Histogram R script not found: $histogram_r" >&2
    exit 1
  fi
fi

outdir_abs=$(mkdir -p "$outdir" && readlink -f "$outdir")
workdir="$outdir_abs/${prefix}.ploidyNGS_work"
mkdir -p "$workdir"
bam_abs=$(readlink -f "$bam")
work_bam="$workdir/sorted.bam"

if [[ "$copy_bam" -eq 1 ]]; then
  cp "$bam_abs" "$work_bam"
else
  ln -sf "$bam_abs" "$work_bam"
fi

work_script="$workdir/work.sh"
runtime_log="$outdir_abs/${prefix}.ploidyNGS_running_time.txt"
manifest="$outdir_abs/${prefix}.ploidyNGS_manifest.tsv"

ploidy_args=("$ploidyngs_cmd")
[[ "$guess_ploidy" -eq 1 ]] && ploidy_args+=(--guess_ploidy)
ploidy_args+=(-b "$work_bam" -o "$prefix")
for option in "${options[@]}"; do
  read -r -a option_parts <<< "$option"
  ploidy_args+=("${option_parts[@]}")
done

{
  printf '#!/usr/bin/env bash\n'
  printf 'set -euo pipefail\n'
  printf 'cd %q\n' "$workdir"
  printf '%q' "${ploidy_args[0]}"
  for arg in "${ploidy_args[@]:1}"; do
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

histogram_pdf="$outdir_abs/${prefix}.ploidyNGS.pdf"
histogram_source="$workdir/$histogram_tab"
histogram_handoff="$outdir_abs/${prefix}.$(basename "$histogram_tab")"
if [[ -s "$histogram_source" ]]; then
  cp "$histogram_source" "$histogram_handoff"
fi
if [[ "$skip_histogram" -eq 0 ]]; then
  if [[ ! -s "$histogram_source" ]]; then
    echo "Expected ploidyNGS histogram table not found: $histogram_source" >&2
    exit 1
  fi
  histogram_r_resolved="$histogram_r"
  if [[ ! -f "$histogram_r_resolved" ]]; then
    histogram_r_resolved=$(command -v "$histogram_r")
  fi
  "$rscript_cmd" --vanilla "$histogram_r_resolved" "$histogram_source" "$histogram_pdf"
fi

if [[ "$keep_work_bam" -eq 0 ]]; then
  rm -f "$work_bam"
fi

cat > "$manifest" <<MANIFEST
field	value
prefix	$prefix
bam	$bam_abs
workdir	$workdir
work_script	$work_script
guess_ploidy	$guess_ploidy
histogram_table	$histogram_handoff
histogram_work_table	$histogram_source
histogram_pdf	$histogram_pdf
runtime_log	$runtime_log
MANIFEST
