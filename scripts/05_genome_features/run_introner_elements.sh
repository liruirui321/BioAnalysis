#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run_introner_elements.sh --gff annotation.gff3 --directory-list directory_list.tsv --tool-dir Introner-elements-main [--python python3]

Run the external Introner-elements workflow using local tool paths supplied by the user.
This wrapper intentionally stores no site-specific paths or real species names.

Required:
  --gff FILE             Genome annotation GFF/GFF3
  --directory-list FILE  Introner-elements directory_list.tsv
  --tool-dir DIR         Directory containing FIND_CLUSTERS_ALLEUKS2.pl, GetCoordinates.pl, blastBack.py, outsideGenes.py, removeDuplicates.py

Options:
  --python CMD           Python interpreter [python3]
  --skip-cluster         Skip candidate cluster discovery
  --skip-coordinates     Skip coordinate extraction from *.Pass files
  -h, --help             Show this help

Workflow:
  1. FIND_CLUSTERS_ALLEUKS2.pl identifies candidate introner elements from GFF.
  2. GetCoordinates.pl extracts coordinates from *.Pass outputs.
  3. blastBack.py checks sequence similarity back to the genome/project directories.
  4. outsideGenes.py screens candidates relative to nearby genes.
  5. removeDuplicates.py removes duplicate candidate calls.
USAGE
}

gff=""
directory_list=""
tool_dir=""
python_cmd="python3"
skip_cluster=0
skip_coordinates=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --gff)
      gff=${2:?"Missing value for --gff"}
      shift 2
      ;;
    --directory-list)
      directory_list=${2:?"Missing value for --directory-list"}
      shift 2
      ;;
    --tool-dir)
      tool_dir=${2:?"Missing value for --tool-dir"}
      shift 2
      ;;
    --python)
      python_cmd=${2:?"Missing value for --python"}
      shift 2
      ;;
    --skip-cluster)
      skip_cluster=1
      shift
      ;;
    --skip-coordinates)
      skip_coordinates=1
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

for value_name in gff directory_list tool_dir; do
  value=${!value_name}
  if [[ -z "$value" ]]; then
    echo "Missing required --${value_name//_/-}" >&2
    usage >&2
    exit 1
  fi
done
if [[ ! -s "$gff" ]]; then
  echo "Missing or empty GFF: $gff" >&2
  exit 1
fi
if [[ ! -s "$directory_list" ]]; then
  echo "Missing or empty directory list: $directory_list" >&2
  exit 1
fi
if [[ ! -d "$tool_dir" ]]; then
  echo "Missing Introner-elements tool directory: $tool_dir" >&2
  exit 1
fi

find_clusters="$tool_dir/FIND_CLUSTERS_ALLEUKS2.pl"
get_coordinates="$tool_dir/GetCoordinates.pl"
blast_back="$tool_dir/blastBack.py"
outside_genes="$tool_dir/outsideGenes.py"
remove_duplicates="$tool_dir/removeDuplicates.py"

for tool in "$blast_back" "$outside_genes" "$remove_duplicates"; do
  if [[ ! -s "$tool" ]]; then
    echo "Missing Introner-elements script: $tool" >&2
    exit 1
  fi
done

if [[ "$skip_cluster" -eq 0 ]]; then
  if [[ ! -s "$find_clusters" ]]; then
    echo "Missing Introner-elements script: $find_clusters" >&2
    exit 1
  fi
  perl "$find_clusters" "$gff"
fi

if [[ "$skip_coordinates" -eq 0 ]]; then
  if [[ ! -s "$get_coordinates" ]]; then
    echo "Missing Introner-elements script: $get_coordinates" >&2
    exit 1
  fi
  perl "$get_coordinates" ./*.Pass
fi

"$python_cmd" "$blast_back" "$directory_list"
"$python_cmd" "$outside_genes" "$directory_list"
"$python_cmd" "$remove_duplicates" "$directory_list"
