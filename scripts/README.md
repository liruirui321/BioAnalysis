# BioAnalysis scripts

This directory contains project-owned helper scripts used by the BioAnalysis genome workflow SOP.

Principles:

- Third-party tools such as BRAKER, InterProScan, eggNOG-mapper, RAxML, IQ-TREE, OrthoFinder, RepeatMasker and Merqury are external dependencies and are not reimplemented here.
- Scripts here handle format conversion, table parsing, ID mapping, QC summaries and workflow handoffs between tools.
- Python scripts use the standard library unless noted otherwise.
- Every script should support `--help` and write TSV/plain-text outputs suitable for downstream workflow steps.

Directory layout:

```text
common/           shared FASTA/GFF/TSV helpers
assembly/         assembly statistics
gff/              GFF/CDS/PEP extraction
annotation/       functional annotation parsing and merging
repeat/           repeat annotation wrappers/converters/statistics
cafe/             CAFE input preparation and filtering
phylogeny/        orthogroup, alignment and gene-tree utilities
genome_features/  intron and feature extraction
synteny/          synteny-to-Circos conversion
```
