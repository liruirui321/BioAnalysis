#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run_repeat_annotation_workflow.sh --genome genome.fa --outdir repeat_work [options]

Chain the Stage 03 repeat annotation workflow:
  1. Create an uppercase genome FASTA for repeat tools.
  2. Run LTR_FINDER_parallel and LTRharvest.
  3. Run RepeatModeler.
  4. Merge LTR candidates and run LTR_retriever.
  5. Run TRF and optional GFF conversion.
  6. Optionally convert RepeatMasker .out to GFF3 and summarize repeat coverage.

Required:
  --genome FILE             Input genome FASTA
  --outdir DIR              Output directory

Options:
  --prefix NAME             Output prefix [genome basename without .fa/.fasta]
  --threads INT             General thread count [20]
  --ltr-finder-threads INT  LTR_FINDER_parallel threads [threads]
  --ltr-retriever-threads INT LTR_retriever threads [12]
  --repeatmodeler-db NAME   RepeatModeler database name [<prefix>_repeatmodeler]
  --genome-size INT         Genome size for repeat_stat.sh when --repeatmasker-out is supplied
  --repeatmasker-out FILE   Existing RepeatMasker .out file to convert/summarize
  --trf-args STRING         TRF parameter string [2 5 7 80 10 50 2000]
  --run-lai                 Run LAI inside LTR_retriever wrapper when available
  --skip-ltr-finder         Skip LTR_FINDER_parallel
  --skip-ltr-harvest        Skip LTRharvest
  --skip-repeatmodeler      Skip RepeatModeler
  --skip-ltr-retriever      Skip LTR_retriever merge step
  --skip-trf                Skip TRF
  --skip-trf-gff            Run TRF but skip trf2gff conversion
  -h, --help                Show this help
USAGE
}

genome=""
outdir=""
prefix=""
threads=20
ltr_finder_threads=""
ltr_retriever_threads=12
repeatmodeler_db=""
genome_size=""
repeatmasker_out=""
trf_args="2 5 7 80 10 50 2000"
run_lai=0
skip_ltr_finder=0
skip_ltr_harvest=0
skip_repeatmodeler=0
skip_ltr_retriever=0
skip_trf=0
skip_trf_gff=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --genome) genome=${2:?"Missing value for --genome"}; shift 2 ;;
    --outdir) outdir=${2:?"Missing value for --outdir"}; shift 2 ;;
    --prefix) prefix=${2:?"Missing value for --prefix"}; shift 2 ;;
    --threads) threads=${2:?"Missing value for --threads"}; shift 2 ;;
    --ltr-finder-threads) ltr_finder_threads=${2:?"Missing value for --ltr-finder-threads"}; shift 2 ;;
    --ltr-retriever-threads) ltr_retriever_threads=${2:?"Missing value for --ltr-retriever-threads"}; shift 2 ;;
    --repeatmodeler-db) repeatmodeler_db=${2:?"Missing value for --repeatmodeler-db"}; shift 2 ;;
    --genome-size) genome_size=${2:?"Missing value for --genome-size"}; shift 2 ;;
    --repeatmasker-out) repeatmasker_out=${2:?"Missing value for --repeatmasker-out"}; shift 2 ;;
    --trf-args) trf_args=${2:?"Missing value for --trf-args"}; shift 2 ;;
    --run-lai) run_lai=1; shift ;;
    --skip-ltr-finder) skip_ltr_finder=1; shift ;;
    --skip-ltr-harvest) skip_ltr_harvest=1; shift ;;
    --skip-repeatmodeler) skip_repeatmodeler=1; shift ;;
    --skip-ltr-retriever) skip_ltr_retriever=1; shift ;;
    --skip-trf) skip_trf=1; shift ;;
    --skip-trf-gff) skip_trf_gff=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

for name in genome outdir; do
  value=${!name}
  if [[ -z "$value" ]]; then
    echo "Missing required --${name}" >&2
    usage >&2
    exit 1
  fi
