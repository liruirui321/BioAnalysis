#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: LTR_harvest.sh --genome genome.fa [--index-prefix genome.fa] [--out genome.fa.harvest.scn]

Build a GenomeTools suffixerator index and run gt ltrharvest.

Required:
  --genome FILE          Genome FASTA

Options:
  --index-prefix PREFIX  Index prefix passed to gt suffixerator [genome path]
  --out FILE             LTRharvest output SCN file [<index-prefix>.harvest.scn]
  -h, --help             Show this help
USAGE
}

genome=""
index_prefix=""
out=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --genome)
      genome=${2:?"Missing value for --genome"}
      shift 2
      ;;
    --index-prefix)
      index_prefix=${2:?"Missing value for --index-prefix"}
      shift 2
      ;;
    --out)
      out=${2:?"Missing value for --out"}
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
if ! command -v gt >/dev/null 2>&1; then
  echo "GenomeTools command 'gt' not found on PATH" >&2
  exit 1
fi

index_prefix=${index_prefix:-$genome}
out=${out:-${index_prefix}.harvest.scn}

gt suffixerator \
  -db "$genome" \
  -indexname "$index_prefix" \
  -tis -suf -lcp -des -ssp -sds -dna

gt ltrharvest \
  -index "$index_prefix" \
  -minlenltr 100 \
  -maxlenltr 7000 \
  -mintsd 4 \
  -maxtsd 6 \
  -motif TGCA \
  -motifmis 1 \
  -similar 85 \
  -vic 10 \
  -seed 20 \
  -seqids yes \
  > "$out"
