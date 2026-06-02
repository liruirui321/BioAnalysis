#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run_braker3_annotation_workflow.sh --genome genome.fa --proteins proteins.fa --rnaseq-bam aln.bam --species Species_name --outdir braker3_work [options]

Run an independent Stage 04 BRAKER3 gene prediction workflow:
  1. Prepare optional writable AUGUSTUS config in the work directory.
  2. Run BRAKER3 with protein evidence and RNA-seq BAM evidence.
  3. Expose stable annotation handoff files without running downstream GFF cleanup.

Required:
  --genome FILE                    Soft-masked genome FASTA
  --proteins FILE                  Protein evidence FASTA
  --rnaseq-bam FILE                RNA-seq BAM evidence; repeatable
  --species NAME                   BRAKER species/training name
  --outdir DIR                     Output directory

Options:
  --prefix NAME                    Output prefix [species]
  --rounds INT                     BRAKER training rounds [20]
  --threads INT                    Threads [20]
  --memory-note TEXT               Memory note for manifest only
  --add-utr                        Pass --addUTR=on to BRAKER
  --braker CMD                     BRAKER executable [braker.pl]
  --samtools CMD                   samtools executable for BAM quickcheck [samtools]
  --augustus-config-source DIR     Copy writable AUGUSTUS config from this directory
  --augustus-config-path DIR       Use this AUGUSTUS config path directly
  --augustus-bin-path DIR          Pass --AUGUSTUS_BIN_PATH
  --augustus-scripts-path DIR      Pass --AUGUSTUS_SCRIPTS_PATH
  --bamtools-path DIR              Pass --BAMTOOLS_PATH
  --samtools-path DIR              Pass --SAMTOOLS_PATH
  --diamond-path DIR               Pass --DIAMOND_PATH
  --cdbtools-path DIR              Pass --CDBTOOLS_PATH
  --prothint-path DIR              Pass --PROTHINT_PATH
  --tsebra-path DIR                Pass --TSEBRA_PATH
  --genemark-path DIR              Pass --GENEMARK_PATH
  --braker-option TEXT             Additional BRAKER option string; repeatable
  -h, --help                       Show this help
USAGE
}

