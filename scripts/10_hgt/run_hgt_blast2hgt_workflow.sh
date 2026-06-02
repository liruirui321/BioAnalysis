#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run_hgt_blast2hgt_workflow.sh --query proteins.fa --blast2hgt-dir blast2hgt --blast-glob 'proteins.fa_*.nr.out' --outdir hgt_work [options]

Chain the Stage 10 HGT workflow:
  1. Use existing NR BLAST/DIAMOND outfmt 6 files, or optionally create taxon-group DIAMOND outputs.
  2. Run blast2hgt handoff to create .rp.bls, .rp.taxid, .rp.lin, and .rp.tsv.
  3. Filter the blast2hgt .rp.tsv table into candidate and rejected HGT tables.
  4. Optionally add genome context and prepare validation handoff files.

Required:
  --query FILE                  Query protein/gene/genomic FASTA
  --blast2hgt-dir DIR           External blast2hgt installation directory
  --outdir DIR                  Workflow output directory
  --self-group NAME=TAXID       First blast2hgt group; treated as self/vertical lineage
  --donor-groups NAMES          Comma-separated donor groups to accept, matching --define names

Input options, choose one:
  --blast-glob GLOB             Existing split BLAST/DIAMOND outfmt 6 files
  --blast-all FILE              Existing concatenated BLAST/DIAMOND outfmt 6 file
  --diamond-db-dir DIR          Directory containing <taxid>.dmnd databases for --taxon TAXID values

Taxonomy definitions:
  --define NAME=TAXID           Additional blast2hgt group definition; repeatable
  --taxon TAXID                 Taxon database to search when --diamond-db-dir is used; repeatable

Filtering options:
  --min-alien-index FLOAT       Minimum blast2hgt alien_index [0]
  --min-donor-bitscore FLOAT    Minimum donor bitscore [50]
  --min-donor-taxon-count INT   Minimum donor taxon count [1]

Optional context and validation:
  --gff FILE                    Annotation GFF3 for context output
  --functional-annotation FILE  Functional annotation TSV
  --intron-details FILE         Intron details TSV
  --synteny FILE                Synteny support TSV
  --classified-hits FILE        Optional classified donor hits for top-donor validation IDs
  --skip-context                Do not run context or validation handoff

Executables:
  --diamond CMD                 DIAMOND executable [diamond]
  --threads INT                 DIAMOND threads [32]
  --perl CMD                    Perl executable [perl]
  --python CMD                  Python executable [python3]
  -h, --help                    Show this help

Outputs:
  <outdir>/blast2hgt/<prefix>.rp.tsv
  <outdir>/<prefix>.hgt.candidates.tsv
  <outdir>/<prefix>.hgt.rejected.tsv
  <outdir>/<prefix>.hgt.score_summary.tsv
  <outdir>/<prefix>.hgt.context.tsv when --gff is provided and context is not skipped
  <outdir>/hgt_validation/ when validation handoff is run
USAGE
}

query=""
blast2hgt_dir=""
outdir=""
self_group=""
donor_groups=""
blast_glob=""
blast_all=""
diamond_db_dir=""
definitions=()
taxa=()
min_alien_index="0"
min_donor_bitscore="50"
min_donor_taxon_count="1"
gff=""
functional_annotation=""
intron_details=""
synteny=""
classified_hits=""
skip_context=0
diamond_cmd="diamond"
threads=32
perl_cmd="perl"
python_cmd="python3"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --query) query=${2:?"Missing value for --query"}; shift 2 ;;
    --blast2hgt-dir) blast2hgt_dir=${2:?"Missing value for --blast2hgt-dir"}; shift 2 ;;
    --outdir) outdir=${2:?"Missing value for --outdir"}; shift 2 ;;
    --self-group) self_group=${2:?"Missing value for --self-group"}; shift 2 ;;
    --donor-groups) donor_groups=${2:?"Missing value for --donor-groups"}; shift 2 ;;
    --blast-glob) blast_glob=${2:?"Missing value for --blast-glob"}; shift 2 ;;
    --blast-all) blast_all=${2:?"Missing value for --blast-all"}; shift 2 ;;
    --diamond-db-dir) diamond_db_dir=${2:?"Missing value for --diamond-db-dir"}; shift 2 ;;
    --define) definitions+=("${2:?"Missing value for --define"}"); shift 2 ;;
    --taxon) taxa+=("${2:?"Missing value for --taxon"}"); shift 2 ;;
    --min-alien-index) min_alien_index=${2:?"Missing value for --min-alien-index"}; shift 2 ;;
    --min-donor-bitscore) min_donor_bitscore=${2:?"Missing value for --min-donor-bitscore"}; shift 2 ;;
    --min-donor-taxon-count) min_donor_taxon_count=${2:?"Missing value for --min-donor-taxon-count"}; shift 2 ;;
    --gff) gff=${2:?"Missing value for --gff"}; shift 2 ;;
    --functional-annotation) functional_annotation=${2:?"Missing value for --functional-annotation"}; shift 2 ;;
    --intron-details) intron_details=${2:?"Missing value for --intron-details"}; shift 2 ;;
    --synteny) synteny=${2:?"Missing value for --synteny"}; shift 2 ;;
    --classified-hits) classified_hits=${2:?"Missing value for --classified-hits"}; shift 2 ;;
    --skip-context) skip_context=1; shift ;;
    --diamond) diamond_cmd=${2:?"Missing value for --diamond"}; shift 2 ;;
    --threads) threads=${2:?"Missing value for --threads"}; shift 2 ;;
    --perl) perl_cmd=${2:?"Missing value for --perl"}; shift 2 ;;
    --python) python_cmd=${2:?"Missing value for --python"}; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

