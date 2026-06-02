#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run_target_family_workflow.sh --annotation functional_annotation.tsv --rules target_rules.tsv --outdir target_family [options]

Chain the Stage 07 target functional-family workflow:
  1. Apply a user-supplied rule table to annotation, BLAST/DIAMOND, and optional seed evidence.
  2. Write selected gene IDs, evidence tables, and family summaries.
  3. Optionally extract selected peptide FASTA and tree-tip metadata.
  4. Optionally summarize expression matrices by target family.

Required:
  --annotation FILE       Functional annotation table
  --rules FILE            Target-family rule TSV
  --outdir DIR            Output directory

Options:
  --prefix NAME           Output prefix [target_family]
  --blast-hits FILE       Optional BLAST/DIAMOND outfmt6 evidence
  --seed-ids FILE         Optional seed/candidate gene IDs
  --peptides FILE         Optional peptide FASTA for selected target genes
  --expression FILE       Optional expression matrix, such as RSEM TPM matrix
  --id-column COLUMN      Annotation/expression ID column [transcript_id]
  --expression-id-column COLUMN Expression matrix ID column [gene_id]
  --max-evalue FLOAT      Maximum BLAST/DIAMOND e-value [1e-5]
  --min-bitscore FLOAT    Optional minimum BLAST/DIAMOND bitscore
  --python CMD            Python executable [python3]
  -h, --help              Show this help
USAGE
}

annotation=""
rules=""
outdir=""
prefix="target_family"
blast_hits=""
seed_ids=""
peptides=""
expression=""
id_column="transcript_id"
expression_id_column="gene_id"
max_evalue="1e-5"
min_bitscore=""
python_cmd="python3"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --annotation) annotation=${2:?"Missing value for --annotation"}; shift 2 ;;
    --rules) rules=${2:?"Missing value for --rules"}; shift 2 ;;
    --outdir) outdir=${2:?"Missing value for --outdir"}; shift 2 ;;
    --prefix) prefix=${2:?"Missing value for --prefix"}; shift 2 ;;
    --blast-hits) blast_hits=${2:?"Missing value for --blast-hits"}; shift 2 ;;
    --seed-ids) seed_ids=${2:?"Missing value for --seed-ids"}; shift 2 ;;
    --peptides) peptides=${2:?"Missing value for --peptides"}; shift 2 ;;
    --expression) expression=${2:?"Missing value for --expression"}; shift 2 ;;
    --id-column) id_column=${2:?"Missing value for --id-column"}; shift 2 ;;
    --expression-id-column) expression_id_column=${2:?"Missing value for --expression-id-column"}; shift 2 ;;
    --max-evalue) max_evalue=${2:?"Missing value for --max-evalue"}; shift 2 ;;
    --min-bitscore) min_bitscore=${2:?"Missing value for --min-bitscore"}; shift 2 ;;
    --python) python_cmd=${2:?"Missing value for --python"}; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

for name in annotation rules outdir; do
  value=${!name}
  if [[ -z "$value" ]]; then
    echo "Missing required --${name}" >&2
    usage >&2
    exit 1
  fi
done
for file in "$annotation" "$rules" "$blast_hits" "$seed_ids" "$peptides" "$expression"; do
  if [[ -n "$file" && ! -s "$file" ]]; then
    echo "Missing or empty input file: $file" >&2
    exit 1
  fi
done

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
outdir_abs=$(mkdir -p "$outdir" && readlink -f "$outdir")

evidence="$outdir_abs/${prefix}.target_family_evidence.tsv"
target_ids="$outdir_abs/${prefix}.target_gene_ids.txt"
summary="$outdir_abs/${prefix}.target_family_summary.tsv"

merge_args=(
  --annotation "$annotation"
  --rules "$rules"
  --out "$evidence"
  --target-ids "$target_ids"
  --summary "$summary"
  --id-column "$id_column"
  --max-evalue "$max_evalue"
)
[[ -n "$blast_hits" ]] && merge_args+=(--blast-hits "$blast_hits")
[[ -n "$seed_ids" ]] && merge_args+=(--seed-ids "$seed_ids")
[[ -n "$min_bitscore" ]] && merge_args+=(--min-bitscore "$min_bitscore")
"$python_cmd" "$script_dir/merge_target_family_evidence.py" "${merge_args[@]}"

if [[ -n "$peptides" ]]; then
  "$python_cmd" "$script_dir/build_target_family_inputs.py" \
    --target-ids "$target_ids" \
    --peptides "$peptides" \
    --functional-annotation "$annotation" \
    --evidence "$evidence" \
    --id-column "$id_column" \
    --out-fasta "$outdir_abs/${prefix}.target_peptides.fa" \
    --tip-table "$outdir_abs/${prefix}.tree_tip_metadata.tsv" \
    --missing-ids "$outdir_abs/${prefix}.missing_peptides.tsv"
fi

if [[ -n "$expression" ]]; then
  "$python_cmd" "$script_dir/summarize_gene_set_expression.py" \
    --matrix "$expression" \
    --evidence "$evidence" \
    --target-ids "$target_ids" \
    --id-column "$expression_id_column" \
    --out "$outdir_abs/${prefix}.expression_family_summary.tsv" \
    --gene-details "$outdir_abs/${prefix}.expression_gene_details.tsv"
fi
