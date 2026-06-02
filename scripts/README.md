# BioAnalysis Scripts

Scripts are organized by numbered workflow stage. Shared Python helpers remain in `common/` so maintained scripts can import `common.bioio` consistently.

## Layout

```text
common/              shared FASTA/GFF/TSV helpers
01_preprocessing/    input QC and NT-based contamination-screening wrappers
02_assembly/         independent assembly, Hi-C scaffolding, statistics, and QC helpers
03_repeat/           repeat annotation, TE post-processing, and EVE/GEVE handoffs
04_gff/              GFF/CDS/PEP extraction, structure statistics, QC, and plot handoffs
05_genome_features/  intron, introner, region-context, and methylation evidence tracks
06_annotation/       functional annotation parsing, COG/NOG summaries, and GO handoffs
07_gene_family/      gene-family analysis, target-family discovery, expression, alignments, and tree helpers
08_gene_family_evolution/ Count/CAFE gene-family gain, loss, expansion, contraction, and target-family integration
09_synteny/          synteny context, MCScan/JCVI summaries, heatmaps, and Circos links
10_hgt/              HGT candidate screening and validation handoff
11_visualization/    visualization matrices, handoff helpers, and legacy Circos scripts
```

## Script policy

- Maintained BioAnalysis scripts should expose explicit CLI arguments and `--help`.
- Reference-derived scripts must not contain real local paths or private project identifiers.
- Legacy scripts should be kept under legacy/reference directories and marked as review-required.
- External bioinformatics programs are not vendored; document them in the software list.
- Repository-facing script help, comments, and documentation should be English.

## Adding a new workflow

1. Place scripts in the relevant numbered stage directory.
2. Use stable descriptive filenames; use numbered filenames for multi-step workflows when order matters.
3. Add command examples to `docs/BioAnalysis_Genome_Command_Templates.md`.
4. Add SOP/checklist entries.
5. Add provenance and status to `scripts/SCRIPT_SOURCES.md`.
6. Add Makefile validation when useful.
7. Run `make check-all`.
