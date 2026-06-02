# Stage 01 raw-read filtering and contamination screening

Run this stage before genome survey, assembly, RNA alignment, or BRAKER gene prediction.

## Recommended order

1. Filter raw RNA-seq or WGS reads with fastp or Trimmomatic.
2. Review read QC reports and filtering summaries.
3. Pass clean WGS reads to Stage 02 genome survey/assembly.
4. Pass clean RNA reads to Stage 04 HISAT2 RNA evidence alignment.
5. Run NT contig decontamination only after an assembly FASTA exists.

## RNA-seq read filtering

```bash
bash run_fastp_rna_read_filtering_workflow.sh \
  --sample Arabidopsis_thaliana.flower \
  --r1 Arabidopsis_thaliana.flower_R1.fq.gz \
  --r2 Arabidopsis_thaliana.flower_R2.fq.gz \
  --outdir rna_fastp \
  --detect-adapter-for-pe

bash run_trimmomatic_rna_read_filtering_workflow.sh \
  --sample Arabidopsis_thaliana.flower \
  --pe1 Arabidopsis_thaliana.flower_R1.fq.gz \
  --pe2 Arabidopsis_thaliana.flower_R2.fq.gz \
  --outdir rna_trimmomatic \
  --adapter-file refs/TruSeq3-PE.fa
```

## WGS read filtering

```bash
bash run_fastp_wgs_read_filtering_workflow.sh \
  --sample Arabidopsis_thaliana.WGS \
  --r1 Arabidopsis_thaliana.WGS_R1.fq.gz \
  --r2 Arabidopsis_thaliana.WGS_R2.fq.gz \
  --outdir wgs_fastp \
  --adapter-fasta refs/adapter.fasta

bash run_trimmomatic_wgs_read_filtering_workflow.sh \
  --sample Arabidopsis_thaliana.WGS \
  --pe1 Arabidopsis_thaliana.WGS_R1.fq.gz \
  --pe2 Arabidopsis_thaliana.WGS_R2.fq.gz \
  --outdir wgs_trimmomatic \
  --adapter-file refs/TruSeq3-PE.fa
```

## NT contig decontamination

```bash
bash 01_nt_decontaminate_contigs.sh \
  --id Arabidopsis_thaliana \
  --fasta Arabidopsis_thaliana.assembly.fa \
  --nt-db refs/nt \
  --script-dir refs/nt_helpers \
  --outdir nt_decontamination
```

## QC checks

- Filtered FASTQ files are non-empty.
- Adapter source and quality thresholds are recorded.
- FastQC/fastp/Trimmomatic summaries are retained.
- NT database and taxonomy table versions are recorded.
- Private database paths and real sample IDs are not committed.
