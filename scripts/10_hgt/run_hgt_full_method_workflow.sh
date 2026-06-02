#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run_hgt_full_method_workflow.sh --outdir hgt_full --prefix full41 [options]

Chain public Stage 10 HGT full-method handoffs:
  1. Optionally run DIAMOND NR taxonlist searches.
  2. Build Condition1/Condition2 species HGT candidate matrices.
  3. Prepare HGT gene--source lists and optional HGT-only peptide FASTA.
  4. Summarize M1 gene-centric or M2 family-centric HGT-driven node events.
  5. Prepare plot-ready species donor and node-event handoff tables.

Core options:
  --outdir DIR                         Output directory
  --prefix NAME                        Output prefix [hgt_full]
  --python CMD                         Python executable [python3]

Optional NR taxonlist search:
  --query FILE                         Protein FASTA query
  --diamond-db FILE                    DIAMOND NR database path or prefix
  --taxonlist NAME=TAXID               Taxonlist group; repeatable
  --diamond CMD                        DIAMOND executable [diamond]
  --threads INT                        Threads for DIAMOND [10]

Condition matrix input:
  --species-manifest FILE              TSV with species and rp_tsv/blast2hgt_rp_tsv columns
  --donor-groups NAMES                 External donor groups [bacteria,fungi,Metazoa,virus,archaea,other]
  --exclude-groups NAMES               Groups excluded from HGT calls [Plant,Viridiplantae,Rhodophyta,Glaucocystophyceae,unknown]
  --min-alien-index FLOAT              Minimum alien_index for Condition calls [0]
  --condition NAME                     Candidate set for downstream HGT OG input [Condition2]

HGT OG input preparation:
  --hgt-candidates FILE                HGT candidate TSV; repeatable. If omitted, generated <condition> candidates are used when available.
  --protein FILE                       Protein FASTA for optional HGT-only FASTA output; repeatable

HGT family event summary:
  --method m1|m2                       Run M1 gene-centric or M2 family-centric summary
  --count-all FILE                     ALL orthogroup count matrix
  --count-hgt FILE                     HGT orthogroup count matrix, recorded for M2 provenance
  --node-list FILE                     Node/species parent table
  --txt-hgt FILE                       Orthogroups.HGT.txt; defaults to --txt-hgt-generated if supplied
  --txt-all FILE                       Orthogroups.all.txt
  --min-hgt-ratio FLOAT                M1 HGT-family ratio cutoff [0.3]

Visualization handoff:
  --visualize                          Prepare species/node plot-ready handoff tables when inputs exist
  --condition-matrix FILE              Optional precomputed Condition matrix for visualization
  --event-summary FILE                 Optional M1/M2 summary TSV for visualization
  --source-breakdown FILE              Optional M1/M2 source breakdown TSV for visualization

  -h, --help                           Show this help
USAGE
}

