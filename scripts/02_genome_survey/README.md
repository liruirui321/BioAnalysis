# Stage 02 genome survey and ploidy estimation

Use this directory before assembly when estimating genome size, heterozygosity, repeat content, and ploidy.

## Recommended order

1. Run k-mer genome survey from filtered WGS short reads.
2. Optionally run Smudgeplot from the same k-mer evidence.
3. Run ploidyNGS when you have a coordinate-sorted WGS BAM.
4. Record k-mer, ploidy, hash-size, coverage, and BAM provenance.
5. Pass genome-size estimates to Stage 02 assembly wrappers.

## K-mer genome survey

```bash
bash run_genome_survey_workflow.sh \
  --read Arabidopsis_thaliana.WGS_R1.clean.fq.gz \
  --read Arabidopsis_thaliana.WGS_R2.clean.fq.gz \
  --outdir genome_survey \
  --prefix Arabidopsis_thaliana \
  --kmer 21 \
  --ploidy 2 \
  --run-smudgeplot
```

Expected outputs include Jellyfish database/histogram, GenomeScope2 results, optional Smudgeplot outputs, runtime log, and manifest.

## BAM-based ploidy estimation

```bash
bash run_ploidyngs_workflow.sh \
  --bam Arabidopsis_thaliana.sorted.bam \
  --outdir ploidy_ngs \
  --prefix Arabidopsis_thaliana \
  --guess-ploidy \
  --option "--max_depth 100"
```

## QC checks

- Input read files or BAM are non-empty.
- GenomeScope and ploidyNGS estimates are biologically plausible.
- K-mer size, ploidy, histogram cap, hash size, and ploidyNGS options are recorded.
- Smudgeplot output is retained when used.
- These scripts stay separate from assembly and assembly QC workflows.
