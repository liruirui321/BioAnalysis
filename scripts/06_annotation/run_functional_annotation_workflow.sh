#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run_functional_annotation_workflow.sh --gff annotation.gff3 --outdir annotation_work [options]

Chain the Stage 06 functional-annotation workflow:
  1. Parse InterProScan and KofamScan outputs when supplied.
  2. Merge structural, CDS QC, InterPro/Pfam, eggNOG, Kofam, SwissProt, and NR annotations.
  3. Summarize GO, Pfam, KEGG pathway, eggNOG COG/NOG category, and Pfam domain-architecture outputs when inputs are available.
  4. Optionally run GO/KEGG/Pfam enrichment for a foreground gene list.

Required:
  --gff FILE                Annotation GFF/GFF3
  --outdir DIR              Output directory

Options:
  --prefix NAME             Output prefix [GFF basename]
  --cds-check FILE          CDS QC table from Stage 04
  --interproscan FILE       Raw InterProScan TSV
  --iprscan-parsed FILE     Already parsed InterProScan table
  --kofam-detail FILE       Raw KofamScan detail output
  --kofam-parsed FILE       Already parsed Kofam table
  --eggnog FILE             eggNOG annotation TSV
  --swissprot FILE          SwissProt hit/annotation TSV
  --nr FILE                 NR hit/annotation TSV
  --ko-map FILE             KO-to-pathway map TSV
  --pathway-names FILE      Optional pathway-name map TSV
  --pfam-map FILE           Optional Pfam ID/name map TSV
  --foreground FILE         Optional foreground gene IDs for enrichment
  --background FILE         Optional background gene IDs for enrichment
  --enrichment-mode MODE    go|kegg|pfam [kegg]
  --enrichment-term-column COLUMN Override enrichment term column
  --python CMD              Python executable [python3]
  -h, --help                Show this help
USAGE
}

gff=""
outdir=""
prefix=""
cds_check=""
interproscan=""
iprscan_parsed=""
kofam_detail=""
kofam_parsed=""
eggnog=""
swissprot=""
nr=""
ko_map=""
pathway_names=""
pfam_map=""
foreground=""
background=""
enrichment_mode="kegg"
enrichment_term_column=""
python_cmd="python3"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --gff) gff=${2:?"Missing value for --gff"}; shift 2 ;;
    --outdir) outdir=${2:?"Missing value for --outdir"}; shift 2 ;;
    --prefix) prefix=${2:?"Missing value for --prefix"}; shift 2 ;;
    --cds-check) cds_check=${2:?"Missing value for --cds-check"}; shift 2 ;;
    --interproscan) interproscan=${2:?"Missing value for --interproscan"}; shift 2 ;;
    --iprscan-parsed) iprscan_parsed=${2:?"Missing value for --iprscan-parsed"}; shift 2 ;;
    --kofam-detail) kofam_detail=${2:?"Missing value for --kofam-detail"}; shift 2 ;;
    --kofam-parsed) kofam_parsed=${2:?"Missing value for --kofam-parsed"}; shift 2 ;;
    --eggnog) eggnog=${2:?"Missing value for --eggnog"}; shift 2 ;;
    --swissprot) swissprot=${2:?"Missing value for --swissprot"}; shift 2 ;;
    --nr) nr=${2:?"Missing value for --nr"}; shift 2 ;;
    --ko-map) ko_map=${2:?"Missing value for --ko-map"}; shift 2 ;;
    --pathway-names) pathway_names=${2:?"Missing value for --pathway-names"}; shift 2 ;;
    --pfam-map) pfam_map=${2:?"Missing value for --pfam-map"}; shift 2 ;;
    --foreground) foreground=${2:?"Missing value for --foreground"}; shift 2 ;;
    --background) background=${2:?"Missing value for --background"}; shift 2 ;;
    --enrichment-mode) enrichment_mode=${2:?"Missing value for --enrichment-mode"}; shift 2 ;;
    --enrichment-term-column) enrichment_term_column=${2:?"Missing value for --enrichment-term-column"}; shift 2 ;;
    --python) python_cmd=${2:?"Missing value for --python"}; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

for name in gff outdir; do
  value=${!name}
  if [[ -z "$value" ]]; then
    echo "Missing required --${name}" >&2
    usage >&2
    exit 1
  fi
done
if [[ ! -s "$gff" ]]; then
  echo "Missing or empty GFF: $gff" >&2
  exit 1
