#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: run_yahs_scaffolding.sh --assembly assembly.fa --hic-r1 hic_R1.fq.gz --hic-r2 hic_R2.fq.gz --outdir yahs_scaffolding [options]

Run an independent Stage 02 YaHS Hi-C scaffolding workflow:
  1. Index the input assembly and align Hi-C reads with chromap.
  2. Convert filtered Hi-C alignments to BED.
  3. Run YaHS scaffolding.
  4. Expose stable scaffold FASTA/AGP handoff files when produced and write stats.

Required:
  --assembly FILE              Input assembly FASTA
  --hic-r1 FILE                Hi-C read 1
  --hic-r2 FILE                Hi-C read 2
  --outdir DIR                 Output directory

Options:
  --prefix NAME                Output prefix [assembly basename]
  --threads INT                Threads for chromap/samtools [32]
  --chromap CMD                chromap executable [chromap]
  --samtools CMD               samtools executable [samtools]
  --bedtools CMD               bedtools executable [bedtools]
  --yahs CMD                   yahs executable [yahs]
  --python CMD                 Python executable [python3]
  --chromap-option TEXT        Additional chromap option string; repeatable
  --yahs-option TEXT           Additional YaHS option string; repeatable
  --skip-assembly-stats        Skip scaffold stats handoff
  -h, --help                   Show this help
USAGE
}

assembly=""
hic_r1=""
hic_r2=""
outdir=""
prefix=""
threads=32
chromap_cmd="chromap"
samtools_cmd="samtools"
bedtools_cmd="bedtools"
yahs_cmd="yahs"
python_cmd="python3"
skip_assembly_stats=0
chromap_options=()
yahs_options=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --assembly) assembly=${2:?"Missing value for --assembly"}; shift 2 ;;
    --hic-r1) hic_r1=${2:?"Missing value for --hic-r1"}; shift 2 ;;
    --hic-r2) hic_r2=${2:?"Missing value for --hic-r2"}; shift 2 ;;
    --outdir) outdir=${2:?"Missing value for --outdir"}; shift 2 ;;
    --prefix) prefix=${2:?"Missing value for --prefix"}; shift 2 ;;
    --threads) threads=${2:?"Missing value for --threads"}; shift 2 ;;
    --chromap) chromap_cmd=${2:?"Missing value for --chromap"}; shift 2 ;;
    --samtools) samtools_cmd=${2:?"Missing value for --samtools"}; shift 2 ;;
    --bedtools) bedtools_cmd=${2:?"Missing value for --bedtools"}; shift 2 ;;
    --yahs) yahs_cmd=${2:?"Missing value for --yahs"}; shift 2 ;;
    --python) python_cmd=${2:?"Missing value for --python"}; shift 2 ;;
    --chromap-option) chromap_options+=("${2:?"Missing value for --chromap-option"}"); shift 2 ;;
    --yahs-option) yahs_options+=("${2:?"Missing value for --yahs-option"}"); shift 2 ;;
    --skip-assembly-stats) skip_assembly_stats=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

for name in assembly hic_r1 hic_r2 outdir; do
  value=${!name}
  if [[ -z "$value" ]]; then
    echo "Missing required --${name//_/-}" >&2
    usage >&2
    exit 1
  fi
done
if [[ ! "$threads" =~ ^[0-9]+$ || "$threads" -lt 1 ]]; then
  echo "--threads must be a positive integer" >&2
  exit 1
fi
for file in "$assembly" "$hic_r1" "$hic_r2"; do
  if [[ ! -s "$file" ]]; then
    echo "Missing or empty input file: $file" >&2
    exit 1
  fi
done
for cmd in "$chromap_cmd" "$samtools_cmd" "$bedtools_cmd" "$yahs_cmd"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required executable not found: $cmd" >&2
    exit 1
  fi
done

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
outdir_abs=$(mkdir -p "$outdir" && readlink -f "$outdir")
if [[ -z "$prefix" ]]; then
  prefix=$(basename "$assembly")
  prefix=${prefix%.gz}
  prefix=${prefix%.fasta}
  prefix=${prefix%.fa}
  prefix=${prefix%.fna}
fi
workdir="$outdir_abs/${prefix}.yahs_work"
mkdir -p "$workdir"
assembly_abs=$(readlink -f "$assembly")
hic_r1_abs=$(readlink -f "$hic_r1")
hic_r2_abs=$(readlink -f "$hic_r2")

(
  cd "$workdir"
  "$samtools_cmd" faidx "$assembly_abs"
  "$chromap_cmd" -i -r "$assembly_abs" -o contigs.index
  chromap_args=(--preset hic -r "$assembly_abs" -x contigs.index --remove-pcr-duplicates -1 "$hic_r1_abs" -2 "$hic_r2_abs" --SAM -o aligned.sam -t "$threads")
  for option in "${chromap_options[@]}"; do
    read -r -a option_parts <<< "$option"
    chromap_args+=("${option_parts[@]}")
  done
  "$chromap_cmd" "${chromap_args[@]}"
  "$samtools_cmd" view -bh aligned.sam | "$samtools_cmd" sort -@ "$threads" -n > aligned.bam
  rm -f aligned.sam
  "$samtools_cmd" view -bh -u -F0xF0C -q10 aligned.bam | "$bedtools_cmd" bamtobed | awk -v OFS='\t' '{$4=substr($4,1,length($4)-2); print}' > aligned.bed
  yahs_args=("$assembly_abs" aligned.bed -o yahs.out)
  for option in "${yahs_options[@]}"; do
    read -r -a option_parts <<< "$option"
    yahs_args+=("${option_parts[@]}")
  done
  "$yahs_cmd" "${yahs_args[@]}"
)

scaffold_fa=""
for candidate in "$workdir/yahs.out_scaffolds_final.fa" "$workdir/yahs.out_scaffolds_final.fasta" "$workdir/yahs.out_scaffolds_final.fa.gz"; do
  if [[ -s "$candidate" ]]; then
    scaffold_fa="$candidate"
    break
  fi
done
agp=""
for candidate in "$workdir/yahs.out_scaffolds_final.agp" "$workdir/yahs.out.agp"; do
  if [[ -s "$candidate" ]]; then
    agp="$candidate"
    break
  fi
done
if [[ -z "$scaffold_fa" ]]; then
  echo "YaHS scaffold FASTA was not found; keeping native outputs in $workdir" >&2
else
  handoff_fa="$outdir_abs/${prefix}.yahs.scaffolds.fa"
  if [[ "$scaffold_fa" == *.gz ]]; then
    gzip -dc "$scaffold_fa" > "$handoff_fa"
  else
    cp "$scaffold_fa" "$handoff_fa"
  fi
  if [[ "$skip_assembly_stats" -eq 0 ]]; then
    "$python_cmd" "$script_dir/assembly_stats.py" \
      --fasta "$handoff_fa" \
      --out "$outdir_abs/${prefix}.yahs.scaffolds_stats.tsv" \
      --lengths "$outdir_abs/${prefix}.yahs.scaffolds_lengths.tsv"
  fi
fi
if [[ -n "$agp" ]]; then
  cp "$agp" "$outdir_abs/${prefix}.yahs.agp"
fi
