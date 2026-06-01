# BioAnalysis Scripts

Scripts are organized by numbered workflow stage. Shared Python helpers remain in `common/` so maintained scripts can import `common.bioio` consistently.

## Layout

```text
common/              shared FASTA/GFF/TSV helpers
01_preprocessing/    input QC and NT-based contamination-screening wrappers
02_assembly/         assembly statistics and QC helpers
03_repeat/           repeat annotation wrappers, converters, and statistics
04_gff/              GFF/CDS/PEP extraction and QC
05_genome_features/  intron, introner, and genome-feature evidence tracks
06_annotation/       functional annotation parsing, merging, and KEGG helpers
07_gene_family/      gene-family analysis, orthogroups, alignments, and tree helpers
08_gene_family_evolution/ Count/CAFE gene-family gain, loss, expansion, and contraction
09_synteny/          synteny and Circos link conversion
10_hgt/              HGT candidate screening and validation handoff
11_visualization/    reference-derived visualization helpers
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
