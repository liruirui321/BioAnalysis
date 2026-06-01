#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: repeatmodeler.sh --genome genome.fa [--database mydb] [--threads 20] [--log repeatmodeler.log] [--out run.out]

Build a RepeatModeler database and run RepeatModeler using tools available on PATH.

Required:
  --genome FILE       Genome FASTA

Options:
  --database NAME     RepeatModeler database name [mydb]
  --threads INT       Number of RepeatModeler threads [20]
  --log FILE          BuildDatabase log [repeatmodeler.log]
  --out FILE          RepeatModeler stdout log [run.out]
  -h, --help          Show this help
USAGE
}

genome=""
database="mydb"
threads=20
log="repeatmodeler.log"
out="run.out"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --genome)
      genome=${2:?"Missing value for --genome"}
      shift 2
      ;;
    --database)
      database=${2:?"Missing value for --database"}
      shift 2
      ;;
    --threads)
      threads=${2:?"Missing value for --threads"}
      shift 2
      ;;
    --log)
      log=${2:?"Missing value for --log"}
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
for tool in BuildDatabase RepeatModeler; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "$tool not found on PATH" >&2
    exit 1
  fi
done

BuildDatabase -name "$database" "$genome" > "$log"
RepeatModeler -database "$database" -threads "$threads" > "$out"
