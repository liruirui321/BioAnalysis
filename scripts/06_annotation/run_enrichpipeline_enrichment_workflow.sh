#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run_enrichpipeline_enrichment_workflow.sh --enrichpipeline-dir EnrichPipeline --class GO --supply genes.id --outdir enrich_out [options]

Run a local EnrichPipeline enrichment handoff without vendoring the EnrichPipeline archive or databases.
The external EnrichPipeline directory, MetaGO/GOdata/mapGene/IPR resources, and gene lists stay outside this repository.

Required:
  --enrichpipeline-dir DIR   External EnrichPipeline root directory
  --class GO|KEGG|IPR        Enrichment class passed to --cls
  --supply FILE              Foreground gene list passed to --supplyF
  --outdir DIR               Output directory

Class-specific inputs:
  GO:   provide --wego FILE and --metago FILE to build GOdata, or provide --godata FILE
  KEGG: provide --map-gene FILE
  IPR:  provide --ipr2gene FILE

Options:
  --supply2 FILE             Second gene list passed to --supplyF2
  --prefix NAME              Output prefix for manifest/runtime [enrichpipeline]
  --perl CMD                 Perl executable [perl]
  --p-adjust-method NAME     EnrichPipeline --P_Adjust_Method value
  --test-method NAME         EnrichPipeline --TestMethod value
  --build-godata             For GO, first build GOdata.RData from --wego and --metago
  --enrich-option TEXT       Additional EnrichPipeline.pl option; repeatable
  -h, --help                 Show this help

Outputs:
  <outdir>/<class-specific EnrichPipeline outputs>
  <outdir>/<prefix>.enrichpipeline_running_time.txt
  <outdir>/<prefix>.enrichpipeline_manifest.tsv
USAGE
}

enrichpipeline_dir=""
cls=""
supply=""
supply2=""
outdir=""
prefix="enrichpipeline"
perl_cmd="perl"
wego=""
metago=""
godata=""
map_gene=""
ipr2gene=""
p_adjust=""
test_method=""
build_godata=0
enrich_options=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --enrichpipeline-dir) enrichpipeline_dir=${2:?"Missing value for --enrichpipeline-dir"}; shift 2 ;;
    --class) cls=${2:?"Missing value for --class"}; shift 2 ;;
    --supply) supply=${2:?"Missing value for --supply"}; shift 2 ;;
    --supply2) supply2=${2:?"Missing value for --supply2"}; shift 2 ;;
    --outdir) outdir=${2:?"Missing value for --outdir"}; shift 2 ;;
    --prefix) prefix=${2:?"Missing value for --prefix"}; shift 2 ;;
    --perl) perl_cmd=${2:?"Missing value for --perl"}; shift 2 ;;
    --wego) wego=${2:?"Missing value for --wego"}; shift 2 ;;
    --metago) metago=${2:?"Missing value for --metago"}; shift 2 ;;
    --godata) godata=${2:?"Missing value for --godata"}; shift 2 ;;
    --map-gene) map_gene=${2:?"Missing value for --map-gene"}; shift 2 ;;
    --ipr2gene) ipr2gene=${2:?"Missing value for --ipr2gene"}; shift 2 ;;
    --p-adjust-method) p_adjust=${2:?"Missing value for --p-adjust-method"}; shift 2 ;;
    --test-method) test_method=${2:?"Missing value for --test-method"}; shift 2 ;;
    --build-godata) build_godata=1; shift ;;
    --enrich-option) enrich_options+=("${2:?"Missing value for --enrich-option"}"); shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

for name in enrichpipeline_dir cls supply outdir; do
  value=${!name}
  if [[ -z "$value" ]]; then
    echo "Missing required --${name//_/-}" >&2
    usage >&2
    exit 1
  fi
done
case "$cls" in
  GO|KEGG|IPR) ;;
  *) echo "--class must be GO, KEGG, or IPR" >&2; exit 1 ;;
esac
if [[ ! -d "$enrichpipeline_dir" ]]; then
  echo "Missing EnrichPipeline directory: $enrichpipeline_dir" >&2
  exit 1
