# BioAnalysis Genome Workflow Software Reference

This document lists external tools, databases, and maintained helper scripts used by the BioAnalysis workflow. Third-party tools are installed separately and are not vendored in this repository.

## Software by workflow stage

| Stage | Tool or script | Purpose | Notes |
|---|---|---|---|
| 01 preprocessing | BLASTN | NT-based contig screening | Requires a local NT database and documented database version. |
| 01 preprocessing | accession-to-taxid and lineage tables | Taxonomic interpretation for NT hits | Supply paths at runtime; do not commit private database paths. |
| 01 preprocessing | `scripts/01_preprocessing/01_nt_decontaminate_contigs.sh` | Portable wrapper for NT-based contig filtering | Requires local helper scripts supplied with `--script-dir`. |
| 02 assembly | hifiasm, NextDenovo, SPAdes, Canu | Genome assembly | Choose based on sequencing technology and project design. |
| 02 assembly | purge_dups, NextPolish, HiC-Pro, chromap, HapHiC | Purging, polishing, and scaffolding | Record assembly version after every major change. |
| 02 assembly | BUSCO, compleasm, meryl, Merqury | Assembly and annotation QC | Record lineage/database versions. |
| 02 assembly | `scripts/02_assembly/assembly_stats.py` | FASTA statistics | Produces summary and optional per-sequence length tables. |
| 03 repeat | LTR_FINDER_parallel, GenomeTools, LTR_retriever | LTR discovery and curation | Use the same uppercase genome FASTA throughout. |
| 03 repeat | RepeatModeler, RepeatMasker, TRF | Repeat library construction and masking | Keep known/unknown outputs traceable. |
| 03 repeat | `scripts/03_repeat/*.sh` | Portable repeat wrappers | Tools must be available on `PATH`. |
| 04 GFF | BRAKER3, AUGUSTUS, GeneMark, gffread | Gene structure annotation and checks | GFF seqids must match genome FASTA. |
| 04 GFF | `scripts/04_gff/gff_cds_pep.py` | Clean GFF/CDS/PEP extraction | Produces CDS QC tables. |
| 05 genome features | bedtools, samtools | Window and coordinate operations | Track coordinate systems carefully. |
| 05 genome features | Introner-elements | Introner candidate workflow | External tool; provide local path at runtime. |
| 05 genome features | `scripts/05_genome_features/extract_introns.py` | Intron, short-intron, and AT-rich intron outputs | BED output is 0-based half-open. |
| 06 annotation | InterProScan, eggNOG-mapper, KofamScan | Functional annotation | Keep database versions and thresholds. |
| 06 annotation | DIAMOND, BLASTP | SwissProt/NR/HGT similarity searches | Use explicit output fields and sorting rules. |
| 06 annotation | `scripts/06_annotation/*.py` | Parse and merge annotation tables | Missing annotations remain `NA`. |
| 06 annotation | `scripts/06_annotation/kegg/*.pl` | Reference KEGG/pathway helpers | Review input formats before use. |
| 07 phylogeny | OrthoFinder, MAFFT, trimAl, RAxML, IQ-TREE, MrBayes | Orthogroups and phylogenetics | Preserve logs, models, support values, and failed-family records. |
| 07 phylogeny | `scripts/07_phylogeny/*.py` | ID mapping, family extraction, tree metadata, summaries | `root_tree.py` is a handoff helper only. |
| 08 CAFE | CAFE/CAFE5 | Expansion/contraction analysis | Requires matching species tree and count matrix. |
| 08 CAFE | `scripts/08_cafe/*.py` | CAFE input preparation and filtering | Removed-family reasons are required. |
| 09 synteny | minimap2, WGDI, MCScanX, JCVI | Genome/protein synteny and dotplots | IDs must match between protein, GFF, and FASTA files. |
| 09 synteny | `scripts/09_synteny/anchors_to_circos_links.py` | Convert anchors/blocks to Circos links | Validate coordinates against chromosome lengths. |
| 10 HGT | DIAMOND/BLASTP, local taxonomy tables | HGT candidate discovery | Candidate calls need phylogenetic and context validation. |
| 10 HGT | `scripts/10_hgt/*.py` | Classify hits, score candidates, add context, prepare validation | No remote database access; all inputs are local files. |
| 11 visualization | Circos, plotting tools, reference Perl helpers | Figures and tracks | Legacy helpers are review-required. |

## Version record template

| Component | Version/database date | Command or source | Notes |
|---|---|---|---|
| Genome assembly | NA | NA | Fill per project. |
| NT database | NA | NA | Required for decontamination. |
| NCBI taxonomy tables | NA | NA | Required for NT/HGT taxonomy interpretation. |
| BUSCO lineage | embryophyta_odb10 | NA | Replace if needed. |
| InterProScan databases | NA | NA | Fill per project. |
| eggNOG database | NA | NA | Fill per project. |
| Kofam profiles | NA | NA | Fill per project. |
| OrthoFinder | NA | NA | Fill per project. |
| IQ-TREE/RAxML | NA | NA | Fill per project. |
| CAFE | NA | NA | Fill per project. |
