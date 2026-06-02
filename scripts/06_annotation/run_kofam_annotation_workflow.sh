#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run_kofam_annotation_workflow.sh --protein proteins.fa --outdir kofam_annotation [options]

Run an independent Stage 06 KofamScan/KEGG annotation workflow:
  1. Run KofamScan exec_annotation on a protein FASTA.
  2. Parse detail-format output with the maintained BioAnalysis parser.
  3. Write a legacy KO aggregation compatible with historical KEGG handoffs.

Required:
  --protein FILE                  Protein FASTA
  --outdir DIR                    Output directory

Options:
  --prefix NAME                   Output prefix [protein FASTA basename]
  --exec-annotation CMD           KofamScan exec_annotation executable [exec_annotation]
  --python CMD                    Python executable [python3]
  --format FORMAT                 KofamScan output format [detail]
  --evalue FLOAT                  E-value cutoff for legacy KO aggregation [1e-5]
  --exec-option TEXT              Additional exec_annotation option string; repeatable
  --keep-all                      Keep all parsed Kofam rows, not only passed entries
  -h, --help                      Show this help
USAGE
}

protein=""
outdir=""
prefix=""
exec_annotation_cmd="exec_annotation"
python_cmd="python3"
format="detail"
evalue="1e-5"
exec_options=()
keep_all=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --protein) protein=${2:?"Missing value for --protein"}; shift 2 ;;
    --outdir) outdir=${2:?"Missing value for --outdir"}; shift 2 ;;
    --prefix) prefix=${2:?"Missing value for --prefix"}; shift 2 ;;
    --exec-annotation) exec_annotation_cmd=${2:?"Missing value for --exec-annotation"}; shift 2 ;;
    --python) python_cmd=${2:?"Missing value for --python"}; shift 2 ;;
    --format) format=${2:?"Missing value for --format"}; shift 2 ;;
    --evalue) evalue=${2:?"Missing value for --evalue"}; shift 2 ;;
    --exec-option) exec_options+=("${2:?"Missing value for --exec-option"}"); shift 2 ;;
    --keep-all) keep_all=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ -z "$protein" || -z "$outdir" ]]; then
  echo "Missing required --protein or --outdir" >&2
  usage >&2
  exit 1
fi
if [[ ! -s "$protein" ]]; then
  echo "Missing or empty protein FASTA: $protein" >&2
  exit 1
fi
if ! command -v "$exec_annotation_cmd" >/dev/null 2>&1; then
  echo "exec_annotation executable not found: $exec_annotation_cmd" >&2
  exit 1
fi
if ! command -v "$python_cmd" >/dev/null 2>&1; then
  echo "Python executable not found: $python_cmd" >&2
  exit 1
fi
if ! "$python_cmd" - "$evalue" <<'PY' >/dev/null 2>&1
import sys
float(sys.argv[1])
PY
then
  echo "--evalue must be numeric" >&2
  exit 1
fi

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
outdir_abs=$(mkdir -p "$outdir" && readlink -f "$outdir")
protein_abs=$(readlink -f "$protein")
prefix=${prefix:-$(basename "$protein")}
prefix=${prefix%.fa}
prefix=${prefix%.faa}
prefix=${prefix%.fasta}
prefix=${prefix%.pep}

detail_out="$outdir_abs/${prefix}.kofam.detail.txt"
parsed_out="$outdir_abs/${prefix}.kofam.tsv"
legacy_ko="$outdir_abs/${prefix}.pep.ko"
runtime_log="$outdir_abs/${prefix}.kofam_running_time.txt"
manifest="$outdir_abs/${prefix}.kofam_manifest.tsv"
exec_log="$outdir_abs/${prefix}.kofam_exec_annotation.log"

exec_args=(-f "$format" -o "$detail_out")
for option in "${exec_options[@]}"; do
  read -r -a option_parts <<< "$option"
  exec_args+=("${option_parts[@]}")
done
exec_args+=("$protein_abs")

{
  printf '[%s] Workflow started\n' "$(date)"
  start=$(date +%s)
  "$exec_annotation_cmd" "${exec_args[@]}" > "$exec_log" 2>&1
  parse_args=(--input "$detail_out" --out "$parsed_out")
  [[ "$keep_all" -eq 1 ]] && parse_args+=(--keep-all)
  "$python_cmd" "$script_dir/parse_kofam_detail.py" "${parse_args[@]}"
  "$python_cmd" - "$detail_out" "$legacy_ko" "$evalue" <<'PY'
from __future__ import annotations
from collections import OrderedDict
from pathlib import Path
import sys

input_path = Path(sys.argv[1])
out_path = Path(sys.argv[2])
cutoff = float(sys.argv[3])
rows: OrderedDict[str, list[str]] = OrderedDict()
with input_path.open() as handle:
    for line in handle:
        text = line.strip()
        if not text or text.startswith("#"):
            continue
        parts = text.split()
        if parts and parts[0] == "*":
            parts = parts[1:]
        if len(parts) < 5:
            continue
        query, ko, evalue = parts[0], parts[1], parts[4]
        try:
            if float(evalue) >= cutoff:
                continue
        except ValueError:
            continue
        rows.setdefault(query, [])
        if ko not in rows[query]:
            rows[query].append(ko)
with out_path.open("w") as out:
    for query, kos in rows.items():
        out.write(f"{query}\t{'!'.join(kos)}\n")
PY
  duration=$(( $(date +%s) - start ))
  awk -v s="$duration" 'BEGIN {printf "[%s] Duration: %.4f hours\n", strftime("%Y-%m-%d %H:%M:%S"), s/3600}'
} | tee -a "$runtime_log"

cat > "$manifest" <<MANIFEST
field	value
prefix	$prefix
protein	$protein_abs
format	$format
evalue	$evalue
keep_all	$keep_all
detail_output	$detail_out
parsed_output	$parsed_out
legacy_ko	$legacy_ko
exec_log	$exec_log
runtime_log	$runtime_log
MANIFEST