fi
pipeline_pl="$enrichpipeline_dir/enrichment/bin/EnrichPipeline.pl"
if [[ ! -s "$pipeline_pl" ]]; then
  echo "Missing EnrichPipeline.pl: $pipeline_pl" >&2
  exit 1
fi
for file in "$supply" "$supply2" "$wego" "$metago" "$godata" "$map_gene" "$ipr2gene"; do
  if [[ -n "$file" && ! -s "$file" ]]; then
    echo "Missing or empty input file: $file" >&2
    exit 1
  fi
done
if ! command -v "$perl_cmd" >/dev/null 2>&1; then
  echo "Perl executable not found: $perl_cmd" >&2
  exit 1
fi

case "$cls" in
  GO)
    if [[ -z "$godata" ]]; then
      if [[ -z "$wego" || -z "$metago" ]]; then
        echo "GO enrichment requires --godata or both --wego and --metago" >&2
        exit 1
      fi
      build_godata=1
    fi
    ;;
  KEGG)
    [[ -n "$map_gene" ]] || { echo "KEGG enrichment requires --map-gene" >&2; exit 1; }
    ;;
  IPR)
    [[ -n "$ipr2gene" ]] || { echo "IPR enrichment requires --ipr2gene" >&2; exit 1; }
    ;;
esac

enrichpipeline_abs=$(readlink -f "$enrichpipeline_dir")
outdir_abs=$(mkdir -p "$outdir" && readlink -f "$outdir")
runtime_log="$outdir_abs/${prefix}.enrichpipeline_running_time.txt"
manifest="$outdir_abs/${prefix}.enrichpipeline_manifest.tsv"

enrich_args=(--cls "$cls" --supplyF "$(readlink -f "$supply")" --outDir "$outdir_abs")
[[ -n "$supply2" ]] && enrich_args+=(--supplyF2 "$(readlink -f "$supply2")")
[[ -n "$p_adjust" ]] && enrich_args+=(--P_Adjust_Method "$p_adjust")
[[ -n "$test_method" ]] && enrich_args+=(--TestMethod "$test_method")
enrich_args+=("${enrich_options[@]}")

{
  printf '[%s] Workflow started\n' "$(date)"
  start=$(date +%s)
  if [[ "$cls" == "GO" && "$build_godata" -eq 1 ]]; then
    godata_out="$outdir_abs/${prefix}.GOdata.RData"
    "$perl_cmd" "$pipeline_pl" \
      --cls GO \
      --MetaGO "$(readlink -f "$metago")" \
      --wegoF "$(readlink -f "$wego")" \
      --outDir "$outdir_abs/${prefix}.GOdata" \
      --GOdata_outF "$godata_out"
    godata="$godata_out"
  fi
  case "$cls" in
    GO) enrich_args+=(--GOdata "$(readlink -f "$godata")") ;;
    KEGG) enrich_args+=(--mapGene "$(readlink -f "$map_gene")") ;;
    IPR) enrich_args+=(--ipr2geneF "$(readlink -f "$ipr2gene")") ;;
  esac
  "$perl_cmd" "$pipeline_pl" "${enrich_args[@]}"
  printf '[%s] Duration: %.6f hours\n' "$(date)" "$(awk -v s=$(($(date +%s) - start)) 'BEGIN {print s/3600}')"
} | tee "$runtime_log"

{
  printf 'field\tvalue\n'
  printf 'enrichpipeline_dir\t%s\n' "$enrichpipeline_abs"
  printf 'class\t%s\n' "$cls"
  printf 'supply\t%s\n' "$(readlink -f "$supply")"
  printf 'supply2\t%s\n' "${supply2:-NA}"
  printf 'outdir\t%s\n' "$outdir_abs"
  printf 'wego\t%s\n' "${wego:-NA}"
  printf 'metago\t%s\n' "${metago:-NA}"
  printf 'godata\t%s\n' "${godata:-NA}"
  printf 'map_gene\t%s\n' "${map_gene:-NA}"
  printf 'ipr2gene\t%s\n' "${ipr2gene:-NA}"
  printf 'p_adjust_method\t%s\n' "${p_adjust:-NA}"
  printf 'test_method\t%s\n' "${test_method:-NA}"
  printf 'runtime_log\t%s\n' "$runtime_log"
} > "$manifest"
