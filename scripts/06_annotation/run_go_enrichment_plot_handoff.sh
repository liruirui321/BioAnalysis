#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run_go_enrichment_plot_handoff.sh --annotation functional_annotation.tsv --foreground gene_ids.txt --outdir go_handoff [options]

Run a Stage 06 GO enrichment and visualization handoff workflow:
  1. Run simple GO overrepresentation with enrich_annotation_terms.py.
  2. Prepare a filtered semantic-space handoff table for external plotting tools.

Required:
  --annotation FILE       functional_annotation.tsv or compatible annotation table
  --foreground FILE       Foreground gene ID list
  --outdir DIR            Output directory

Options:
  --prefix NAME           Output prefix [annotation basename]
  --background FILE       Optional background gene ID list
  --id-column COLUMN      Gene/transcript ID column [transcript_id]
  --term-column COLUMN    GO term column [GO_terms]
  --go-names FILE         Optional GO term-name TSV
  --q-value-cutoff FLOAT  Q-value cutoff for plot handoff [0.05]
  --max-terms INT         Maximum GO terms in plot handoff [200]
  --plot-group NAME       Plot group label [target]
  --python CMD            Python executable [python3]
  -h, --help              Show this help
USAGE
}

annotation=""
foreground=""
outdir=""
prefix=""
background=""
id_column="transcript_id"
term_column="GO_terms"
go_names=""
q_value_cutoff="0.05"
max_terms=200
plot_group="target"
python_cmd="python3"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --annotation) annotation=${2:?"Missing value for --annotation"}; shift 2 ;;
    --foreground) foreground=${2:?"Missing value for --foreground"}; shift 2 ;;
    --outdir) outdir=${2:?"Missing value for --outdir"}; shift 2 ;;
    --prefix) prefix=${2:?"Missing value for --prefix"}; shift 2 ;;
    --background) background=${2:?"Missing value for --background"}; shift 2 ;;
    --id-column) id_column=${2:?"Missing value for --id-column"}; shift 2 ;;
    --term-column) term_column=${2:?"Missing value for --term-column"}; shift 2 ;;
    --go-names) go_names=${2:?"Missing value for --go-names"}; shift 2 ;;
    --q-value-cutoff) q_value_cutoff=${2:?"Missing value for --q-value-cutoff"}; shift 2 ;;
    --max-terms) max_terms=${2:?"Missing value for --max-terms"}; shift 2 ;;
    --plot-group) plot_group=${2:?"Missing value for --plot-group"}; shift 2 ;;
    --python) python_cmd=${2:?"Missing value for --python"}; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

for name in annotation foreground outdir; do
  value=${!name}
  if [[ -z "$value" ]]; then
    echo "Missing required --${name}" >&2
    usage >&2
    exit 1
  fi
done
for file in "$annotation" "$foreground" "$background" "$go_names"; do
  if [[ -n "$file" && ! -s "$file" ]]; then
    echo "Missing or empty input file: $file" >&2
    exit 1
  fi
done

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
outdir_abs=$(mkdir -p "$outdir" && readlink -f "$outdir")
prefix=${prefix:-$(basename "$annotation")}
prefix=${prefix%.tsv}

enrichment="$outdir_abs/${prefix}.go.enrichment.tsv"
handoff="$outdir_abs/${prefix}.go.semantic_handoff.tsv"

enrich_args=(
  --annotation "$annotation"
  --foreground "$foreground"
  --mode go
  --term-column "$term_column"
  --id-column "$id_column"
  --out "$enrichment"
)
[[ -n "$background" ]] && enrich_args+=(--background "$background")
"$python_cmd" "$script_dir/enrich_annotation_terms.py" "${enrich_args[@]}"

handoff_args=(
  --enrichment "$enrichment"
  --out "$handoff"
  --q-value-cutoff "$q_value_cutoff"
  --max-terms "$max_terms"
  --plot-group "$plot_group"
)
[[ -n "$go_names" ]] && handoff_args+=(--go-names "$go_names")
"$python_cmd" "$script_dir/prepare_go_semantic_handoff.py" "${handoff_args[@]}"
