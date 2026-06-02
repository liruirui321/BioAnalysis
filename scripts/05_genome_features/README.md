# Stage 05 genome features, introns, region context, and methylation

Use this directory after clean GFF and genome FASTA files are available.

## Recommended order

1. Extract introns and gene features from GFF/genome FASTA.
2. Compare target regions against background regions.
3. Summarize methylation over regions when Bismark CX reports are available.
4. Optionally run external Introner-elements with user-supplied paths.
5. Pass region/context outputs to Stage 09 synteny and Stage 11 visualization.

## Main genome-feature workflow

```bash
bash run_genome_features_workflow.sh \
  --gff Arabidopsis_thaliana.annotation.primary.gff3 \
  --genome Arabidopsis_thaliana.genome.fa \
  --outdir genome_features \
  --prefix Arabidopsis_thaliana
```

## Region context workflow

```bash
bash run_region_context_workflow.sh \
  --target-bed Arabidopsis_thaliana.eve_geve_regions.bed \
  --background-bed Arabidopsis_thaliana.callable_windows.bed \
  --feature-bed genome_features/Arabidopsis_thaliana.introns.bed \
  --outdir region_context \
  --prefix Arabidopsis_thaliana.eve_geve
```

## Individual helpers

```bash
python3 extract_introns.py --help
python3 compare_region_feature_enrichment.py --help
python3 summarize_bismark_cx_regions.py --help
bash run_introner_elements.sh --help
```

## QC checks

- BED files are 0-based half-open.
- Target and background regions are comparable.
- Unique loci are used for density summaries when needed.
- Bismark coverage thresholds and CX report source are documented.
- External Introner-elements paths are passed at runtime and not committed.
