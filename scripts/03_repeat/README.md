# Stage 03 repeat annotation and TE/EVE post-processing

Use this directory after you have a cleaned genome FASTA from Stage 02. Run the wrappers in this order unless a project already has equivalent outputs.

## Recommended order

1. Run the repeat annotation workflow.
2. Convert or summarize repeat outputs when needed.
3. Standardize EVE/GEVE candidate regions.
4. Summarize TE domains and divergence.
5. Pass repeat/EVE/TE tables to downstream feature, synteny, and visualization stages.

## 1. Repeat annotation workflow

```bash
bash run_repeat_annotation_workflow.sh \
  --genome Arabidopsis_thaliana.genome.fa \
  --outdir repeat_annotation \
  --prefix Arabidopsis_thaliana \
  --threads 24
```

This is the main entry point for RepeatModeler, RepeatMasker, LTR, TRF, and repeat handoff outputs when the required tools are available.

Expected handoffs include repeat libraries, RepeatMasker outputs, repeat GFF/summary tables, TRF outputs, and workflow manifests.

## 2. Standalone LTR or repeat helpers

Use these only when you need a single sub-step instead of the full wrapper.

```bash
bash LTR_Finder.sh --help
bash LTR_harvest.sh --help
bash trf.sh --help
bash rmout2gff.sh --help
bash repeat_stat.sh --help
```

Notes:

- Prefer `repeat_stat.sh` over legacy `stat.sh`.
- Check genome naming and masking convention before mixing outputs from different tools.
- Keep tool versions and repeat database/library sources in project run notes.

## 3. TE/EVE post-processing workflow

```bash
bash run_te_eve_postprocessing_workflow.sh \
  --repeatmasker-out repeat_annotation/Arabidopsis_thaliana.repeatmasker.out \
  --genome Arabidopsis_thaliana.genome.fa \
  --outdir te_eve_postprocessing \
  --prefix Arabidopsis_thaliana
```

Use this when you have RepeatMasker output plus EVE/GEVE regions or TEsorter domains to standardize for downstream analyses.

## 4. Python summarizers

```bash
python3 standardize_eve_geve_regions.py --help
python3 parse_tesorter_domains.py --help
python3 summarize_tesorter_regions.py --help
python3 summarize_te_divergence.py --help
```

Typical flow:

```text
external EVE/GEVE calls -> standardize_eve_geve_regions.py -> BED/TSV handoff
TEsorter output -> parse_tesorter_domains.py -> domain TSV
regions + domains -> summarize_tesorter_regions.py -> region-domain summary
RepeatMasker divergence -> summarize_te_divergence.py -> divergence summary
```

## QC checks

- Genome FASTA is non-empty and sequence IDs are unique.
- Repeat libraries and RepeatMasker `.out` files are non-empty when expected.
- BED coordinates are 0-based half-open and in bounds.
- EVE/GEVE caller source and format are documented.
- RepeatMasker, RepeatModeler, LTR, TRF, and TEsorter versions are recorded.

## Downstream handoff

- Stage 05 uses repeat/region BED files for region context comparisons.
- Stage 09 can use repeat or target-region BED files for synteny context.
- Stage 11 can use standardized region tables for final visualization matrices.
