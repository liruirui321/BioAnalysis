#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run_hgt_nr_taxonlist_workflow.sh --query proteins.fa --diamond-db nr_diamond --taxonlist bacteria=2 --outdir nr_by_taxon [options]

Run independent Stage 10 DIAMOND NR searches split by NCBI taxonlist groups.
The output files are compatible with the blast2hgt handoff workflow.

Required:
  --query FILE              Protein FASTA query
  --diamond-db FILE         DIAMOND database path or prefix
  --taxonlist NAME=TAXID    Taxon group to search; repeatable
  --outdir DIR              Output directory

Options:
  --prefix NAME             Output prefix [query basename]
  --diamond CMD             DIAMOND executable [diamond]
  --threads INT             Threads [10]
  --evalue FLOAT            E-value cutoff [1e-5]
  --identity FLOAT          Minimum identity passed to DIAMOND --id [40]
  --max-target-seqs INT     Maximum targets per query [500]
  --max-hsps INT            Maximum HSPs per target [1]
  --taxon-k INT             DIAMOND --taxon-k [1]
  --block-size FLOAT        DIAMOND block size [20]
  --tmpdir DIR              Temporary directory [<outdir>/tmp]
  --sensitive               Use DIAMOND --sensitive [on]
  --no-sensitive            Disable DIAMOND --sensitive
  --diamond-option TEXT     Additional DIAMOND option; repeatable
  -h, --help                Show this help

Outputs:
  <outdir>/<prefix>_<name>.nr.out
  <outdir>/<prefix>.nr_taxonlist_manifest.tsv
  <outdir>/<prefix>.nr_taxonlist_running_time.txt
USAGE
}

query=""
diamond_db=""
outdir=""
prefix=""
diamond_cmd="diamond"
threads=10
evalue="1e-5"
identity="40"
max_target_seqs=500
max_hsps=1
taxon_k=1
block_size="20"
tmpdir=""
sensitive=1
taxonlists=()
diamond_options=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --query) query=${2:?"Missing value for --query"}; shift 2 ;;
    --diamond-db) diamond_db=${2:?"Missing value for --diamond-db"}; shift 2 ;;
    --taxonlist) taxonlists+=("${2:?"Missing value for --taxonlist"}"); shift 2 ;;
    --outdir) outdir=${2:?"Missing value for --outdir"}; shift 2 ;;
    --prefix) prefix=${2:?"Missing value for --prefix"}; shift 2 ;;
    --diamond) diamond_cmd=${2:?"Missing value for --diamond"}; shift 2 ;;
    --threads) threads=${2:?"Missing value for --threads"}; shift 2 ;;
    --evalue) evalue=${2:?"Missing value for --evalue"}; shift 2 ;;
    --identity) identity=${2:?"Missing value for --identity"}; shift 2 ;;
    --max-target-seqs) max_target_seqs=${2:?"Missing value for --max-target-seqs"}; shift 2 ;;
    --max-hsps) max_hsps=${2:?"Missing value for --max-hsps"}; shift 2 ;;
    --taxon-k) taxon_k=${2:?"Missing value for --taxon-k"}; shift 2 ;;
    --block-size) block_size=${2:?"Missing value for --block-size"}; shift 2 ;;
    --tmpdir) tmpdir=${2:?"Missing value for --tmpdir"}; shift 2 ;;
    --sensitive) sensitive=1; shift ;;
    --no-sensitive) sensitive=0; shift ;;
    --diamond-option) diamond_options+=("${2:?"Missing value for --diamond-option"}"); shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

for name in query diamond_db outdir; do
  value=${!name}
  if [[ -z "$value" ]]; then
    echo "Missing required --${name//_/-}" >&2
    usage >&2
    exit 1
  fi
done
if [[ ${#taxonlists[@]} -eq 0 ]]; then
  echo "Provide at least one --taxonlist NAME=TAXID" >&2
  exit 1
fi
if [[ ! -s "$query" ]]; then
  echo "Missing or empty query FASTA: $query" >&2
  exit 1
fi
if ! command -v "$diamond_cmd" >/dev/null 2>&1; then
  echo "DIAMOND executable not found: $diamond_cmd" >&2
  exit 1
fi

query_abs=$(readlink -f "$query")
outdir_abs=$(mkdir -p "$outdir" && readlink -f "$outdir")
prefix=${prefix:-$(basename "$query")}
tmpdir=${tmpdir:-"$outdir_abs/tmp"}
mkdir -p "$tmpdir"
runtime_log="$outdir_abs/${prefix}.nr_taxonlist_running_time.txt"
manifest="$outdir_abs/${prefix}.nr_taxonlist_manifest.tsv"

{
  printf '[%s] Workflow started\n' "$(date)"
  start=$(date +%s)
  for item in "${taxonlists[@]}"; do
    if [[ "$item" != *=* ]]; then
      echo "Invalid --taxonlist value, expected NAME=TAXID: $item" >&2
      exit 1
    fi
    group=${item%%=*}
    taxid=${item#*=}
    out="$outdir_abs/${prefix}_${group}.nr.out"
    args=(
      blastp
      -d "$diamond_db"
      -q "$query_abs"
      --taxonlist "$taxid"
      --evalue "$evalue"
      --outfmt 6
      --max-target-seqs "$max_target_seqs"
      --max-hsps "$max_hsps"
      --taxon-k "$taxon_k"
      --id "$identity"
      --block-size "$block_size"
      --tmpdir "$tmpdir"
      --out "$out"
      --threads "$threads"
    )
    if [[ "$sensitive" -eq 1 ]]; then
      args+=(--sensitive)
    fi
    args+=("${diamond_options[@]}")
    "$diamond_cmd" "${args[@]}"
  done
  printf '[%s] Duration: %.6f hours\n' "$(date)" "$(awk -v s=$(($(date +%s) - start)) 'BEGIN {print s/3600}')"
} | tee "$runtime_log"

{
  printf 'field\tvalue\n'
  printf 'query\t%s\n' "$query_abs"
  printf 'diamond_db\t%s\n' "$diamond_db"
  printf 'taxonlists\t%s\n' "${taxonlists[*]}"
  printf 'threads\t%s\n' "$threads"
  printf 'evalue\t%s\n' "$evalue"
  printf 'identity\t%s\n' "$identity"
  printf 'max_target_seqs\t%s\n' "$max_target_seqs"
  printf 'max_hsps\t%s\n' "$max_hsps"
  printf 'taxon_k\t%s\n' "$taxon_k"
  printf 'block_size\t%s\n' "$block_size"
  printf 'tmpdir\t%s\n' "$tmpdir"
  printf 'sensitive\t%s\n' "$sensitive"
  printf 'output_glob\t%s\n' "$outdir_abs/${prefix}_*.nr.out"
  printf 'runtime_log\t%s\n' "$runtime_log"
} > "$manifest"
