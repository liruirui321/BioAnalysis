#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: work.sh --genome genome.fa --harvest genome.fa.harvest.scn --finder genome.fa.finder.combine.scn [--threads 12] [--raw-ltr genome.fa.rawLTR.scn] [--run-lai]

Merge LTRharvest and LTR_FINDER_parallel candidate files, then run LTR_retriever.
The script name is retained for compatibility with older SOPs; functionally it is an
LTR_retriever wrapper.

Required:
  --genome FILE       Genome FASTA
  --harvest FILE      LTRharvest SCN file
  --finder FILE       LTR_FINDER_parallel combined SCN file

Options:
  --threads INT       Number of threads for LTR_retriever [12]
  --raw-ltr FILE      Merged candidate SCN output [<genome>.rawLTR.scn]
  --run-lai           Run LAI after LTR_retriever if LAI is available on PATH
  -h, --help          Show this help
USAGE
}

genome=""
harvest=""
finder=""
threads=12
raw_ltr=""
run_lai=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --genome)
      genome=${2:?"Missing value for --genome"}
      shift 2
      ;;
    --harvest)
      harvest=${2:?"Missing value for --harvest"}
      shift 2
      ;;
    --finder)
      finder=${2:?"Missing value for --finder"}
      shift 2
      ;;
    --threads)
      threads=${2:?"Missing value for --threads"}
      shift 2
      ;;
    --raw-ltr)
      raw_ltr=${2:?"Missing value for --raw-ltr"}
      shift 2
      ;;
    --run-lai)
      run_lai=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

for name in genome harvest finder; do
  value=${!name}
  if [[ -z "$value" ]]; then
    echo "Missing required --$name" >&2
    usage >&2
    exit 1
  fi
  if [[ ! -s "$value" ]]; then
    echo "Input file is missing or empty: $value" >&2
    exit 1
  fi
done
if ! command -v LTR_retriever >/dev/null 2>&1; then
  echo "LTR_retriever not found on PATH" >&2
  exit 1
fi

raw_ltr=${raw_ltr:-${genome}.rawLTR.scn}
cat "$harvest" "$finder" > "$raw_ltr"

LTR_retriever \
  -genome "$genome" \
  -inharvest "$raw_ltr" \
  -threads "$threads"

if [[ "$run_lai" -eq 1 ]]; then
  if ! command -v LAI >/dev/null 2>&1; then
    echo "--run-lai requested but LAI is not found on PATH" >&2
    exit 1
  fi
  LAI \
    -genome "$genome" \
    -intact "${genome}.pass.list" \
    -all "${genome}.out"
fi
