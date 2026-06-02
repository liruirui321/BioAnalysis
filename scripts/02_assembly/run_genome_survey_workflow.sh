#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run_genome_survey_workflow.sh --read reads.fq.gz --outdir genome_survey [options]

Run an independent Stage 02 genome survey workflow:
  1. Count canonical k-mers from read files with Jellyfish.
  2. Create a k-mer depth histogram.
  3. Run GenomeScope2 to estimate genome size, heterozygosity, and duplication.
  4. Optionally run Smudgeplot to estimate ploidy structure.

Required:
  --read FILE                  Read FASTQ/FASTA file; repeatable
  --outdir DIR                 Output directory

Options:
  --prefix NAME                Output prefix [genome_survey]
  --kmer INT                   k-mer size [21]
  --hash-size SIZE             Jellyfish hash size, for example 10G [10G]
  --threads INT                Threads [20]
  --histo-high INT             Maximum count for jellyfish histo [100000]
  --ploidy INT                 GenomeScope2 ploidy [2]
  --jellyfish CMD              jellyfish executable [jellyfish]
  --genomescope CMD            GenomeScope2 executable [genomescope2]
  --smudgeplot CMD             Smudgeplot executable [smudgeplot.py]
  --run-smudgeplot             Run Smudgeplot after GenomeScope2
  --cleanup-reads              Remove temporary concatenated read file when created
  -h, --help                   Show this help
USAGE
}

reads=()
outdir=""
prefix="genome_survey"
kmer=21
hash_size="10G"
threads=20
histo_high=100000
ploidy=2
jellyfish_cmd="jellyfish"
genomescope_cmd="genomescope2"
smudgeplot_cmd="smudgeplot.py"
run_smudgeplot=0
cleanup_reads=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --read) reads+=("${2:?"Missing value for --read"}"); shift 2 ;;
    --outdir) outdir=${2:?"Missing value for --outdir"}; shift 2 ;;
    --prefix) prefix=${2:?"Missing value for --prefix"}; shift 2 ;;
    --kmer) kmer=${2:?"Missing value for --kmer"}; shift 2 ;;
    --hash-size) hash_size=${2:?"Missing value for --hash-size"}; shift 2 ;;
    --threads) threads=${2:?"Missing value for --threads"}; shift 2 ;;
    --histo-high) histo_high=${2:?"Missing value for --histo-high"}; shift 2 ;;
    --ploidy) ploidy=${2:?"Missing value for --ploidy"}; shift 2 ;;
    --jellyfish) jellyfish_cmd=${2:?"Missing value for --jellyfish"}; shift 2 ;;
    --genomescope) genomescope_cmd=${2:?"Missing value for --genomescope"}; shift 2 ;;
    --smudgeplot) smudgeplot_cmd=${2:?"Missing value for --smudgeplot"}; shift 2 ;;
    --run-smudgeplot) run_smudgeplot=1; shift ;;
    --cleanup-reads) cleanup_reads=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ ${#reads[@]} -eq 0 || -z "$outdir" ]]; then
  echo "Missing required --read or --outdir" >&2
  usage >&2
  exit 1
fi
for value_name in kmer threads histo_high ploidy; do
  value=${!value_name}
  if [[ ! "$value" =~ ^[0-9]+$ || "$value" -lt 1 ]]; then
    echo "--${value_name//_/-} must be a positive integer" >&2
    exit 1
  fi
done
for file in "${reads[@]}"; do
  if [[ ! -s "$file" ]]; then
    echo "Missing or empty read file: $file" >&2
    exit 1
  fi
done
for cmd in "$jellyfish_cmd" "$genomescope_cmd"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required executable not found: $cmd" >&2
    exit 1
  fi
done
if [[ "$run_smudgeplot" -eq 1 ]] && ! command -v "$smudgeplot_cmd" >/dev/null 2>&1; then
  echo "Smudgeplot executable not found: $smudgeplot_cmd" >&2
  exit 1
fi

outdir_abs=$(mkdir -p "$outdir" && readlink -f "$outdir")
workdir="$outdir_abs/${prefix}.genome_survey_work"
results_dir="$outdir_abs/results"
mkdir -p "$workdir" "$results_dir"

read_abs=()
for file in "${reads[@]}"; do
  read_abs+=("$(readlink -f "$file")")
done

count_inputs=("${read_abs[@]}")
temporary_reads=""
if [[ "${read_abs[0]}" == *.gz ]]; then
  temporary_reads="$workdir/${prefix}.all_reads.fq"
  zcat "${read_abs[@]}" > "$temporary_reads"
  count_inputs=("$temporary_reads")
fi

kmer_db="$results_dir/${prefix}.kmer_counts.jf"
hist_file="$results_dir/${prefix}.k${kmer}.hist"
"$jellyfish_cmd" count -C -m "$kmer" -t "$threads" -s "$hash_size" "${count_inputs[@]}" -o "$kmer_db"
"$jellyfish_cmd" histo -t "$threads" -h "$histo_high" "$kmer_db" > "$hist_file"

"$genomescope_cmd" -i "$hist_file" -o "$results_dir/${prefix}.GenomeScopeResults" -p "$ploidy" -k "$kmer"

if [[ "$run_smudgeplot" -eq 1 ]]; then
  L=$("$smudgeplot_cmd" cutoff "$hist_file" L)
  U=$("$smudgeplot_cmd" cutoff "$hist_file" U)
  "$jellyfish_cmd" dump -c -L "$L" -U "$U" "$kmer_db" | "$smudgeplot_cmd" hetkmers -o "$results_dir/${prefix}.kmer_pairs"
  "$smudgeplot_cmd" plot "$results_dir"/*coverages.tsv -o "$results_dir/${prefix}.SmudgePlotResults"
fi

cat > "$outdir_abs/${prefix}.genome_survey_manifest.tsv" <<MANIFEST
field	value
prefix	$prefix
kmer	$kmer
hash_size	$hash_size
threads	$threads
histo_high	$histo_high
ploidy	$ploidy
read_count	${#reads[@]}
kmer_db	$kmer_db
histogram	$hist_file
genomescope_output	$results_dir/${prefix}.GenomeScopeResults
smudgeplot_run	$run_smudgeplot
MANIFEST

if [[ "$cleanup_reads" -eq 1 && -n "$temporary_reads" ]]; then
  rm -f "$temporary_reads"
fi
