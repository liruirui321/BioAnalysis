#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run_hifiasm_assembly.sh --hifi reads.fa --outdir hifiasm_assembly [options]

Run an independent Stage 02 hifiasm assembly workflow:
  1. Optionally filter HiFi reads by minimum length with seqkit.
  2. Run hifiasm with optional native Hi-C read pairs.
  3. Extract primary contig FASTA from hifiasm GFA output.
  4. Write stable assembly statistics.

Required:
  --hifi FILE                  HiFi read FASTA/FASTQ; repeatable
  --outdir DIR                 Output directory

Options:
  --prefix NAME                Output prefix [first HiFi basename]
  --threads INT                hifiasm threads [32]
  --hic-r1 FILE                Optional Hi-C read 1 passed to hifiasm --h1
  --hic-r2 FILE                Optional Hi-C read 2 passed to hifiasm --h2
  --hom-cov VALUE              Optional hifiasm --hom-cov value
  --min-length INT             Filter HiFi reads to minimum length with seqkit before assembly
  --hifiasm CMD                hifiasm executable [hifiasm]
  --seqkit CMD                 seqkit executable [seqkit]
  --python CMD                 Python executable [python3]
  --hifiasm-option TEXT        Additional hifiasm option string; repeatable
  --skip-assembly-stats        Skip assembly_stats.py handoff
  -h, --help                   Show this help
USAGE
}

hifi_reads=()
outdir=""
prefix=""
threads=32
hic_r1=""
hic_r2=""
hom_cov=""
min_length=""
hifiasm_cmd="hifiasm"
seqkit_cmd="seqkit"
python_cmd="python3"
skip_assembly_stats=0
hifiasm_options=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --hifi) hifi_reads+=("${2:?"Missing value for --hifi"}"); shift 2 ;;
    --outdir) outdir=${2:?"Missing value for --outdir"}; shift 2 ;;
    --prefix) prefix=${2:?"Missing value for --prefix"}; shift 2 ;;
    --threads) threads=${2:?"Missing value for --threads"}; shift 2 ;;
    --hic-r1) hic_r1=${2:?"Missing value for --hic-r1"}; shift 2 ;;
    --hic-r2) hic_r2=${2:?"Missing value for --hic-r2"}; shift 2 ;;
    --hom-cov) hom_cov=${2:?"Missing value for --hom-cov"}; shift 2 ;;
    --min-length) min_length=${2:?"Missing value for --min-length"}; shift 2 ;;
    --hifiasm) hifiasm_cmd=${2:?"Missing value for --hifiasm"}; shift 2 ;;
    --seqkit) seqkit_cmd=${2:?"Missing value for --seqkit"}; shift 2 ;;
    --python) python_cmd=${2:?"Missing value for --python"}; shift 2 ;;
    --hifiasm-option) hifiasm_options+=("${2:?"Missing value for --hifiasm-option"}"); shift 2 ;;
    --skip-assembly-stats) skip_assembly_stats=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ ${#hifi_reads[@]} -eq 0 || -z "$outdir" ]]; then
  echo "Missing required --hifi or --outdir" >&2
  usage >&2
  exit 1
fi
if [[ ! "$threads" =~ ^[0-9]+$ || "$threads" -lt 1 ]]; then
  echo "--threads must be a positive integer" >&2
  exit 1
fi
if [[ -n "$min_length" && (! "$min_length" =~ ^[0-9]+$ || "$min_length" -lt 1) ]]; then
  echo "--min-length must be a positive integer" >&2
  exit 1
fi
if [[ -n "$hic_r1" || -n "$hic_r2" ]]; then
  if [[ -z "$hic_r1" || -z "$hic_r2" ]]; then
    echo "Provide --hic-r1 and --hic-r2 together" >&2
    exit 1
  fi
fi
for file in "${hifi_reads[@]}" "$hic_r1" "$hic_r2"; do
  [[ -z "$file" ]] && continue
  if [[ ! -s "$file" ]]; then
    echo "Missing or empty input file: $file" >&2
    exit 1
  fi
done
if ! command -v "$hifiasm_cmd" >/dev/null 2>&1; then
  echo "hifiasm executable not found: $hifiasm_cmd" >&2
  exit 1
fi
if [[ -n "$min_length" ]] && ! command -v "$seqkit_cmd" >/dev/null 2>&1; then
  echo "seqkit executable not found: $seqkit_cmd" >&2
  exit 1
fi

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
outdir_abs=$(mkdir -p "$outdir" && readlink -f "$outdir")
if [[ -z "$prefix" ]]; then
  prefix=$(basename "${hifi_reads[0]}")
  prefix=${prefix%.gz}
  prefix=${prefix%.fasta}
  prefix=${prefix%.fastq}
  prefix=${prefix%.fa}
  prefix=${prefix%.fq}
fi
workdir="$outdir_abs/${prefix}.hifiasm_work"
mkdir -p "$workdir"

hifi_abs=()
for file in "${hifi_reads[@]}"; do
  hifi_abs+=("$(readlink -f "$file")")
done
hic_args=()
if [[ -n "$hic_r1" ]]; then
  hic_args=(--h1 "$(readlink -f "$hic_r1")" --h2 "$(readlink -f "$hic_r2")")
fi

assembly_input=()
if [[ -n "$min_length" ]]; then
  filtered="$workdir/${prefix}.hifi.min${min_length}.fa"
  : > "$filtered"
  for file in "${hifi_abs[@]}"; do
    "$seqkit_cmd" seq -m "$min_length" "$file" >> "$filtered"
  done
  assembly_input=("$filtered")
else
  assembly_input=("${hifi_abs[@]}")
fi

(
  cd "$workdir"
  hifiasm_args=(-o "$prefix" -t "$threads")
  [[ -n "$hom_cov" ]] && hifiasm_args+=(--hom-cov "$hom_cov")
  hifiasm_args+=("${hic_args[@]}")
  for option in "${hifiasm_options[@]}"; do
    read -r -a option_parts <<< "$option"
    hifiasm_args+=("${option_parts[@]}")
  done
  hifiasm_args+=("${assembly_input[@]}")
  "$hifiasm_cmd" "${hifiasm_args[@]}" 2> "${prefix}.hifiasm.log"
)

candidate_gfas=(
  "$workdir/${prefix}.hic.p_ctg.gfa"
  "$workdir/${prefix}.bp.p_ctg.gfa"
  "$workdir/${prefix}.p_ctg.gfa"
)
gfa=""
for candidate in "${candidate_gfas[@]}"; do
  if [[ -s "$candidate" ]]; then
    gfa="$candidate"
    break
  fi
done
if [[ -z "$gfa" ]]; then
  echo "No hifiasm primary-contig GFA found. Checked: ${candidate_gfas[*]}" >&2
  exit 1
fi
assembly_fa="$outdir_abs/${prefix}.hifiasm.assembly.fa"
awk '/^S\t/ {print ">"$2"\n"$3}' "$gfa" > "$assembly_fa"
if [[ ! -s "$assembly_fa" ]]; then
  echo "Failed to extract hifiasm assembly FASTA from: $gfa" >&2
  exit 1
fi

if [[ "$skip_assembly_stats" -eq 0 ]]; then
  "$python_cmd" "$script_dir/assembly_stats.py" \
    --fasta "$assembly_fa" \
    --out "$outdir_abs/${prefix}.hifiasm.assembly_stats.tsv" \
    --lengths "$outdir_abs/${prefix}.hifiasm.assembly_lengths.tsv"
fi