done
if [[ ! -s "$genome" ]]; then
  echo "Missing or empty genome FASTA: $genome" >&2
  exit 1
fi
if [[ -n "$repeatmasker_out" && ! -s "$repeatmasker_out" ]]; then
  echo "Missing or empty RepeatMasker output: $repeatmasker_out" >&2
  exit 1
fi
if [[ -n "$repeatmasker_out" && -z "$genome_size" ]]; then
  echo "--genome-size is required when --repeatmasker-out is supplied" >&2
  exit 1
fi

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
outdir_abs=$(mkdir -p "$outdir" && readlink -f "$outdir")
genome_abs=$(readlink -f "$genome")
prefix=${prefix:-$(basename "$genome")}
prefix=${prefix%.fasta}
prefix=${prefix%.fa}
ltr_finder_threads=${ltr_finder_threads:-$threads}
repeatmodeler_db=${repeatmodeler_db:-${prefix}_repeatmodeler}
upper_genome="$outdir_abs/${prefix}.genome.upper.fa"

python3 - "$genome_abs" "$upper_genome" <<'PY'
from pathlib import Path
import sys
src = Path(sys.argv[1])
out = Path(sys.argv[2])
with src.open() as inp, out.open('w') as handle:
    for line in inp:
        if line.startswith('>'):
            handle.write(line)
        else:
            handle.write(line.upper())
PY

if [[ "$skip_ltr_finder" -eq 0 ]]; then
  bash "$script_dir/LTR_Finder.sh" --genome "$upper_genome" --threads "$ltr_finder_threads"
fi

harvest_scn="$outdir_abs/${prefix}.genome.upper.fa.harvest.scn"
if [[ "$skip_ltr_harvest" -eq 0 ]]; then
  bash "$script_dir/LTR_harvest.sh" --genome "$upper_genome" --index-prefix "$upper_genome" --out "$harvest_scn"
fi

if [[ "$skip_repeatmodeler" -eq 0 ]]; then
  (cd "$outdir_abs" && bash "$script_dir/repeatmodeler.sh" --genome "$upper_genome" --database "$repeatmodeler_db" --threads "$threads" --log "${prefix}.repeatmodeler.BuildDatabase.log" --out "${prefix}.repeatmodeler.run.out")
fi

finder_scn="${upper_genome}.finder.combine.scn"
if [[ "$skip_ltr_retriever" -eq 0 ]]; then
  if [[ ! -s "$harvest_scn" ]]; then
    echo "Missing LTRharvest SCN for LTR_retriever: $harvest_scn" >&2
    exit 1
  fi
  if [[ ! -s "$finder_scn" ]]; then
    echo "Missing LTR_FINDER SCN for LTR_retriever: $finder_scn" >&2
    exit 1
  fi
  lai_arg=()
  [[ "$run_lai" -eq 1 ]] && lai_arg+=(--run-lai)
  bash "$script_dir/work.sh" --genome "$upper_genome" --harvest "$harvest_scn" --finder "$finder_scn" --threads "$ltr_retriever_threads" --raw-ltr "$outdir_abs/${prefix}.rawLTR.scn" "${lai_arg[@]}"
fi

if [[ "$skip_trf" -eq 0 ]]; then
  trf_args_extra=()
  [[ "$skip_trf_gff" -eq 1 ]] && trf_args_extra+=(--skip-gff)
  bash "$script_dir/trf.sh" --genome "$upper_genome" --out-prefix "$outdir_abs/${prefix}.trf" --trf-args "$trf_args" --gff "$outdir_abs/${prefix}.trf.gff3" "${trf_args_extra[@]}"
fi

if [[ -n "$repeatmasker_out" ]]; then
  bash "$script_dir/rmout2gff.sh" "$repeatmasker_out" > "$outdir_abs/${prefix}.repeatmasker.all.gff3"
  bash "$script_dir/repeat_stat.sh" "$repeatmasker_out" "$genome_size" "$outdir_abs/${prefix}.repeat.summary.tsv"
fi
