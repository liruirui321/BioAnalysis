#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run_lai_qc_workflow.sh --genome genome.fa --outdir lai_qc [options]

Run an independent Stage 02 LAI assessment workflow:
  1. Run GenomeTools suffixerator and LTRharvest.
  2. Run LTR_FINDER_parallel and combine LTR candidate files.
  3. Run LTR_retriever to calculate LAI.
  4. Summarize LAI outputs into a stable TSV.

Run mode requires:
  --genome FILE                 Genome FASTA
  --outdir DIR                  Output directory

Summary-only mode:
  --lai-file FILE               Existing LAI output file; repeatable
  --lai-dir DIR                 Existing LAI output directory
  --outdir DIR                  Output directory
  --skip-run                    Do not run external LAI tools

Options:
  --prefix NAME                 Output prefix [genome basename]
  --threads INT                 Threads for LTR_FINDER_parallel/LTR_retriever [20]
  --max-length INT              Maximum LTR length for LTRharvest [7000]
  --min-length INT              Minimum LTR length for LTRharvest [100]
  --min-similarity FLOAT        Minimum LTR similarity for LTRharvest [85]
  --gt CMD                      GenomeTools executable [gt]
  --ltr-finder CMD              LTR_FINDER_parallel executable [LTR_FINDER_parallel]
  --ltr-retriever CMD           LTR_retriever executable [LTR_retriever]
  --python CMD                  Python executable [python3]
  --cleanup                     Remove bulky GenomeTools/LTR_retriever intermediate files
  -h, --help                    Show this help
USAGE
}

genome=""
outdir=""
prefix=""
threads=20
max_length=7000
min_length=100
min_similarity=85
gt_cmd="gt"
ltr_finder_cmd="LTR_FINDER_parallel"
ltr_retriever_cmd="LTR_retriever"
python_cmd="python3"
cleanup=0
skip_run=0
lai_files=()
lai_dir=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --genome) genome=${2:?"Missing value for --genome"}; shift 2 ;;
    --outdir) outdir=${2:?"Missing value for --outdir"}; shift 2 ;;
    --prefix) prefix=${2:?"Missing value for --prefix"}; shift 2 ;;
    --threads) threads=${2:?"Missing value for --threads"}; shift 2 ;;
    --max-length) max_length=${2:?"Missing value for --max-length"}; shift 2 ;;
    --min-length) min_length=${2:?"Missing value for --min-length"}; shift 2 ;;
    --min-similarity) min_similarity=${2:?"Missing value for --min-similarity"}; shift 2 ;;
    --gt) gt_cmd=${2:?"Missing value for --gt"}; shift 2 ;;
    --ltr-finder) ltr_finder_cmd=${2:?"Missing value for --ltr-finder"}; shift 2 ;;
    --ltr-retriever) ltr_retriever_cmd=${2:?"Missing value for --ltr-retriever"}; shift 2 ;;
    --python) python_cmd=${2:?"Missing value for --python"}; shift 2 ;;
    --lai-file) lai_files+=("${2:?"Missing value for --lai-file"}"); shift 2 ;;
    --lai-dir) lai_dir=${2:?"Missing value for --lai-dir"}; shift 2 ;;
    --skip-run) skip_run=1; shift ;;
    --cleanup) cleanup=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ -z "$outdir" ]]; then
  echo "Missing required --outdir" >&2
  usage >&2
  exit 1
fi
if [[ -z "$prefix" ]]; then
  if [[ -n "$genome" ]]; then
    prefix=$(basename "$genome")
    prefix=${prefix%.fasta}
    prefix=${prefix%.fa}
    prefix=${prefix%.fna}
  else
    prefix="genome"
  fi
fi
for file in "${lai_files[@]}"; do
  if [[ ! -s "$file" ]]; then
    echo "Missing or empty LAI file: $file" >&2
    exit 1
  fi
done
if [[ -n "$lai_dir" && ! -d "$lai_dir" ]]; then
  echo "Missing LAI directory: $lai_dir" >&2
  exit 1
fi
if [[ "$skip_run" -eq 0 ]]; then
  if [[ -z "$genome" ]]; then
    echo "Run mode requires --genome" >&2
    usage >&2
    exit 1
  fi
  if [[ ! -s "$genome" ]]; then
    echo "Missing or empty genome FASTA: $genome" >&2
    exit 1
  fi
  for cmd in "$gt_cmd" "$ltr_finder_cmd" "$ltr_retriever_cmd"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "Required executable not found: $cmd" >&2
      exit 1
    fi
  done
fi

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
outdir_abs=$(mkdir -p "$outdir" && readlink -f "$outdir")
workdir="$outdir_abs/${prefix}.lai_work"

if [[ "$skip_run" -eq 0 ]]; then
  mkdir -p "$workdir"
  genome_abs=$(readlink -f "$genome")
  genome_name=$(basename "$genome_abs")
  (
    cd "$workdir"
    "$gt_cmd" suffixerator -db "$genome_abs" -indexname "$genome_name" -tis -suf -lcp -des -ssp -sds -dna
    "$gt_cmd" ltrharvest \
      -index "$genome_name" \
      -minlenltr "$min_length" \
      -maxlenltr "$max_length" \
      -mintsd 4 \
      -maxtsd 6 \
      -motif TGCA \
      -motifmis 1 \
      -similar "$min_similarity" \
      -vic 10 \
      -seed 20 \
      -seqids yes > "$genome_name.harvest.scn"
    "$ltr_finder_cmd" -seq "$genome_abs" -threads "$threads" -harvest_out -size 1000000 -time 300
    finder_file="$genome_name.finder.combine.scn"
    if [[ ! -s "$finder_file" ]]; then
      finder_file=$(find . -maxdepth 1 -type f -name '*.finder.combine.scn' -print -quit)
    fi
    if [[ -n "$finder_file" && -s "$finder_file" ]]; then
      cat "$genome_name.harvest.scn" "$finder_file" > "$genome_name.rawLTR.scn"
    else
      cp "$genome_name.harvest.scn" "$genome_name.rawLTR.scn"
    fi
    "$ltr_retriever_cmd" -genome "$genome_abs" -inharvest "$genome_name.rawLTR.scn" -threads "$threads"
  )
  lai_dir="$workdir"
fi

summary_args=(--sample "$prefix" --out "$outdir_abs/${prefix}.lai_summary.tsv")
for file in "${lai_files[@]}"; do
  summary_args+=(--lai-file "$file")
done
[[ -n "$lai_dir" ]] && summary_args+=(--lai-dir "$lai_dir")
"$python_cmd" "$script_dir/summarize_lai_results.py" "${summary_args[@]}"

if [[ "$cleanup" -eq 1 && "$skip_run" -eq 0 ]]; then
  find "$workdir" -maxdepth 1 -type f \
    \( -name '*.sds' -o -name '*.prj' -o -name '*.esq' -o -name '*.llv' -o -name '*.suf' -o -name '*.ssp' -o -name '*.lcp' -o -name '*.md5' -o -name '*.des' -o -name '*.defalse' -o -name '*.masked' -o -name '*.homo' -o -name '*LAI.LTR.ava.out' \) \
    -delete
fi
