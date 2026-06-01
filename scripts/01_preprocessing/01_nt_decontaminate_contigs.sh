#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: 01_nt_decontaminate_contigs.sh --id sample_id --fasta assembly.fa --blast-db nt_db_dir --accession2taxid nucl_gb.accession2taxid.gz --lineage fullnamelineage.dmp.gz [options]

Run an NT-based contig decontamination workflow with local databases and local helper scripts.
This wrapper is a portable template and intentionally contains no site-specific paths.

Required:
  --id NAME               Output prefix / sample ID
  --fasta FILE            Input assembly FASTA
  --blast-db DIR          Directory containing the local NT BLAST database prefix 'nt'
  --accession2taxid FILE  NCBI accession-to-taxid table
  --lineage FILE          NCBI full-name lineage table
  --script-dir DIR        Directory containing cn50.py, length_by_seq.pl, get_cov_list_nt.pl, exclude_fa.pl

Options:
  --cpu INT               BLAST threads [20]
  --threshold FLOAT       Contamination coverage threshold [0.5]
  --max-hsps INT          blastn -max_hsps [500]
  --max-target-seqs INT   blastn -max_target_seqs [100]
  --outdir DIR            Output directory [<id>_rm]
  --blastn CMD            blastn executable [blastn]
  --python CMD            Python executable [python3]
  -h, --help              Show this help

Outputs:
  <outdir>/<id>.n50
  <outdir>/<input_basename>.size
  <outdir>/<id>.m6
  <outdir>/ngdc.up.<threshold>.list or helper-script-defined contaminant list
  <outdir>/<id>.nt.fa
  <outdir>/<id>.nt.fa.n50
USAGE
}

id=""
fasta=""
blast_db=""
accession2taxid=""
lineage=""
script_dir=""
cpu=20
threshold=0.5
max_hsps=500
max_target_seqs=100
outdir=""
blastn_cmd="blastn"
python_cmd="python3"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --id) id=${2:?"Missing value for --id"}; shift 2 ;;
    --fasta) fasta=${2:?"Missing value for --fasta"}; shift 2 ;;
    --blast-db) blast_db=${2:?"Missing value for --blast-db"}; shift 2 ;;
    --accession2taxid) accession2taxid=${2:?"Missing value for --accession2taxid"}; shift 2 ;;
    --lineage) lineage=${2:?"Missing value for --lineage"}; shift 2 ;;
    --script-dir) script_dir=${2:?"Missing value for --script-dir"}; shift 2 ;;
    --cpu) cpu=${2:?"Missing value for --cpu"}; shift 2 ;;
    --threshold) threshold=${2:?"Missing value for --threshold"}; shift 2 ;;
    --max-hsps) max_hsps=${2:?"Missing value for --max-hsps"}; shift 2 ;;
    --max-target-seqs) max_target_seqs=${2:?"Missing value for --max-target-seqs"}; shift 2 ;;
    --outdir) outdir=${2:?"Missing value for --outdir"}; shift 2 ;;
    --blastn) blastn_cmd=${2:?"Missing value for --blastn"}; shift 2 ;;
    --python) python_cmd=${2:?"Missing value for --python"}; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

for name in id fasta blast_db accession2taxid lineage script_dir; do
  value=${!name}
  if [[ -z "$value" ]]; then
    echo "Missing required --${name//_/-}" >&2
    usage >&2
    exit 1
  fi
done
for file in "$fasta" "$accession2taxid" "$lineage"; do
  if [[ ! -s "$file" ]]; then
    echo "Missing or empty input file: $file" >&2
    exit 1
  fi
done
if [[ ! -d "$blast_db" ]]; then
  echo "Missing BLAST database directory: $blast_db" >&2
  exit 1
fi
if [[ ! -d "$script_dir" ]]; then
  echo "Missing helper script directory: $script_dir" >&2
  exit 1
fi
for helper in cn50.py length_by_seq.pl get_cov_list_nt.pl exclude_fa.pl; do
  if [[ ! -s "$script_dir/$helper" ]]; then
    echo "Missing helper script: $script_dir/$helper" >&2
    exit 1
  fi
done
if ! command -v "$blastn_cmd" >/dev/null 2>&1; then
  echo "blastn executable not found: $blastn_cmd" >&2
  exit 1
fi

outdir=${outdir:-${id}_rm}
mkdir -p "$outdir"
fasta_abs=$(readlink -f "$fasta")
script_abs=$(readlink -f "$script_dir")
accession_abs=$(readlink -f "$accession2taxid")
lineage_abs=$(readlink -f "$lineage")
blast_db_abs=$(readlink -f "$blast_db")
fasta_base=$(basename "$fasta")

(
  cd "$outdir"
  "$python_cmd" "$script_abs/cn50.py" "$fasta_abs" > "${id}.n50"
  perl "$script_abs/length_by_seq.pl" "$fasta_abs"

  "$blastn_cmd" \
    -db "$blast_db_abs/nt" \
    -query "$fasta_abs" \
    -out "${id}.m6" \
    -evalue 1e-5 \
    -max_hsps "$max_hsps" \
    -outfmt 6 \
    -max_target_seqs "$max_target_seqs" \
    -num_threads "$cpu"

  perl "$script_abs/get_cov_list_nt.pl" \
    "${id}.m6" \
    "${fasta_base}.size" \
    "$threshold" \
    "$accession_abs" \
    "$lineage_abs"

  list="ngdc.up.${threshold}.list"
  if [[ ! -s "$list" && "$threshold" == "0.5" && -s "ngdc.up.0.5.list" ]]; then
    list="ngdc.up.0.5.list"
  fi
  if [[ ! -s "$list" ]]; then
    echo "Expected contaminant list not found: $list" >&2
    exit 1
  fi

  perl "$script_abs/exclude_fa.pl" --fa "$fasta_abs" --list "$list" > "${id}.nt.fa"
  "$python_cmd" "$script_abs/cn50.py" "${id}.nt.fa" > "${id}.nt.fa.n50"
)
