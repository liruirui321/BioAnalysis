#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: repeat_stat.sh <RepeatMasker.out> <genome_size> [output.tsv]

Summarize non-redundant repeat coverage from RepeatMasker .out using merged intervals.
Categories: all, DNA Transposons, SINEs, LINE, LTR, Unknown, Satellite, Simple_repeat.

This is a cleaned BioAnalysis version of the reference repeatmasker/stat.sh logic.
USAGE
}

if [[ ${1:-} == "-h" || ${1:-} == "--help" || $# -lt 2 ]]; then
  usage
  exit 0
fi

infile=$1
gsize=$2
outfile=${3:-/dev/stdout}

if [[ ! -s "$infile" ]]; then
  echo "Missing or empty RepeatMasker .out: $infile" >&2
  exit 1
fi
if ! [[ "$gsize" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "Genome size must be numeric: $gsize" >&2
  exit 1
fi

summarize() {
  local label=$1
  local pattern=$2
  if [[ "$pattern" == "__ALL__" ]]; then
    awk 'NR>3 && $5 !~ /^#/ {print $5"\t"$6-1"\t"$7}' "$infile"
  else
    awk -v pat="$pattern" 'NR>3 && $0 ~ pat {print $5"\t"$6-1"\t"$7}' "$infile"
  fi \
    | sort -k1,1 -k2,2n \
    | bedtools merge -i - \
    | awk -v label="$label" -v gsize="$gsize" 'BEGIN{sum=0} {sum += $3 - $2} END{printf "%s\t%d\t%.6f\n", label, sum, (gsize>0 ? sum/gsize*100 : 0)}'
}

{
  echo -e "category\tcoverage_bp\tcoverage_percent"
  summarize "all repeat" "__ALL__"
  summarize "DNA Transposons" "DNA"
  summarize "SINEs" "SINE"
  summarize "LINE" "LINE"
  summarize "LTR" "LTR"
  summarize "Unknown" "Unknown"
  summarize "Satellite" "Satellite"
  summarize "Simple_repeat" "Simple_repeat"
} > "$outfile"
