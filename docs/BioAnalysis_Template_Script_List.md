# BioAnalysis Script Reference

This document lists maintained helper scripts, reference-derived scripts, and external tool entry points by numbered workflow stage.

Status labels match [`../scripts/SCRIPT_SOURCES.md`](../scripts/SCRIPT_SOURCES.md).

## Script inventory

| Stage | Script | Status | Input | Output / handoff |
|---|---|---|---|---|
| common | `scripts/common/bioio.py` | Maintained helper library | FASTA/GFF/TSV paths | Shared IO functions for Python scripts |
| 01 preprocessing | `scripts/01_preprocessing/01_nt_decontaminate_contigs.sh` | Reference-derived; cleaned wrapper | Assembly FASTA, local NT database, taxonomy files, helper script directory | NT-filtered FASTA and N50 reports |
| 02 assembly | `scripts/02_assembly/assembly_stats.py` | Implemented and CLI verified | Genome FASTA | Assembly stats TSV and optional per-sequence lengths |
| 03 repeat | `scripts/03_repeat/LTR_Finder.sh` | Reference-derived; cleaned wrapper | Uppercase genome FASTA | LTR_FINDER candidate file |
| 03 repeat | `scripts/03_repeat/LTR_harvest.sh` | Reference-derived; cleaned wrapper | Uppercase genome FASTA | LTRharvest candidate file |
| 03 repeat | `scripts/03_repeat/repeatmodeler.sh` | Reference-derived; cleaned wrapper | Uppercase genome FASTA | RepeatModeler libraries |
| 03 repeat | `scripts/03_repeat/work.sh` | Reference-derived; cleaned wrapper | LTR_FINDER and LTRharvest candidates | LTR_retriever library and pass list |
| 03 repeat | `scripts/03_repeat/rmout2gff.sh` | Reference-derived; review before use | RepeatMasker `.out` | Repeat GFF3 |
| 03 repeat | `scripts/03_repeat/repeat_stat.sh` | Reference-derived; review before use | RepeatMasker `.out`, genome size | Repeat coverage summary |
| 03 repeat | `scripts/03_repeat/trf.sh` | Reference-derived; cleaned wrapper | Genome FASTA | TRF `.dat` and optional GFF3 |
| 04 GFF | `scripts/04_gff/gff_cds_pep.py` | Implemented and CLI verified | Genome FASTA, annotation GFF, manifest | Clean GFF/CDS/PEP and CDS QC tables |
| 05 genome features | `scripts/05_genome_features/extract_introns.py` | Implemented and CLI verified | Annotation GFF, optional genome FASTA | Intron BED/TSV, unique loci, short introns, AT-rich summaries |
| 05 genome features | `scripts/05_genome_features/run_introner_elements.sh` | Reference-derived; cleaned wrapper | GFF, directory list, external Introner-elements path | Introner candidate workflow outputs |
| 06 annotation | `scripts/06_annotation/parse_interproscan_tsv.py` | Implemented and CLI verified | InterProScan TSV | Parsed InterPro/Pfam table |
| 06 annotation | `scripts/06_annotation/parse_kofam_detail.py` | Implemented and CLI verified | Kofam detail output | KO table |
| 06 annotation | `scripts/06_annotation/merge_function_annotations.py` | Implemented and CLI verified | GFF, CDS QC, database outputs | `functional_annotation.tsv` |
| 06 annotation | `scripts/06_annotation/kegg/*.pl` | Reference-derived; review before use | KEGG/pathway inputs | KEGG helper outputs |
| 07 phylogeny | `scripts/07_phylogeny/prefix_fasta_ids.py` | Implemented and CLI verified | Protein FASTA | Prefixed FASTA and ID map |
| 07 phylogeny | `scripts/07_phylogeny/extract_orthogroup_members.py` | Implemented and CLI verified | OrthoFinder outputs | Per-family ID lists |
| 07 phylogeny | `scripts/07_phylogeny/clean_pep_for_tree.py` | Implemented and CLI verified | Peptide FASTA | Clean peptide FASTA |
| 07 phylogeny | `scripts/07_phylogeny/concat_alignments.py` | Implemented and CLI verified | Trimmed alignments | Supermatrix, partition, stats |
| 07 phylogeny | `scripts/07_phylogeny/select_genes_by_function.py` | Implemented and CLI verified | Functional annotation | Target gene IDs |
| 07 phylogeny | `scripts/07_phylogeny/select_blast_hits.py` | Implemented and CLI verified | BLAST/DIAMOND TSV | Selected subject IDs |
| 07 phylogeny | `scripts/07_phylogeny/build_function_tree_tip_table.py` | Implemented and CLI verified | Target/outgroup/marker inputs | Tree-tip annotation table |
| 07 phylogeny | `scripts/07_phylogeny/make_tree_tip_annotation.py` | Implemented and CLI verified | Functional annotation and ID map | Tree-tip metadata |
| 07 phylogeny | `scripts/07_phylogeny/rename_tree_tips.py` | Implemented and CLI verified | Tree and tip map | Renamed tree |
| 07 phylogeny | `scripts/07_phylogeny/root_tree.py` | Implemented; limited placeholder behavior | Tree and outgroup note | Copied tree plus rooting note |
| 07 phylogeny | `scripts/07_phylogeny/summarize_gene_trees.py` | Implemented and CLI verified | Tree list, alignment dir, IQ-TREE dir | Gene-tree summary |
| 08 CAFE | `scripts/08_cafe/prepare_cafe_input.py` | Implemented and CLI verified | OrthoFinder count table, species tree | CAFE input table |
| 08 CAFE | `scripts/08_cafe/filter_cafe_families.py` | Implemented and CLI verified | CAFE input table | Filtered and removed-family tables |
| 09 synteny | `scripts/09_synteny/anchors_to_circos_links.py` | Implemented and CLI verified | Anchor/simple file and BED maps | Circos link file |
| 10 HGT | `scripts/10_hgt/01_classify_hgt_hits.py` | Implemented and CLI verified | Hits and local taxonomy table | Classified HGT hit table |
| 10 HGT | `scripts/10_hgt/02_score_hgt_candidates.py` | Implemented and CLI verified | Classified hits | Candidate and rejected HGT tables |
| 10 HGT | `scripts/10_hgt/03_add_hgt_context.py` | Implemented and CLI verified | Candidates, GFF, optional context | HGT context table and BED |
| 10 HGT | `scripts/10_hgt/04_prepare_hgt_validation.py` | Implemented and CLI verified | Context and classified hits | Validation manifest and ID lists |
| 11 visualization | `scripts/11_visualization/circos/*` | Reference-derived; review before use | Track-specific inputs | Circos helper outputs |

## Deprecated or legacy notes

- Prefer `scripts/03_repeat/repeat_stat.sh` over `scripts/03_repeat/stat.sh`.
- Prefer `scripts/07_phylogeny/rename_tree_tips.py` over legacy tree renaming scripts.
- Prefer `scripts/09_synteny/anchors_to_circos_links.py` over legacy `simple2links.py`.
- `root_tree.py` does not reroot a Newick tree; use external tree tools for true rerooting.

## Extension rule

Every new script should be added to this inventory, documented in the SOP and command templates, and covered by validation where practical.
