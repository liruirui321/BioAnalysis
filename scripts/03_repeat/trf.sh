#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: trf.sh --genome genome.fa [--out-prefix trf] [--trf-args "2 5 7 80 10 50 2000"] [--gff trf.gff3]

Run Tandem Repeats Finder and optionally convert the .dat output to GFF3 using trf2gff.

Required:
  --genome FILE       Genome FASTA

Options:
  --out-prefix NAME   Prefix for converted GFF output [trf]
  --trf-args STRING   TRF parameter string [2 5 7 80 10 50 2000]
  --gff FILE          GFF3 output from trf2gff [<out-prefix>.gff3]
  --skip-gff          Do not run trf2gff conversion
  -h, --help          Show this help
USAGE
}

genome=""
out_prefix="trf"
trf_args="2 5 7 80 10 50 2000"
gff=""
skip_gff=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --genome)
      genome=${2:?"Missing value for --genome"}
      shift 2
      ;;
    --out-prefix)
      out_prefix=${2:?"Missing value for --out-prefix"}
      shift 2
      ;;
    --trf-args)
      trf_args=${2:?"Missing value for --trf-args"}
      shift 2
      ;;
    --gff)
      gff=${2:?"Missing value for --gff"}
      shift 2
      ;;
    --skip-gff)
      skip_gff=1
      shift
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
if ! command -v trf >/dev/null 2>&1; then
  echo "trf not found on PATH" >&2
  exit 1
fi

read -r -a trf_params <<< "$trf_args"
trf "$genome" "${trf_params[@]}" -d -h

if [[ "$skip_gff" -eq 0 ]]; then
  if ! command -v trf2gff >/dev/null 2>&1; then
    echo "trf2gff not found on PATH; rerun with --skip-gff or install trf2gff" >&2
    exit 1
  fi
  gff=${gff:-${out_prefix}.gff3}
  dat="${genome}.${trf_args// /.}.dat"
  if [[ ! -s "$dat" ]]; then
    echo "Expected TRF .dat output not found: $dat" >&2
    exit 1
  fi
  trf2gff -o - < "$dat" > "$gff"
fi
