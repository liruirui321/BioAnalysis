#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: LTR_Finder.sh --genome genome.fa [--threads 30] [--size 1000000] [--time 300]

Run LTR_FINDER_parallel on a genome FASTA. The expected LTR_FINDER_parallel
output follows the tool default, typically: <genome>.finder.combine.scn

Required:
  --genome FILE      Genome FASTA

Options:
  --threads INT      Number of threads [30]
  --size INT         Split size passed to LTR_FINDER_parallel [1000000]
  --time INT         Time limit passed to LTR_FINDER_parallel [300]
  -h, --help         Show this help
USAGE
}

genome=""
threads=30
size=1000000
time_limit=300

while [[ $# -gt 0 ]]; do
  case "$1" in
    --genome)
      genome=${2:?"Missing value for --genome"}
      shift 2
      ;;
    --threads)
      threads=${2:?"Missing value for --threads"}
      shift 2
      ;;
    --size)
      size=${2:?"Missing value for --size"}
      shift 2
      ;;
    --time)
      time_limit=${2:?"Missing value for --time"}
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ -z "$genome" && -f "$1" ]]; then
        genome=$1
        shift
      else
        echo "Unknown argument: $1" >&2
        usage >&2
        exit 1
      fi
      ;;
  esac
done

if [[ -z "$genome" ]]; then
  echo "Missing required --genome" >&2
  usage >&2
  exit 1
fi
if [[ ! -s "$genome" ]]; then
  echo "Genome FASTA is missing or empty: $genome" >&2
  exit 1
fi
if ! command -v LTR_FINDER_parallel >/dev/null 2>&1; then
  echo "LTR_FINDER_parallel not found on PATH" >&2
  exit 1
fi

LTR_FINDER_parallel \
  -seq "$genome" \
  -threads "$threads" \
  -harvest_out \
  -size "$size" \
  -time "$time_limit"
