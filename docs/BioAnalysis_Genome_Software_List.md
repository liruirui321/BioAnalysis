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
| 03 repeat | `scripts/03_repeat/run_repeat_annotation_workflow.sh`, `scripts/03_repeat/*.sh` | Chained repeat workflow and portable repeat wrappers | Tools must be available on `PATH`. |
| 04 GFF | BRAKER3, AUGUSTUS, GeneMark, gffread | Gene structure annotation and checks | GFF seqids must match genome FASTA. |
| 04 GFF | `scripts/04_gff/gff_cds_pep.py` | Clean GFF/CDS/PEP extraction | Produces CDS QC tables. |
| 05 genome features | bedtools, samtools | Window and coordinate operations | Track coordinate systems carefully. |
| 05 genome features | Introner-elements | Introner candidate workflow | External tool; provide local path at runtime. |
| 05 genome features | `scripts/05_genome_features/run_genome_features_workflow.sh`, `extract_introns.py` | Chained intron and optional introner workflow outputs | BED output is 0-based half-open. |
| 06 annotation | InterProScan, eggNOG-mapper, KofamScan | Functional annotation | Keep database versions and thresholds. |
| 06 annotation | DIAMOND, BLASTP | SwissProt/NR/HGT similarity searches | Use explicit output fields and sorting rules. |
| 06 annotation | GO, KEGG, Pfam, and pathway mapping tables | Downstream term summaries and enrichment | Record term-map source and version in project notes. |
| 06 annotation | `scripts/06_annotation/run_functional_annotation_workflow.sh`, `scripts/06_annotation/*.py` | Chain parsing, merging, summaries, and enrichment for annotation tables | Missing annotations remain `NA`. |
| 06 annotation | `scripts/06_annotation/kegg/*.pl` | Reference KEGG/pathway helpers | Review input formats before use. |
| 07 gene family | OrthoFinder | Orthogroups and gene-family count matrices | Run before alignment and tree-building helpers. |
| 07 gene family | MAFFT, trimAl, RAxML, IQ-TREE, MrBayes | Alignment trimming and phylogenetic inference | Preserve logs, models, support values, and failed-family records. |
| 07 gene family | `scripts/07_gene_family/run_gene_family_workflow.sh`, `scripts/07_gene_family/*.py` | Chain ID mapping, family summaries, member extraction, and tree handoffs | `root_tree.py` is a handoff helper only. |
| 08 gene-family evolution | Count | Gene-family gain/loss inference from count matrices and species trees | Validate Count output format before parsing. |
| 08 gene-family evolution | CAFE/CAFE5 | Expansion/contraction analysis | Requires matching species tree and count matrix. |
| 08 gene-family evolution | `scripts/08_gene_family_evolution/run_gene_family_evolution_workflow.sh`, `scripts/08_gene_family_evolution/*.py` | Chain Count input preparation, gain/loss parsing, CAFE input preparation, and filtering | Rejected or removed-family reasons are required. |
| 09 synteny | minimap2, WGDI, MCScanX, JCVI | Genome/protein synteny and dotplots | IDs must match between protein, GFF, and FASTA files. |
| 09 synteny | `scripts/09_synteny/anchors_to_circos_links.py` | Convert anchors/blocks to Circos links | Validate coordinates against chromosome lengths. |
| 10 HGT | DIAMOND/BLASTP against NR or another broad local database | HGT similarity-search input generation | Use BLAST outfmt 6 with e-value and bitscore columns. |
| 10 HGT | blast2hgt with configured accession/taxonomy database | HGT candidate screening and taxonomy-group signal table | External tool; first `--define` group is treated as self/vertical lineage. Database credentials and private paths stay outside the repository. |
| 10 HGT | `scripts/10_hgt/*.sh`, `scripts/10_hgt/*.py` | Run blast2hgt handoff, filter candidates, add context, prepare validation | No remote database access; all inputs are local files. |
| 11 visualization | Circos, plotting tools, reference Perl helpers | Figures and tracks | Legacy helpers are review-required. |

## Version record template

| Component | Version/database date | Command or source | Notes |
|---|---|---|---|
| Genome assembly | NA | NA | Fill per project. |
| NT database | NA | NA | Required for decontamination. |
| NCBI taxonomy tables | NA | NA | Required for NT/HGT taxonomy interpretation. |
| blast2hgt accession/taxonomy database | NA | NA | Required for blast2hgt HGT screening. |
| BUSCO lineage | embryophyta_odb10 | NA | Replace if needed. |
| InterProScan databases | NA | NA | Fill per project. |
| eggNOG database | NA | NA | Fill per project. |
| Kofam profiles | NA | NA | Fill per project. |
| GO ontology or GO mapping source | NA | NA | Fill per project. |
| KEGG KO-to-pathway map | NA | NA | Fill per project. |
| Pfam database | NA | NA | Fill per project. |
| OrthoFinder | NA | NA | Fill per project. |
| Count | NA | NA | Fill per project. |
| IQ-TREE/RAxML | NA | NA | Fill per project. |
| CAFE | NA | NA | Fill per project. |