genome=""
proteins=""
rnaseq_bams=()
species=""
outdir=""
prefix=""
rounds=20
threads=20
memory_note="NA"
add_utr=0
braker_cmd="braker.pl"
samtools_cmd="samtools"
augustus_config_source=""
augustus_config_path=""
augustus_bin_path=""
augustus_scripts_path=""
bamtools_path=""
samtools_path=""
diamond_path=""
cdbtools_path=""
prothint_path=""
tsebra_path=""
genemark_path=""
braker_options=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --genome) genome=${2:?"Missing value for --genome"}; shift 2 ;;
    --proteins) proteins=${2:?"Missing value for --proteins"}; shift 2 ;;
    --rnaseq-bam) rnaseq_bams+=("${2:?"Missing value for --rnaseq-bam"}"); shift 2 ;;
    --species) species=${2:?"Missing value for --species"}; shift 2 ;;
    --outdir) outdir=${2:?"Missing value for --outdir"}; shift 2 ;;
    --prefix) prefix=${2:?"Missing value for --prefix"}; shift 2 ;;
    --rounds) rounds=${2:?"Missing value for --rounds"}; shift 2 ;;
    --threads) threads=${2:?"Missing value for --threads"}; shift 2 ;;
    --memory-note) memory_note=${2:?"Missing value for --memory-note"}; shift 2 ;;
    --add-utr) add_utr=1; shift ;;
    --braker) braker_cmd=${2:?"Missing value for --braker"}; shift 2 ;;
    --samtools) samtools_cmd=${2:?"Missing value for --samtools"}; shift 2 ;;
    --augustus-config-source) augustus_config_source=${2:?"Missing value for --augustus-config-source"}; shift 2 ;;
    --augustus-config-path) augustus_config_path=${2:?"Missing value for --augustus-config-path"}; shift 2 ;;
    --augustus-bin-path) augustus_bin_path=${2:?"Missing value for --augustus-bin-path"}; shift 2 ;;
    --augustus-scripts-path) augustus_scripts_path=${2:?"Missing value for --augustus-scripts-path"}; shift 2 ;;
    --bamtools-path) bamtools_path=${2:?"Missing value for --bamtools-path"}; shift 2 ;;
    --samtools-path) samtools_path=${2:?"Missing value for --samtools-path"}; shift 2 ;;
    --diamond-path) diamond_path=${2:?"Missing value for --diamond-path"}; shift 2 ;;
    --cdbtools-path) cdbtools_path=${2:?"Missing value for --cdbtools-path"}; shift 2 ;;
    --prothint-path) prothint_path=${2:?"Missing value for --prothint-path"}; shift 2 ;;
    --tsebra-path) tsebra_path=${2:?"Missing value for --tsebra-path"}; shift 2 ;;
    --genemark-path) genemark_path=${2:?"Missing value for --genemark-path"}; shift 2 ;;
    --braker-option) braker_options+=("${2:?"Missing value for --braker-option"}"); shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ -z "$genome" || -z "$proteins" || ${#rnaseq_bams[@]} -eq 0 || -z "$species" || -z "$outdir" ]]; then
  echo "Missing required BRAKER input" >&2
  usage >&2
  exit 1
fi
for value_name in rounds threads; do
  value=${!value_name}
  if [[ ! "$value" =~ ^[0-9]+$ || "$value" -lt 1 ]]; then
    echo "--${value_name//_/-} must be a positive integer" >&2
    exit 1
  fi
done
if [[ ! -s "$genome" ]]; then
  echo "Missing or empty genome FASTA: $genome" >&2
  exit 1
fi
if [[ ! -s "$proteins" ]]; then
  echo "Missing or empty protein FASTA: $proteins" >&2
  exit 1
fi
for bam in "${rnaseq_bams[@]}"; do
  if [[ ! -s "$bam" ]]; then
    echo "Missing or empty RNA-seq BAM: $bam" >&2
    exit 1
  fi
done
if [[ -n "$augustus_config_source" && -n "$augustus_config_path" ]]; then
  echo "Use only one of --augustus-config-source or --augustus-config-path" >&2
  exit 1
fi
for path in "$augustus_config_source" "$augustus_config_path" "$augustus_bin_path" "$augustus_scripts_path" "$bamtools_path" "$samtools_path" "$diamond_path" "$cdbtools_path" "$prothint_path" "$tsebra_path"; do
  if [[ -n "$path" && ! -d "$path" ]]; then
    echo "Missing directory: $path" >&2
    exit 1
  fi
done
if [[ -n "$genemark_path" && ! -d "$genemark_path" && ! -x "$genemark_path" ]]; then
  echo "Missing GeneMark path: $genemark_path" >&2
  exit 1
fi
if ! command -v "$braker_cmd" >/dev/null 2>&1; then
  echo "BRAKER executable not found: $braker_cmd" >&2
  exit 1
fi
if command -v "$samtools_cmd" >/dev/null 2>&1; then
  for bam in "${rnaseq_bams[@]}"; do
    "$samtools_cmd" quickcheck "$bam"
  done
fi

prefix=${prefix:-$species}
outdir_abs=$(mkdir -p "$outdir" && readlink -f "$outdir")
workdir="$outdir_abs/${prefix}.braker3_work"
mkdir -p "$workdir"

genome_abs=$(readlink -f "$genome")
proteins_abs=$(readlink -f "$proteins")
bam_abs=()
for bam in "${rnaseq_bams[@]}"; do
  bam_abs+=("$(readlink -f "$bam")")
done
bam_csv=$(IFS=,; printf '%s' "${bam_abs[*]}")

resolved_augustus_config="$augustus_config_path"
if [[ -n "$augustus_config_source" ]]; then
  resolved_augustus_config="$workdir/augustus_config"
  rm -rf "$resolved_augustus_config"
  cp -r "$augustus_config_source" "$resolved_augustus_config"
fi

braker_args=(
  --genome="$genome_abs"
  --species="$species"
  --prot_seq="$proteins_abs"
  --bam="$bam_csv"
  --gff3
  --threads "$threads"
  --softmasking
  --rounds="$rounds"
  --workingdir="$workdir/braker"
)
[[ "$add_utr" -eq 1 ]] && braker_args+=(--addUTR=on)
[[ -n "$resolved_augustus_config" ]] && braker_args+=(--AUGUSTUS_CONFIG_PATH="$resolved_augustus_config")
[[ -n "$augustus_bin_path" ]] && braker_args+=(--AUGUSTUS_BIN_PATH="$augustus_bin_path")
[[ -n "$augustus_scripts_path" ]] && braker_args+=(--AUGUSTUS_SCRIPTS_PATH="$augustus_scripts_path")
[[ -n "$bamtools_path" ]] && braker_args+=(--BAMTOOLS_PATH="$bamtools_path")
[[ -n "$samtools_path" ]] && braker_args+=(--SAMTOOLS_PATH="$samtools_path")
[[ -n "$diamond_path" ]] && braker_args+=(--DIAMOND_PATH="$diamond_path")
[[ -n "$cdbtools_path" ]] && braker_args+=(--CDBTOOLS_PATH="$cdbtools_path")
[[ -n "$prothint_path" ]] && braker_args+=(--PROTHINT_PATH="$prothint_path")
[[ -n "$tsebra_path" ]] && braker_args+=(--TSEBRA_PATH="$tsebra_path")
[[ -n "$genemark_path" ]] && braker_args+=(--GENEMARK_PATH="$genemark_path")
for option in "${braker_options[@]}"; do
  read -r -a option_parts <<< "$option"
  braker_args+=("${option_parts[@]}")
done

run_script="$workdir/run_braker3.sh"
runtime_log="$outdir_abs/${prefix}.braker3_running_time.txt"
{
  printf '#!/usr/bin/env bash\n'
  printf 'set -euo pipefail\n'
  printf 'cd %q\n' "$workdir"
  printf '%q' "$braker_cmd"
  for arg in "${braker_args[@]}"; do
    printf ' %q' "$arg"
  done
  printf '\n'
} > "$run_script"
chmod +x "$run_script"

{
  printf '[%s] Workflow started\n' "$(date)"
  start=$(date +%s)
  "$run_script"
  duration=$(( $(date +%s) - start ))
  awk -v s="$duration" 'BEGIN {printf "[%s] Duration: %.4f hours\n", strftime("%Y-%m-%d %H:%M:%S"), s/3600}'
} | tee -a "$runtime_log"

copy_if_present() {
  local src=$1
  local dst=$2
  if [[ -s "$src" ]]; then
    cp "$src" "$dst"
  fi
}

braker_dir="$workdir/braker"
copy_if_present "$braker_dir/braker.gff3" "$outdir_abs/${prefix}.braker3.gff3"
copy_if_present "$braker_dir/braker.gtf" "$outdir_abs/${prefix}.braker3.gtf"
copy_if_present "$braker_dir/braker.aa" "$outdir_abs/${prefix}.braker3.protein.fa"
copy_if_present "$braker_dir/braker.codingseq" "$outdir_abs/${prefix}.braker3.cds.fa"
copy_if_present "$braker_dir/augustus.hints.gff3" "$outdir_abs/${prefix}.augustus_hints.gff3"

cat > "$outdir_abs/${prefix}.braker3_manifest.tsv" <<MANIFEST
field	value
prefix	$prefix
species	$species
genome	$genome_abs
proteins	$proteins_abs
rnaseq_bam_count	${#bam_abs[@]}
rounds	$rounds
threads	$threads
memory_note	$memory_note
add_utr	$add_utr
workdir	$workdir
runtime_log	$runtime_log
augustus_config	${resolved_augustus_config:-NA}
MANIFEST
