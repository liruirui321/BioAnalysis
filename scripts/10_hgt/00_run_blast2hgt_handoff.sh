#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: 00_run_blast2hgt_handoff.sh --query proteins.fa --tool-dir blast2hgt --blast-glob 'proteins.fa_rpd.*.dbls' --outdir blast2hgt_handoff [options]

Run the external blast2hgt similarity-screening handoff with local BLAST outputs and a user-supplied blast2hgt installation.
The blast2hgt installation must already be configured with its required accession/taxonomy database.
This wrapper stores no site-specific paths, database credentials, or real project identifiers.

Required:
  --query FILE             Query protein/gene/genomic FASTA used for the BLAST search
  --tool-dir DIR           blast2hgt installation directory containing bin/*.pl
  --outdir DIR             Output directory
  --blast-glob GLOB        Split BLAST outfmt 6 files to concatenate
    or
  --blast-all FILE         Already concatenated BLAST outfmt 6 file

Options:
  --prefix NAME            Output prefix [query basename]
  --max-evalue FLOAT       Maximum BLAST e-value for the raw hit table [1e-5]
  --taxid-script NAME      blast2hgt accession-to-taxid script [accgi_refseqProtein2taxonid.pl]
  --lineage-script NAME    blast2hgt taxid-to-lineage script [taxonid2lineage3.pub.pl]
  --table-script NAME      blast2hgt lineage-to-table script [lineage2table3.pub.pl]
  --define NAME=TAXID      Taxonomy group definition passed to lineage2table3.pub.pl; repeatable
  --mine-best-hit          Run blast_mine_maxb.pl before taxonomy lookup [off]
  --perl CMD               Perl executable [perl]
  -h, --help               Show this help

Default --define values match the public blast2hgt example:
  Metazoa=33208 Plant=33090 archaea=2157 bacteria=2 fungi=4751 virus=10239

Expected outputs:
  <outdir>/<prefix>_blast.all
  <outdir>/<prefix>.rp.bls
  <outdir>/<prefix>.rp.taxid
  <outdir>/<prefix>.rp.lin
  <outdir>/<prefix>.rp.tsv
  <outdir>/<prefix>.blast2hgt_manifest.tsv
USAGE
}

query=""
tool_dir=""
outdir=""
blast_glob=""
blast_all=""
prefix=""
max_evalue="1e-5"
taxid_script="accgi_refseqProtein2taxonid.pl"
lineage_script="taxonid2lineage3.pub.pl"
table_script="lineage2table3.pub.pl"
perl_cmd="perl"
mine_best_hit=0
definitions=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --query) query=${2:?"Missing value for --query"}; shift 2 ;;
    --tool-dir) tool_dir=${2:?"Missing value for --tool-dir"}; shift 2 ;;
    --outdir) outdir=${2:?"Missing value for --outdir"}; shift 2 ;;
    --blast-glob) blast_glob=${2:?"Missing value for --blast-glob"}; shift 2 ;;
    --blast-all) blast_all=${2:?"Missing value for --blast-all"}; shift 2 ;;
    --prefix) prefix=${2:?"Missing value for --prefix"}; shift 2 ;;
    --max-evalue) max_evalue=${2:?"Missing value for --max-evalue"}; shift 2 ;;
    --taxid-script) taxid_script=${2:?"Missing value for --taxid-script"}; shift 2 ;;
    --lineage-script) lineage_script=${2:?"Missing value for --lineage-script"}; shift 2 ;;
    --table-script) table_script=${2:?"Missing value for --table-script"}; shift 2 ;;
    --define) definitions+=("${2:?"Missing value for --define"}"); shift 2 ;;
    --mine-best-hit) mine_best_hit=1; shift ;;
    --perl) perl_cmd=${2:?"Missing value for --perl"}; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

for name in query tool_dir outdir; do
  value=${!name}
  if [[ -z "$value" ]]; then
    echo "Missing required --${name//_/-}" >&2
    usage >&2
    exit 1
  fi
done
if [[ -z "$blast_glob" && -z "$blast_all" ]]; then
  echo "Provide either --blast-glob or --blast-all" >&2
  usage >&2
  exit 1
fi
if [[ -n "$blast_glob" && -n "$blast_all" ]]; then
  echo "Use only one of --blast-glob or --blast-all" >&2
  usage >&2
  exit 1
fi
if [[ ! -s "$query" ]]; then
  echo "Missing or empty query FASTA: $query" >&2
  exit 1
fi
if [[ ! -d "$tool_dir" ]]; then
  echo "Missing blast2hgt tool directory: $tool_dir" >&2
  exit 1
fi
if ! command -v "$perl_cmd" >/dev/null 2>&1; then
  echo "Perl executable not found: $perl_cmd" >&2
  exit 1
fi

bin_dir="$tool_dir/bin"
if [[ ! -d "$bin_dir" ]]; then
  echo "Missing blast2hgt bin directory: $bin_dir" >&2
  exit 1
fi
for helper in "$taxid_script" "$lineage_script" "$table_script"; do
  if [[ ! -s "$bin_dir/$helper" ]]; then
    echo "Missing blast2hgt script: $bin_dir/$helper" >&2
    exit 1
  fi
done
if [[ "$mine_best_hit" -eq 1 && ! -s "$bin_dir/blast_mine_maxb.pl" ]]; then
  echo "Missing blast2hgt script: $bin_dir/blast_mine_maxb.pl" >&2
  exit 1
fi

if [[ ${#definitions[@]} -eq 0 ]]; then
  definitions=(Metazoa=33208 Plant=33090 archaea=2157 bacteria=2 fungi=4751 virus=10239)
fi
define_args=()
for definition in "${definitions[@]}"; do
  if [[ "$definition" != *=* ]]; then
    echo "Invalid --define value, expected NAME=TAXID: $definition" >&2
    exit 1
  fi
  define_args+=(--define "$definition")
done

query_abs=$(readlink -f "$query")
tool_abs=$(readlink -f "$tool_dir")
outdir_abs=$(mkdir -p "$outdir" && readlink -f "$outdir")
prefix=${prefix:-$(basename "$query")}

blast_inputs=()
if [[ -n "$blast_all" ]]; then
  if [[ ! -s "$blast_all" ]]; then
    echo "Missing or empty BLAST file: $blast_all" >&2
    exit 1
  fi
  blast_inputs+=("$(readlink -f "$blast_all")")
else
  mapfile -t blast_inputs < <(compgen -G "$blast_glob" | sort)
  if [[ ${#blast_inputs[@]} -eq 0 ]]; then
    echo "No BLAST files matched --blast-glob: $blast_glob" >&2
    exit 1
  fi
  for i in "${!blast_inputs[@]}"; do
    if [[ ! -s "${blast_inputs[$i]}" ]]; then
      echo "Missing or empty BLAST file: ${blast_inputs[$i]}" >&2
      exit 1
    fi
    blast_inputs[$i]=$(readlink -f "${blast_inputs[$i]}")
  done
fi

(
  cd "$outdir_abs"
  cat "${blast_inputs[@]}" > "${prefix}_blast.all"
  awk -v max="$max_evalue" 'BEGIN{OFS="\t"} $11 <= max {print $1,$2,$11,$12}' "${prefix}_blast.all" > "${prefix}.rp.bls"
  if [[ "$mine_best_hit" -eq 1 ]]; then
    "$perl_cmd" "$tool_abs/bin/blast_mine_maxb.pl" "${prefix}.rp.bls" > "${prefix}.rp.bls.maxb"
    mv "${prefix}.rp.bls.maxb" "${prefix}.rp.bls"
  fi
  "$perl_cmd" "$tool_abs/bin/$taxid_script" "${prefix}.rp.bls" > "${prefix}.rp.taxid"
  "$perl_cmd" "$tool_abs/bin/$lineage_script" "${prefix}.rp.taxid" > "${prefix}.rp.lin"
  cat "${prefix}.rp.lin" "${prefix}.rp.taxid" | "$perl_cmd" "$tool_abs/bin/$table_script" - "${define_args[@]}" > "${prefix}.rp.tsv"
  {
    printf 'field\tvalue\n'
    printf 'query\t%s\n' "$query_abs"
    printf 'tool_dir\t%s\n' "$tool_abs"
    printf 'blast_input_count\t%s\n' "${#blast_inputs[@]}"
    printf 'max_evalue\t%s\n' "$max_evalue"
    printf 'taxid_script\t%s\n' "$taxid_script"
    printf 'lineage_script\t%s\n' "$lineage_script"
    printf 'table_script\t%s\n' "$table_script"
    printf 'taxonomy_defines\t%s\n' "${definitions[*]}"
    printf 'mine_best_hit\t%s\n' "$mine_best_hit"
  } > "${prefix}.blast2hgt_manifest.tsv"
)