outdir=""
prefix="hgt_full"
python_cmd="python3"
query=""
diamond_db=""
diamond_cmd="diamond"
threads=10
taxonlists=()
species_manifest=""
donor_groups="bacteria,fungi,Metazoa,virus,archaea,other"
exclude_groups="Plant,Viridiplantae,Rhodophyta,Glaucocystophyceae,unknown"
min_alien_index="0"
condition="Condition2"
hgt_candidates=()
proteins=()
method=""
count_all=""
count_hgt=""
node_list=""
txt_hgt=""
txt_all=""
min_hgt_ratio="0.3"
visualize=0
condition_matrix=""
event_summary=""
source_breakdown=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --outdir) outdir=${2:?"Missing value for --outdir"}; shift 2 ;;
    --prefix) prefix=${2:?"Missing value for --prefix"}; shift 2 ;;
    --python) python_cmd=${2:?"Missing value for --python"}; shift 2 ;;
    --query) query=${2:?"Missing value for --query"}; shift 2 ;;
    --diamond-db) diamond_db=${2:?"Missing value for --diamond-db"}; shift 2 ;;
    --taxonlist) taxonlists+=("${2:?"Missing value for --taxonlist"}"); shift 2 ;;
    --diamond) diamond_cmd=${2:?"Missing value for --diamond"}; shift 2 ;;
    --threads) threads=${2:?"Missing value for --threads"}; shift 2 ;;
    --species-manifest) species_manifest=${2:?"Missing value for --species-manifest"}; shift 2 ;;
    --donor-groups) donor_groups=${2:?"Missing value for --donor-groups"}; shift 2 ;;
    --exclude-groups) exclude_groups=${2:?"Missing value for --exclude-groups"}; shift 2 ;;
    --min-alien-index) min_alien_index=${2:?"Missing value for --min-alien-index"}; shift 2 ;;
    --condition) condition=${2:?"Missing value for --condition"}; shift 2 ;;
    --hgt-candidates) hgt_candidates+=("${2:?"Missing value for --hgt-candidates"}"); shift 2 ;;
    --protein) proteins+=("${2:?"Missing value for --protein"}"); shift 2 ;;
    --method) method=${2:?"Missing value for --method"}; shift 2 ;;
    --count-all) count_all=${2:?"Missing value for --count-all"}; shift 2 ;;
    --count-hgt) count_hgt=${2:?"Missing value for --count-hgt"}; shift 2 ;;
    --node-list) node_list=${2:?"Missing value for --node-list"}; shift 2 ;;
    --txt-hgt) txt_hgt=${2:?"Missing value for --txt-hgt"}; shift 2 ;;
    --txt-all) txt_all=${2:?"Missing value for --txt-all"}; shift 2 ;;
    --min-hgt-ratio) min_hgt_ratio=${2:?"Missing value for --min-hgt-ratio"}; shift 2 ;;
    --visualize) visualize=1; shift ;;
    --condition-matrix) condition_matrix=${2:?"Missing value for --condition-matrix"}; shift 2 ;;
    --event-summary) event_summary=${2:?"Missing value for --event-summary"}; shift 2 ;;
    --source-breakdown) source_breakdown=${2:?"Missing value for --source-breakdown"}; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ -z "$outdir" ]]; then
  echo "Missing required --outdir" >&2
  usage >&2
  exit 1
fi
if ! command -v "$python_cmd" >/dev/null 2>&1; then
  echo "Python executable not found: $python_cmd" >&2
  exit 1
fi

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
outdir_abs=$(mkdir -p "$outdir" && readlink -f "$outdir")
manifest="$outdir_abs/${prefix}.hgt_full_method_manifest.tsv"
steps=()