for name in query blast2hgt_dir outdir self_group donor_groups; do
  value=${!name}
  if [[ -z "$value" ]]; then
    echo "Missing required --${name//_/-}" >&2
    usage >&2
    exit 1
  fi
done
if [[ ! -s "$query" ]]; then
  echo "Missing or empty query FASTA: $query" >&2
  exit 1
fi
if [[ ! -d "$blast2hgt_dir" ]]; then
  echo "Missing blast2hgt directory: $blast2hgt_dir" >&2
  exit 1
fi
input_modes=0
[[ -n "$blast_glob" ]] && input_modes=$((input_modes + 1))
[[ -n "$blast_all" ]] && input_modes=$((input_modes + 1))
[[ -n "$diamond_db_dir" ]] && input_modes=$((input_modes + 1))
if [[ "$input_modes" -ne 1 ]]; then
  echo "Choose exactly one input mode: --blast-glob, --blast-all, or --diamond-db-dir" >&2
  exit 1
fi
if [[ -n "$diamond_db_dir" && ${#taxa[@]} -eq 0 ]]; then
  echo "Provide at least one --taxon when using --diamond-db-dir" >&2
  exit 1
fi
if [[ -n "$diamond_db_dir" && ! -d "$diamond_db_dir" ]]; then
  echo "Missing DIAMOND database directory: $diamond_db_dir" >&2
  exit 1
fi

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
outdir_abs=$(mkdir -p "$outdir" && readlink -f "$outdir")
query_abs=$(readlink -f "$query")
prefix=$(basename "$query")
blast2hgt_out="$outdir_abs/blast2hgt"
mkdir -p "$blast2hgt_out"

define_args=(--define "$self_group")
for definition in "${definitions[@]}"; do
  define_args+=(--define "$definition")
done

if [[ -n "$diamond_db_dir" ]]; then
  if ! command -v "$diamond_cmd" >/dev/null 2>&1; then
    echo "DIAMOND executable not found: $diamond_cmd" >&2
    exit 1
  fi
  for taxid in "${taxa[@]}"; do
    db="$diamond_db_dir/${taxid}.dmnd"
    if [[ ! -s "$db" ]]; then
      echo "Missing DIAMOND database: $db" >&2
      exit 1
    fi
    "$diamond_cmd" blastp \
      --query "$query_abs" \
      --db "$db" \
      --out "$blast2hgt_out/${prefix}_${taxid}.nr.out" \
      --outfmt 6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore \
      --evalue 1e-5 \
      --threads "$threads"
  done
  blast_glob="$blast2hgt_out/${prefix}_*.nr.out"
fi

handoff_args=(
  --query "$query_abs"
  --tool-dir "$blast2hgt_dir"
  --outdir "$blast2hgt_out"
  --prefix "$prefix"
  --perl "$perl_cmd"
  "${define_args[@]}"
)
if [[ -n "$blast_glob" ]]; then
  handoff_args+=(--blast-glob "$blast_glob")
else
  handoff_args+=(--blast-all "$blast_all")
fi

bash "$script_dir/00_run_blast2hgt_handoff.sh" "${handoff_args[@]}"

candidate_tsv="$outdir_abs/${prefix}.hgt.candidates.tsv"
rejected_tsv="$outdir_abs/${prefix}.hgt.rejected.tsv"
summary_tsv="$outdir_abs/${prefix}.hgt.score_summary.tsv"
"$python_cmd" "$script_dir/filter_blast2hgt_candidates.py" \
  --blast2hgt "$blast2hgt_out/${prefix}.rp.tsv" \
  --ingroup-group "${self_group%%=*}" \
  --donor-groups "$donor_groups" \
  --min-alien-index "$min_alien_index" \
  --min-donor-bitscore "$min_donor_bitscore" \
  --min-donor-taxon-count "$min_donor_taxon_count" \
  --out "$candidate_tsv" \
  --rejected "$rejected_tsv" \
  --summary "$summary_tsv"

if [[ "$skip_context" -eq 0 && -n "$gff" ]]; then
  context_args=(
    --candidates "$candidate_tsv"
    --gff "$gff"
    --out "$outdir_abs/${prefix}.hgt.context.tsv"
    --bed "$outdir_abs/${prefix}.hgt.candidates.bed"
    --summary "$outdir_abs/${prefix}.hgt.context_summary.tsv"
  )
  [[ -n "$functional_annotation" ]] && context_args+=(--functional-annotation "$functional_annotation")
  [[ -n "$intron_details" ]] && context_args+=(--intron-details "$intron_details")
  [[ -n "$synteny" ]] && context_args+=(--synteny "$synteny")
  "$python_cmd" "$script_dir/03_add_hgt_context.py" "${context_args[@]}"

  validation_args=(
    --context "$outdir_abs/${prefix}.hgt.context.tsv"
    --outdir "$outdir_abs/hgt_validation"
  )
  [[ -n "$classified_hits" ]] && validation_args+=(--classified-hits "$classified_hits")
  "$python_cmd" "$script_dir/04_prepare_hgt_validation.py" "${validation_args[@]}"
fi
