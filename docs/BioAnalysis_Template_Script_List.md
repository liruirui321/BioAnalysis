# BioAnalysis Script Reference

This document lists maintained helper scripts, reference-derived scripts, and external tool entry points by numbered workflow stage.

Status labels match [`../scripts/SCRIPT_SOURCES.md`](../scripts/SCRIPT_SOURCES.md).

## Script inventory

| Stage | Script | Status | Input | Output / handoff |
|---|---|---|---|---|
| common | `scripts/common/bioio.py` | Maintained helper library | FASTA/GFF/TSV paths | Shared IO functions for Python scripts |
| 01 preprocessing | `scripts/01_preprocessing/01_nt_decontaminate_contigs.sh` | Reference-derived; cleaned wrapper | Assembly FASTA, local NT database, taxonomy files, helper script directory | NT-filtered FASTA and N50 reports |
| 02 assembly | `scripts/02_assembly/assembly_stats.py` | Implemented and CLI verified | Genome FASTA | Assembly stats TSV and optional per-sequence lengths |
| 02 assembly | `scripts/02_assembly/run_busco_qc_workflow.sh` | Implemented and CLI verified | Genome/protein/transcript FASTA or BUSCO short summaries | BUSCO summary TSV and optional assembly stats |
| 02 assembly | `scripts/02_assembly/summarize_busco_results.py` | Implemented and CLI verified | BUSCO short_summary JSON/TXT | Stable BUSCO summary TSV |
| 02 assembly | `scripts/02_assembly/run_lai_qc_workflow.sh` | Implemented and CLI verified | Genome FASTA or existing LAI outputs | LAI work directory and summary TSV |
| 02 assembly | `scripts/02_assembly/summarize_lai_results.py` | Implemented and CLI verified | LTR_retriever LAI output files | Stable LAI summary TSV |
| 02 assembly | `scripts/02_assembly/run_merqury_qv_workflow.sh` | Implemented and CLI verified | Genome FASTA plus read files, or existing Merqury outputs | Merqury work directory and QV summary TSV |
| 02 assembly | `scripts/02_assembly/summarize_merqury_qv.py` | Implemented and CLI verified | Merqury QV/completeness output files | Stable Merqury QV summary TSV |
| 03 repeat | `scripts/03_repeat/run_repeat_annotation_workflow.sh` | Implemented and CLI verified | Genome FASTA and optional RepeatMasker output | Chained repeat annotation outputs and summaries |
| 03 repeat | `scripts/03_repeat/run_te_eve_postprocessing_workflow.sh` | Implemented and CLI verified | TEsorter domains, target/EVE regions, RepeatMasker `.out` | Chained TE-domain, EVE/GEVE region, and divergence handoff tables |
| 03 repeat | `scripts/03_repeat/parse_tesorter_domains.py` | Implemented and CLI verified | TEsorter domain FASTA | Normalized TE-domain table and domain summary |
| 03 repeat | `scripts/03_repeat/summarize_tesorter_regions.py` | Implemented and CLI verified | Parsed TEsorter domains and target/background BED | Region-labeled TE-domain summary and details |
| 03 repeat | `scripts/03_repeat/summarize_te_divergence.py` | Implemented and CLI verified | RepeatMasker `.out` | Per-repeat divergence table and class/family summary |
| 03 repeat | `scripts/03_repeat/standardize_eve_geve_regions.py` | Implemented and CLI verified | External EVE/GEVE BED, GFF, or TSV | Standardized EVE/GEVE BED and TSV |
| 03 repeat | `scripts/03_repeat/LTR_Finder.sh` | Reference-derived; cleaned wrapper | Uppercase genome FASTA | LTR_FINDER candidate file |
| 03 repeat | `scripts/03_repeat/LTR_harvest.sh` | Reference-derived; cleaned wrapper | Uppercase genome FASTA | LTRharvest candidate file |
| 03 repeat | `scripts/03_repeat/repeatmodeler.sh` | Reference-derived; cleaned wrapper | Uppercase genome FASTA | RepeatModeler libraries |
| 03 repeat | `scripts/03_repeat/work.sh` | Reference-derived; cleaned wrapper | LTR_FINDER and LTRharvest candidates | LTR_retriever library and pass list |
| 03 repeat | `scripts/03_repeat/rmout2gff.sh` | Reference-derived; review before use | RepeatMasker `.out` | Repeat GFF3 |
| 03 repeat | `scripts/03_repeat/repeat_stat.sh` | Reference-derived; review before use | RepeatMasker `.out`, genome size | Repeat coverage summary |
| 03 repeat | `scripts/03_repeat/trf.sh` | Reference-derived; cleaned wrapper | Genome FASTA | TRF `.dat` and optional GFF3 |
| 04 GFF | `scripts/04_gff/gff_cds_pep.py` | Implemented and CLI verified | Genome FASTA, annotation GFF, manifest | Clean GFF/CDS/PEP and CDS QC tables |
| 04 GFF | `scripts/04_gff/run_gff_structure_workflow.sh` | Implemented and CLI verified | Main GFF and optional comparison GFFs or manifest | Chained GFF structure statistics, QC tables, plot handoff tables, and optional R plots |
| 04 GFF | `scripts/04_gff/summarize_gff_structure.py` | Implemented and CLI verified | GFF/GFF3 and optional genome FASTA | Gene/transcript/exon/CDS/intron/isoform metrics, raw distributions, reference-style binned percent distributions, chromosome summaries, feature summaries, and QC |
| 04 GFF | `scripts/04_gff/prepare_gff_structure_plot_handoff.py` | Implemented and CLI verified | GFF structure metrics and distributions | Plot-ready metric matrix and long distribution table |
| 04 GFF | `scripts/04_gff/plot_gff_structure.R` | Implemented and CLI verified | Reference-style binned GFF structure distributions | Base-R PDF mRNA/CDS/exon/intron length distribution and exon-number distribution plots |
| 05 genome features | `scripts/05_genome_features/run_genome_features_workflow.sh` | Implemented and CLI verified | Annotation GFF, genome FASTA, optional Introner-elements inputs | Chained intron outputs and optional introner candidate workflow |
| 05 genome features | `scripts/05_genome_features/run_region_context_workflow.sh` | Implemented and CLI verified | Target BED, optional feature track, optional Bismark CX report | Feature enrichment and methylation metaprofile handoff tables |
| 05 genome features | `scripts/05_genome_features/compare_region_feature_enrichment.py` | Implemented and CLI verified | Target/background BED and feature BED/GFF | Feature overlap, coverage, and enrichment summary |
| 05 genome features | `scripts/05_genome_features/summarize_bismark_cx_regions.py` | Implemented and CLI verified | Bismark CX report and target BED | CG/CHG/CHH methylation bin and context summaries |
| 05 genome features | `scripts/05_genome_features/extract_introns.py` | Implemented and CLI verified | Annotation GFF, optional genome FASTA | Intron BED/TSV, unique loci, short introns, AT-rich summaries |
| 05 genome features | `scripts/05_genome_features/run_introner_elements.sh` | Reference-derived; cleaned wrapper | GFF, directory list, external Introner-elements path | Introner candidate workflow outputs |
| 06 annotation | `scripts/06_annotation/run_functional_annotation_workflow.sh` | Implemented and CLI verified | GFF and optional database annotation outputs | Chained parsed, merged, term-summary, domain, and enrichment outputs |
| 06 annotation | `scripts/06_annotation/parse_interproscan_tsv.py` | Implemented and CLI verified | InterProScan TSV | Parsed InterPro/Pfam table |
| 06 annotation | `scripts/06_annotation/parse_kofam_detail.py` | Implemented and CLI verified | Kofam detail output | KO table |
| 06 annotation | `scripts/06_annotation/merge_function_annotations.py` | Implemented and CLI verified | GFF, CDS QC, database outputs | `functional_annotation.tsv` |
| 06 annotation | `scripts/06_annotation/summarize_go_terms.py` | Implemented and CLI verified | Functional annotation table | Gene-to-GO table and GO count summary |
| 06 annotation | `scripts/06_annotation/summarize_kegg_pathways.py` | Implemented and CLI verified | Functional annotation table and KO-to-pathway map | Gene-to-pathway table, pathway counts, unmapped KO report |
| 06 annotation | `scripts/06_annotation/summarize_pfam_domains.py` | Implemented and CLI verified | Functional annotation table | Gene-to-Pfam table and Pfam count summary |
| 06 annotation | `scripts/06_annotation/summarize_domain_architecture.py` | Implemented and CLI verified | Parsed InterProScan table | Per-query Pfam architecture and architecture summary |
| 06 annotation | `scripts/06_annotation/summarize_eggnog_categories.py` | Implemented and CLI verified | eggNOG-mapper/emapper output | Gene-to-category and COG/NOG category summary tables |
| 06 annotation | `scripts/06_annotation/enrich_annotation_terms.py` | Implemented and CLI verified | Functional annotation table and foreground gene IDs | GO/KEGG/Pfam enrichment table |
| 06 annotation | `scripts/06_annotation/prepare_go_semantic_handoff.py` | Implemented and CLI verified | GO enrichment results | Plot-ready GO semantic handoff table |
| 06 annotation | `scripts/06_annotation/run_go_enrichment_plot_handoff.sh` | Implemented and CLI verified | Functional annotation table and foreground IDs | GO enrichment and semantic-plot handoff outputs |
| 06 annotation | `scripts/06_annotation/kegg/*.pl` | Reference-derived; review before use | KEGG/pathway inputs | KEGG helper outputs |
| 07 gene family | `scripts/07_gene_family/run_gene_family_workflow.sh` | Implemented and CLI verified | OrthoFinder count table and optional protein/alignment inputs | Chained gene-family summary, member extraction, and supermatrix handoffs |
| 07 gene family | `scripts/07_gene_family/run_target_family_workflow.sh` | Implemented and CLI verified | Functional annotation, target rules, optional BLAST/seed/expression inputs | Target-family evidence, selected IDs, peptide FASTA, tip metadata, and expression summaries |
| 07 gene family | `scripts/07_gene_family/merge_target_family_evidence.py` | Implemented and CLI verified | Functional annotation, target rules, optional BLAST/seed inputs | Target-family evidence table, selected IDs, and summary |
| 07 gene family | `scripts/07_gene_family/build_target_family_inputs.py` | Implemented and CLI verified | Target IDs, peptide FASTA, optional annotation/evidence | Target peptide FASTA and tree-tip metadata |
| 07 gene family | `scripts/07_gene_family/summarize_gene_set_expression.py` | Implemented and CLI verified | Expression matrix and target-family evidence | Gene-level and family-level expression summaries |
| 07 gene family | `scripts/07_gene_family/prefix_fasta_ids.py` | Implemented and CLI verified | Protein FASTA | Prefixed FASTA and ID map |
| 07 gene family | `scripts/07_gene_family/summarize_orthofinder_gene_families.py` | Implemented and CLI verified | OrthoFinder orthogroup and gene-count tables | Family summary and selected orthogroup lists |
| 07 gene family | `scripts/07_gene_family/extract_orthogroup_members.py` | Implemented and CLI verified | OrthoFinder outputs | Per-family ID lists |
| 07 gene family | `scripts/07_gene_family/clean_pep_for_tree.py` | Implemented and CLI verified | Peptide FASTA | Clean peptide FASTA |
| 07 gene family | `scripts/07_gene_family/concat_alignments.py` | Implemented and CLI verified | Trimmed alignments | Supermatrix, partition, stats |
| 07 gene family | `scripts/07_gene_family/select_genes_by_function.py` | Implemented and CLI verified | Functional annotation | Target gene IDs |
| 07 gene family | `scripts/07_gene_family/select_blast_hits.py` | Implemented and CLI verified | BLAST/DIAMOND TSV | Selected subject IDs |
| 07 gene family | `scripts/07_gene_family/build_function_tree_tip_table.py` | Implemented and CLI verified | Target/outgroup/marker inputs | Tree-tip annotation table |
| 07 gene family | `scripts/07_gene_family/make_tree_tip_annotation.py` | Implemented and CLI verified | Functional annotation and ID map | Tree-tip metadata |
| 07 gene family | `scripts/07_gene_family/rename_tree_tips.py` | Implemented and CLI verified | Tree and tip map | Renamed tree |
| 07 gene family | `scripts/07_gene_family/root_tree.py` | Implemented; limited placeholder behavior | Tree and outgroup note | Copied tree plus rooting note |
| 07 gene family | `scripts/07_gene_family/summarize_gene_trees.py` | Implemented and CLI verified | Tree list, alignment dir, IQ-TREE dir | Gene-tree summary |
| 08 gene-family evolution | `scripts/08_gene_family_evolution/run_gene_family_evolution_workflow.sh` | Implemented and CLI verified | OrthoFinder count table, species tree, optional Count output | Chained Count and CAFE input/filtering summaries |
| 08 gene-family evolution | `scripts/08_gene_family_evolution/prepare_count_input.py` | Implemented and CLI verified | OrthoFinder count table, species tree | Count-ready family matrix and rejected-family report |
| 08 gene-family evolution | `scripts/08_gene_family_evolution/parse_count_gain_loss.py` | Implemented and CLI verified | Count gain/loss output | Normalized family-node gain/loss table |
| 08 gene-family evolution | `scripts/08_gene_family_evolution/summarize_family_gain_loss.py` | Implemented and CLI verified | Parsed Count gain/loss table and optional family summary | Family-level and node-level gain/loss summaries |
| 08 gene-family evolution | `scripts/08_gene_family_evolution/integrate_target_family_evolution.py` | Implemented and CLI verified | Target-family evidence, orthogroups, family gain/loss table | Target-family evolution detail and summary tables |
| 08 gene-family evolution | `scripts/08_gene_family_evolution/prepare_cafe_input.py` | Implemented and CLI verified | OrthoFinder count table, species tree | CAFE input table |
| 08 gene-family evolution | `scripts/08_gene_family_evolution/filter_cafe_families.py` | Implemented and CLI verified | CAFE input table | Filtered and removed-family tables |
| 09 synteny | `scripts/09_synteny/run_synteny_context_workflow.sh` | Implemented and CLI verified | MCScanX/JCVI synteny file, optional gene and region BED | Normalized synteny tables, heatmap matrix, and region synteny summaries |
| 09 synteny | `scripts/09_synteny/summarize_mcscan_jcvi_synteny.py` | Implemented and CLI verified | Anchor/simple/table synteny file | Normalized synteny detail and pair summary tables |
| 09 synteny | `scripts/09_synteny/build_synteny_heatmap_matrix.py` | Implemented and CLI verified | Synteny pair summary table | Heatmap-ready pairwise matrix |
| 09 synteny | `scripts/09_synteny/compare_region_synteny.py` | Implemented and CLI verified | Normalized synteny table, gene BED, target/background BED | Target/background synteny support summary |
| 09 synteny | `scripts/09_synteny/anchors_to_circos_links.py` | Implemented and CLI verified | Anchor/simple file and BED maps | Circos link file |
| 10 HGT | `scripts/10_hgt/run_hgt_blast2hgt_workflow.sh` | Implemented and CLI verified | Query FASTA, NR BLAST/DIAMOND outputs or taxon-group DIAMOND databases, external blast2hgt directory | Chained HGT candidate, context, and validation outputs |
| 10 HGT | `scripts/10_hgt/run_hgt_family_integration_workflow.sh` | Implemented and CLI verified | HGT candidates, optional donor taxonomy, orthogroups, target-family evidence, family gain/loss table | Refined donor and HGT-family evolution support summaries |
| 10 HGT | `scripts/10_hgt/00_run_blast2hgt_handoff.sh` | Reference-derived; cleaned wrapper | Query FASTA, NR BLAST/DIAMOND outfmt 6 outputs, external blast2hgt directory | Blast2hgt `.rp.bls`, `.rp.taxid`, `.rp.lin`, and `.rp.tsv` files |
| 10 HGT | `scripts/10_hgt/filter_blast2hgt_candidates.py` | Implemented and CLI verified | Blast2hgt `.rp.tsv` table | Candidate and rejected HGT tables |
| 10 HGT | `scripts/10_hgt/refine_hgt_donor_taxonomy.py` | Implemented and CLI verified | HGT candidates and optional local donor taxonomy table | Refined donor table and donor-taxonomy summary |
| 10 HGT | `scripts/10_hgt/integrate_hgt_family_evolution.py` | Implemented and CLI verified | HGT candidates, refined donors, orthogroups, target-family evidence, family gain/loss table | HGT-family evolution support table |
| 10 HGT | `scripts/10_hgt/01_classify_hgt_hits.py` | Implemented and CLI verified | Hits and local taxonomy table | Classified HGT hit table |
| 10 HGT | `scripts/10_hgt/02_score_hgt_candidates.py` | Implemented and CLI verified | Classified hits | Candidate and rejected HGT tables |
| 10 HGT | `scripts/10_hgt/03_add_hgt_context.py` | Implemented and CLI verified | Candidates, GFF, optional context | HGT context table and BED |
| 10 HGT | `scripts/10_hgt/04_prepare_hgt_validation.py` | Implemented and CLI verified | Context and classified hits | Validation manifest and ID lists |
| 11 visualization | `scripts/11_visualization/run_visualization_handoff_workflow.sh` | Implemented and CLI verified | Gene sets, expression summaries, target evolution tables, HGT-family tables | Plot-ready matrices and matrix manifests |
| 11 visualization | `scripts/11_visualization/build_gene_set_matrix.py` | Implemented and CLI verified | Multiple gene ID sets | UpSet/Venn-style membership matrix |
| 11 visualization | `scripts/11_visualization/prepare_family_visualization_matrices.py` | Implemented and CLI verified | Expression, target-evolution, and HGT-family tables | Family visualization matrices and manifest |
| 11 visualization | `scripts/11_visualization/circos/*` | Reference-derived; review before use | Track-specific inputs | Circos helper outputs |

## Deprecated or legacy notes

- Prefer `scripts/03_repeat/repeat_stat.sh` over `scripts/03_repeat/stat.sh`.
- Prefer `scripts/07_gene_family/rename_tree_tips.py` over legacy tree renaming scripts.
- Prefer `scripts/09_synteny/anchors_to_circos_links.py` over legacy `simple2links.py`.
- `root_tree.py` does not reroot a Newick tree; use external tree tools for true rerooting.

## Extension rule

Every new script should be added to this inventory, documented in the SOP and command templates, and covered by validation where practical.