if [[ -n "$query" || -n "$diamond_db" || ${#taxonlists[@]} -gt 0 ]]; then
  if [[ -z "$query" || -z "$diamond_db" || ${#taxonlists[@]} -eq 0 ]]; then
    echo "NR search requires --query, --diamond-db, and at least one --taxonlist" >&2
    exit 1
  fi
  nr_args=(--query "$query" --diamond-db "$diamond_db" --outdir "$outdir_abs/nr_taxonlist" --prefix "$prefix" --diamond "$diamond_cmd" --threads "$threads")
  for item in "${taxonlists[@]}"; do
    nr_args+=(--taxonlist "$item")
  done
  bash "$script_dir/run_hgt_nr_taxonlist_workflow.sh" "${nr_args[@]}"
  steps+=("nr_taxonlist")
fi

if [[ -n "$species_manifest" ]]; then
  "$python_cmd" "$script_dir/build_hgt_condition_matrices.py" \
    --species-manifest "$species_manifest" \
    --outdir "$outdir_abs/condition_matrices" \
    --prefix "$prefix" \
    --donor-groups "$donor_groups" \
    --exclude-groups "$exclude_groups" \
    --min-alien-index "$min_alien_index"
  steps+=("condition_matrices")
  generated_candidates="$outdir_abs/condition_matrices/${condition}_HGT_candidates.tsv"
  generated_matrix="$outdir_abs/condition_matrices/${condition}_$( [[ "$condition" == "Condition1" ]] && printf 'AI_taxon' || printf 'Matching_taxon' )_counts_matrix.tsv"
  if [[ ${#hgt_candidates[@]} -eq 0 && -s "$generated_candidates" ]]; then
    hgt_candidates+=("$generated_candidates")
  fi
  if [[ -z "$condition_matrix" && -s "$generated_matrix" ]]; then
    condition_matrix="$generated_matrix"
  fi
fi

if [[ ${#hgt_candidates[@]} -gt 0 ]]; then
  og_args=(--outdir "$outdir_abs/hgt_orthogroup_inputs" --prefix "$prefix")
  for file in "${hgt_candidates[@]}"; do
    og_args+=(--candidates "$file")
  done
  for fasta in "${proteins[@]}"; do
    og_args+=(--protein "$fasta")
  done
  "$python_cmd" "$script_dir/prepare_hgt_orthogroup_inputs.py" "${og_args[@]}"
  steps+=("hgt_orthogroup_inputs")
fi

if [[ -n "$method" ]]; then
  for name in count_all node_list txt_all; do
    value=${!name}
    if [[ -z "$value" ]]; then
      echo "HGT event summary requires --$([[ "$name" == count_all ]] && printf 'count-all' || [[ "$name" == node_list ]] && printf 'node-list' || printf 'txt-all')" >&2
      exit 1
    fi
  done
  if [[ -z "$txt_hgt" ]]; then
    echo "HGT event summary requires --txt-hgt" >&2
    exit 1
  fi
  event_args=(--method "$method" --count-all "$count_all" --node-list "$node_list" --txt-hgt "$txt_hgt" --txt-all "$txt_all" --outdir "$outdir_abs/hgt_family_events" --min-hgt-ratio "$min_hgt_ratio")
  [[ -n "$count_hgt" ]] && event_args+=(--count-hgt "$count_hgt")
  "$python_cmd" "$script_dir/summarize_hgt_family_events.py" "${event_args[@]}"
  steps+=("hgt_family_events")
  method_prefix="M1"
  [[ "$method" == "m2" ]] && method_prefix="M2"
  [[ -z "$event_summary" ]] && event_summary="$outdir_abs/hgt_family_events/${method_prefix}_Summary_Evolution.tsv"
  [[ -z "$source_breakdown" ]] && source_breakdown="$outdir_abs/hgt_family_events/${method_prefix}_HGT_Source_Breakdown.tsv"
fi

if [[ "$visualize" -eq 1 ]]; then
  viz_args=(--outdir "$outdir_abs/hgt_visualization" --prefix "$prefix")
  [[ -n "$condition_matrix" ]] && viz_args+=(--condition-matrix "$condition_matrix")
  [[ -n "$event_summary" ]] && viz_args+=(--event-summary "$event_summary")
  [[ -n "$source_breakdown" ]] && viz_args+=(--source-breakdown "$source_breakdown")
  "$python_cmd" "$script_dir/prepare_hgt_visualization_handoff.py" "${viz_args[@]}"
  steps+=("hgt_visualization")
fi

{
  printf 'field\tvalue\n'
  printf 'prefix\t%s\n' "$prefix"
  printf 'outdir\t%s\n' "$outdir_abs"
  printf 'steps\t%s\n' "${steps[*]:-none}"
  printf 'species_manifest\t%s\n' "${species_manifest:-NA}"
  printf 'donor_groups\t%s\n' "$donor_groups"
  printf 'condition\t%s\n' "$condition"
  printf 'hgt_candidates\t%s\n' "${hgt_candidates[*]:-NA}"
  printf 'method\t%s\n' "${method:-NA}"
  printf 'visualize\t%s\n' "$visualize"
} > "$manifest"