fi
for file in "$cds_check" "$interproscan" "$iprscan_parsed" "$kofam_detail" "$kofam_parsed" "$eggnog" "$swissprot" "$nr" "$ko_map" "$pathway_names" "$pfam_map" "$foreground" "$background"; do
  if [[ -n "$file" && ! -s "$file" ]]; then
    echo "Missing or empty input file: $file" >&2
    exit 1
  fi
done

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
outdir_abs=$(mkdir -p "$outdir" && readlink -f "$outdir")
prefix=${prefix:-$(basename "$gff")}
prefix=${prefix%.gff3}
prefix=${prefix%.gff}

if [[ -n "$interproscan" ]]; then
  iprscan_parsed="$outdir_abs/${prefix}.iprscan.xls"
  "$python_cmd" "$script_dir/parse_interproscan_tsv.py" --input "$interproscan" --out "$iprscan_parsed"
fi
if [[ -n "$kofam_detail" ]]; then
  kofam_parsed="$outdir_abs/${prefix}.kofam.tsv"
  "$python_cmd" "$script_dir/parse_kofam_detail.py" --input "$kofam_detail" --out "$kofam_parsed"
fi

merge_args=(--gff "$gff" --out "$outdir_abs/${prefix}.functional_annotation.tsv")
[[ -n "$cds_check" ]] && merge_args+=(--cds-check "$cds_check")
[[ -n "$iprscan_parsed" ]] && merge_args+=(--iprscan "$iprscan_parsed")
[[ -n "$eggnog" ]] && merge_args+=(--eggnog "$eggnog")
[[ -n "$kofam_parsed" ]] && merge_args+=(--kofam "$kofam_parsed")
[[ -n "$swissprot" ]] && merge_args+=(--swissprot "$swissprot")
[[ -n "$nr" ]] && merge_args+=(--nr "$nr")
"$python_cmd" "$script_dir/merge_function_annotations.py" "${merge_args[@]}"
annotation="$outdir_abs/${prefix}.functional_annotation.tsv"

"$python_cmd" "$script_dir/summarize_go_terms.py" \
  --annotation "$annotation" \
  --out "$outdir_abs/${prefix}.go.counts.tsv" \
  --gene2go "$outdir_abs/${prefix}.gene2go.tsv"

pfam_args=(--annotation "$annotation" --out "$outdir_abs/${prefix}.pfam.counts.tsv" --gene2pfam "$outdir_abs/${prefix}.gene2pfam.tsv")
[[ -n "$pfam_map" ]] && pfam_args+=(--pfam-map "$pfam_map")
"$python_cmd" "$script_dir/summarize_pfam_domains.py" "${pfam_args[@]}"

if [[ -n "$ko_map" ]]; then
  kegg_args=(--annotation "$annotation" --ko-map "$ko_map" --out "$outdir_abs/${prefix}.kegg.pathway_counts.tsv" --gene2pathway "$outdir_abs/${prefix}.gene2pathway.tsv" --unmapped "$outdir_abs/${prefix}.kegg.unmapped_ko.tsv")
  [[ -n "$pathway_names" ]] && kegg_args+=(--pathway-names "$pathway_names")
  "$python_cmd" "$script_dir/summarize_kegg_pathways.py" "${kegg_args[@]}"
fi

if [[ -n "$eggnog" ]]; then
  "$python_cmd" "$script_dir/summarize_eggnog_categories.py" \
    --eggnog "$eggnog" \
    --out "$outdir_abs/${prefix}.eggnog_category_summary.tsv" \
    --gene2category "$outdir_abs/${prefix}.gene2eggnog_category.tsv"
fi

if [[ -n "$iprscan_parsed" ]]; then
  "$python_cmd" "$script_dir/summarize_domain_architecture.py" \
    --iprscan "$iprscan_parsed" \
    --out "$outdir_abs/${prefix}.domain_architecture.tsv" \
    --summary "$outdir_abs/${prefix}.domain_architecture_summary.tsv"
fi

if [[ -n "$foreground" ]]; then
  enrich_args=(--annotation "$annotation" --foreground "$foreground" --mode "$enrichment_mode" --out "$outdir_abs/${prefix}.${enrichment_mode}.enrichment.tsv")
  [[ -n "$background" ]] && enrich_args+=(--background "$background")
  [[ -n "$enrichment_term_column" ]] && enrich_args+=(--term-column "$enrichment_term_column")
  "$python_cmd" "$script_dir/enrich_annotation_terms.py" "${enrich_args[@]}"
fi
