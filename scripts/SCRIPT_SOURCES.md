# BioAnalysis Script Sources

This file records provenance, implementation status, and review requirements for scripts under `scripts/`.

Reusable repository files must use anonymized examples such as `Arabidopsis_thaliana`, `Arabidopsis_lyrata`, and `Arabidopsis_halleri`. Do not commit real project paths, sample IDs, database paths, or user-specific installation paths.

## Status labels

| Status | Meaning |
|---|---|
| Implemented and CLI verified | Maintained helper script with an explicit CLI used by the SOP. |
| Implemented; limited placeholder behavior | Script exists but intentionally performs only a handoff or limited operation. |
| Reference-derived; cleaned wrapper | Historical/reference logic retained after path cleanup and CLI normalization. |
| Reference-derived; review before use | Historical/reference script retained for compatibility; inspect inputs and dependencies before production use. |
| Deprecated historical reference | Older script kept only for provenance; prefer the maintained replacement. |
| External tool; not included | Third-party tool invoked by the SOP and installed separately. |

## Maintained BioAnalysis scripts

| Script | Status | Purpose |
|---|---|---|
| `01_preprocessing/run_fastp_rna_read_filtering_workflow.sh` | Reference-derived; cleaned wrapper | Run fastp filtering and optional FastQC on RNA-seq raw reads. |
| `01_preprocessing/run_fastp_wgs_read_filtering_workflow.sh` | Reference-derived; cleaned wrapper | Run fastp filtering and optional FastQC on WGS raw reads. |
| `01_preprocessing/run_trimmomatic_rna_read_filtering_workflow.sh` | Reference-derived; cleaned wrapper | Run Trimmomatic filtering on RNA-seq raw reads. |
| `01_preprocessing/run_trimmomatic_wgs_read_filtering_workflow.sh` | Reference-derived; cleaned wrapper | Run Trimmomatic filtering on WGS raw reads. |
| `01_preprocessing/01_nt_decontaminate_contigs.sh` | Reference-derived; cleaned wrapper | Run local NT-based contig decontamination using user-supplied BLAST database and helper scripts. |
| `02_assembly/assembly_stats.py` | Implemented and CLI verified | Compute assembly length, N50/L50, N90/L90, GC, and N statistics. |
| `02_genome_survey/run_genome_survey_workflow.sh` | Reference-derived; cleaned wrapper | Run independent Jellyfish, GenomeScope2, and optional Smudgeplot genome survey from read files. |
| `02_genome_survey/run_ploidyngs_workflow.sh` | Reference-derived; cleaned wrapper | Run independent ploidyNGS WGS/BAM ploidy estimation and histogram handoff generation. |
| `02_assembly/run_hifiasm_assembly.sh` | Reference-derived; cleaned wrapper | Run independent hifiasm assembly with optional native Hi-C reads and expose stable FASTA/stat outputs. |
| `02_assembly/run_nextdenovo_assembly.sh` | Reference-derived; cleaned wrapper | Run independent NextDenovo assembly from long-read files or FOFN and expose stable FASTA/stat outputs. |
| `02_assembly/run_spades_assembly.sh` | Reference-derived; cleaned wrapper | Run independent SPAdes assembly from paired-end libraries and expose stable FASTA/stat outputs. |
| `02_assembly/run_flye_assembly.sh` | Reference-derived; cleaned wrapper | Run independent Flye assembly from ONT, PacBio CLR, or HiFi reads and expose stable FASTA/stat outputs. |
| `02_assembly/run_canu_assembly.sh` | Reference-derived; cleaned wrapper | Run independent Canu assembly from ONT, PacBio CLR, or HiFi reads and expose stable FASTA/stat outputs. |
| `02_assembly/run_verkko_assembly.sh` | Reference-derived; cleaned wrapper | Run independent Verkko assembly from HiFi and optional ONT/Hi-C reads and expose stable FASTA/stat outputs. |
| `02_assembly/run_yahs_scaffolding.sh` | Reference-derived; cleaned wrapper | Run independent YaHS Hi-C scaffolding from an existing assembly and Hi-C read pair. |
| `02_assembly/run_haphic_scaffolding.sh` | Reference-derived; cleaned wrapper | Run independent HapHiC Hi-C scaffolding from an existing assembly and Hi-C read pair. |
| `02_assembly/run_pandepth_coverage_workflow.sh` | Reference-derived; cleaned wrapper | Map WGS or long reads to an assembly and run PanDepth sliding-window coverage summaries. |
| `02_assembly/run_gc_depth_workflow.sh` | Reference-derived; cleaned wrapper | Map WGS or long reads to an assembly and generate GC-depth coverage handoff files. |
| `02_assembly/run_busco_qc_workflow.sh` | Implemented and CLI verified | Run or summarize BUSCO assessment independently and optionally write assembly/N50 stats. |
| `02_assembly/summarize_busco_results.py` | Implemented and CLI verified | Summarize BUSCO short_summary JSON/TXT outputs into a stable TSV. |
| `02_assembly/run_lai_qc_workflow.sh` | Implemented and CLI verified | Run or summarize LAI assessment independently using GenomeTools, LTR_FINDER_parallel, and LTR_retriever. |
| `02_assembly/summarize_lai_results.py` | Implemented and CLI verified | Summarize LTR_retriever LAI output files into a stable TSV. |
| `02_assembly/run_merqury_qv_workflow.sh` | Implemented and CLI verified | Run or summarize Merqury QV assessment independently using meryl and merqury.sh. |
| `02_assembly/summarize_merqury_qv.py` | Implemented and CLI verified | Summarize Merqury QV and completeness outputs into a stable TSV. |
| `03_repeat/run_repeat_annotation_workflow.sh` | Implemented and CLI verified | Chain uppercase genome preparation, LTR discovery, RepeatModeler, LTR_retriever, TRF, and optional RepeatMasker summaries. |
| `03_repeat/run_te_eve_postprocessing_workflow.sh` | Implemented and CLI verified | Chain TEsorter parsing, target-region TE summaries, RepeatMasker divergence summaries, and EVE/GEVE region standardization. |
| `03_repeat/parse_tesorter_domains.py` | Implemented and CLI verified | Parse TEsorter domain FASTA headers into normalized domain and class summary tables. |
| `03_repeat/summarize_tesorter_regions.py` | Implemented and CLI verified | Label parsed TEsorter domains by overlap with target EVE/GEVE regions and optional background regions. |
| `03_repeat/summarize_te_divergence.py` | Implemented and CLI verified | Summarize RepeatMasker divergence and optional insertion-time estimates by repeat class and family. |
| `03_repeat/standardize_eve_geve_regions.py` | Implemented and CLI verified | Standardize external EVE/GEVE region calls from BED, GFF, or TSV into BED and TSV handoffs. |
| `03_repeat/LTR_Finder.sh` | Reference-derived; cleaned wrapper | Run `LTR_FINDER_parallel` from `PATH`. |
| `03_repeat/LTR_harvest.sh` | Reference-derived; cleaned wrapper | Run GenomeTools suffixerator and LTRharvest from `PATH`. |
| `03_repeat/work.sh` | Reference-derived; cleaned wrapper | Merge LTR candidates and run `LTR_retriever`. |
| `03_repeat/repeatmodeler.sh` | Reference-derived; cleaned wrapper | Build a RepeatModeler database and run RepeatModeler from `PATH`. |
| `03_repeat/trf.sh` | Reference-derived; cleaned wrapper | Run TRF and optional `trf2gff`. |
| `03_repeat/rmout2gff.sh` | Reference-derived; review before use | Convert RepeatMasker `.out` to GFF3. |
| `03_repeat/repeat_stat.sh` | Reference-derived; review before use | Summarize RepeatMasker coverage by repeat class. |
| `04_gene_prediction/run_hisat2_rnaseq_alignment_workflow.sh` | Reference-derived; cleaned wrapper | Build RNA-seq BAM evidence with HISAT2 and samtools for gene prediction. |
| `04_gene_prediction/run_braker3_annotation_workflow.sh` | Reference-derived; cleaned wrapper | Run BRAKER3 gene prediction from a soft-masked genome, protein evidence, and RNA-seq BAMs. |
| `04_gff/gff_cds_pep.py` | Implemented and CLI verified | Extract clean GFF/CDS/PEP files and CDS QC tables. |
| `04_gff/run_gff_structure_workflow.sh` | Implemented and CLI verified | Chain GFF structure statistics, multi-species comparison, plot-ready handoffs, and optional base-R plots. |
| `04_gff/summarize_gff_structure.py` | Implemented and CLI verified | Summarize gene, transcript, exon, CDS, intron, isoform, chromosome, feature, QC metrics, and reference-style binned percent distributions from GFF/GFF3. |
| `04_gff/prepare_gff_structure_plot_handoff.py` | Implemented and CLI verified | Prepare plot-ready metric matrices and long distribution tables from GFF structure summaries. |
| `04_gff/plot_gff_structure.R` | Implemented and CLI verified | Create reference-style base-R PDF plots for mRNA/CDS/exon/intron length distributions and exon-number distributions. |
| `05_genome_features/run_genome_features_workflow.sh` | Implemented and CLI verified | Chain intron extraction outputs and optional Introner-elements execution. |
| `05_genome_features/run_region_context_workflow.sh` | Implemented and CLI verified | Chain target-region feature enrichment and optional Bismark CX methylation summaries. |
| `05_genome_features/compare_region_feature_enrichment.py` | Implemented and CLI verified | Compare target and optional background region overlap against BED or GFF feature tracks. |
| `05_genome_features/summarize_bismark_cx_regions.py` | Implemented and CLI verified | Summarize Bismark CX methylation over target regions using upstream/body/downstream bins. |
| `05_genome_features/extract_introns.py` | Implemented and CLI verified | Infer introns, unique intron loci, short introns, and AT-rich intron summaries. |
| `05_genome_features/run_introner_elements.sh` | Reference-derived; cleaned wrapper | Run an external Introner-elements workflow using user-supplied tool paths. |
| `06_annotation/run_kofam_annotation_workflow.sh` | Reference-derived; cleaned wrapper | Run KofamScan exec_annotation, parse detail output, and write legacy KO aggregation. |
| `06_annotation/run_enrichpipeline_enrichment_workflow.sh` | Reference-derived; cleaned wrapper | Run a user-supplied local EnrichPipeline installation for GO, KEGG, or IPR enrichment without vendoring the archive or databases. |
| `06_annotation/run_functional_annotation_workflow.sh` | Implemented and CLI verified | Chain annotation parsing, merging, downstream term summaries, domain architecture summaries, and optional enrichment. |
| `06_annotation/parse_interproscan_tsv.py` | Implemented and CLI verified | Parse InterProScan TSV into a compact annotation table. |
| `06_annotation/parse_kofam_detail.py` | Implemented and CLI verified | Parse KofamScan detail output. |
| `06_annotation/merge_function_annotations.py` | Implemented and CLI verified | Merge structural, CDS QC, InterPro/Pfam, eggNOG, Kofam, SwissProt, and NR annotations. |
| `06_annotation/summarize_go_terms.py` | Implemented and CLI verified | Produce long gene-to-GO and GO term count tables. |
| `06_annotation/summarize_kegg_pathways.py` | Implemented and CLI verified | Map KO annotations to pathways and report pathway counts and unmapped KOs. |
| `06_annotation/summarize_pfam_domains.py` | Implemented and CLI verified | Produce long gene-to-Pfam and Pfam count tables. |
| `06_annotation/summarize_domain_architecture.py` | Implemented and CLI verified | Summarize ordered Pfam domain architectures from parsed InterProScan output. |
| `06_annotation/summarize_eggnog_categories.py` | Implemented and CLI verified | Summarize eggNOG-mapper COG/NOG category assignments into gene-level and category-level tables. |
| `06_annotation/enrich_annotation_terms.py` | Implemented and CLI verified | Run GO, KEGG, or Pfam overrepresentation tests for foreground gene sets. |
| `06_annotation/prepare_go_semantic_handoff.py` | Implemented and CLI verified | Prepare GO enrichment results for external semantic-space visualization tools. |
| `06_annotation/run_go_enrichment_plot_handoff.sh` | Implemented and CLI verified | Chain GO enrichment and semantic-visualization handoff table preparation. |
| `07_gene_family/run_gene_family_workflow.sh` | Implemented and CLI verified | Chain optional FASTA prefixing, OrthoFinder handoff, family summaries, member extraction, and supermatrix handoff. |
| `07_gene_family/run_target_family_workflow.sh` | Implemented and CLI verified | Chain rule-based target-family evidence merging, peptide handoff generation, and optional expression summaries. |
| `07_gene_family/merge_target_family_evidence.py` | Implemented and CLI verified | Merge functional annotation, rule-table, BLAST/DIAMOND, and seed evidence for target functional families. |
| `07_gene_family/build_target_family_inputs.py` | Implemented and CLI verified | Build target peptide FASTA and tree-tip metadata from selected gene IDs. |
| `07_gene_family/summarize_gene_set_expression.py` | Implemented and CLI verified | Summarize expression matrices by target family or selected gene set. |
| `07_gene_family/prefix_fasta_ids.py` | Implemented and CLI verified | Prefix FASTA IDs and write an ID map. |
| `07_gene_family/summarize_orthofinder_gene_families.py` | Implemented and CLI verified | Summarize OrthoFinder families by copy number, occupancy, and selected family classes. |
| `07_gene_family/extract_orthogroup_members.py` | Implemented and CLI verified | Extract orthogroup member lists. |
| `07_gene_family/clean_pep_for_tree.py` | Implemented and CLI verified | Clean peptide FASTA records before tree building. |
| `07_gene_family/concat_alignments.py` | Implemented and CLI verified | Concatenate alignments into a supermatrix and partition table. |
| `07_gene_family/select_genes_by_function.py` | Implemented and CLI verified | Select genes using functional annotation fields. |
| `07_gene_family/select_blast_hits.py` | Implemented and CLI verified | Select sequence hits from BLAST/DIAMOND-style tables. |
| `07_gene_family/build_function_tree_tip_table.py` | Implemented and CLI verified | Build tree-tip annotation tables for selected genes. |
| `07_gene_family/make_tree_tip_annotation.py` | Implemented and CLI verified | Create tree-tip metadata. |
| `07_gene_family/rename_tree_tips.py` | Implemented and CLI verified | Rename tree tips using a mapping table. |
| `07_gene_family/root_tree.py` | Implemented; limited placeholder behavior | Copy a tree and write a rooting handoff note; it does not reroot topology. |
| `07_gene_family/summarize_gene_trees.py` | Implemented and CLI verified | Summarize gene-tree outputs and failures. |
| `08_gene_family_evolution/run_gene_family_evolution_workflow.sh` | Implemented and CLI verified | Chain Count input preparation, optional Count gain/loss summaries, and CAFE input filtering. |
| `08_gene_family_evolution/prepare_count_input.py` | Implemented and CLI verified | Convert OrthoFinder count tables to Count input while validating species names. |
| `08_gene_family_evolution/parse_count_gain_loss.py` | Implemented and CLI verified | Normalize Count gain/loss output to long or wide family-node tables. |
| `08_gene_family_evolution/summarize_family_gain_loss.py` | Implemented and CLI verified | Summarize Count gain/loss calls by family and node. |
| `08_gene_family_evolution/integrate_target_family_evolution.py` | Implemented and CLI verified | Integrate target-family evidence with orthogroups and Count/CAFE gain-loss outputs. |
| `08_gene_family_evolution/prepare_cafe_input.py` | Implemented and CLI verified | Convert OrthoFinder count tables to CAFE input. |
| `08_gene_family_evolution/filter_cafe_families.py` | Implemented and CLI verified | Filter CAFE families and record removed-family reasons. |
| `09_synteny/run_synteny_context_workflow.sh` | Implemented and CLI verified | Chain synteny normalization, heatmap matrix generation, and optional target/background region comparison. |
| `09_synteny/summarize_mcscan_jcvi_synteny.py` | Implemented and CLI verified | Normalize MCScanX/JCVI anchor, simple, or table outputs into stable synteny summaries. |
| `09_synteny/build_synteny_heatmap_matrix.py` | Implemented and CLI verified | Build pairwise heatmap-ready matrices from synteny summaries. |
| `09_synteny/compare_region_synteny.py` | Implemented and CLI verified | Compare synteny support in target regions versus optional background regions. |
| `09_synteny/anchors_to_circos_links.py` | Implemented and CLI verified | Convert synteny anchors/blocks to Circos links. |
| `10_hgt/run_hgt_nr_taxonlist_workflow.sh` | Reference-derived; cleaned wrapper | Run DIAMOND NR searches by taxonlist group for blast2hgt-compatible outfmt6 files. |
| `10_hgt/run_hgt_blast2hgt_workflow.sh` | Implemented and CLI verified | Chain NR hit input, blast2hgt handoff, candidate filtering, context annotation, and validation preparation. |
| `10_hgt/build_hgt_condition_matrices.py` | Implemented and CLI verified | Build comparable Condition1/Condition2 species HGT candidate tables and donor matrices from blast2hgt `.rp.tsv` inputs. |
| `10_hgt/prepare_hgt_orthogroup_inputs.py` | Implemented and CLI verified | Prepare HGT gene-source IDs and optional HGT-only protein FASTA for HGT orthogroup clustering. |
| `10_hgt/summarize_hgt_family_events.py` | Reference-derived; cleaned implementation | Summarize M1 gene-centric or M2 family-centric HGT-driven gain/expansion events from HGT/ALL orthogroups and count matrices. |
| `10_hgt/prepare_hgt_visualization_handoff.py` | Implemented and CLI verified | Prepare plot-ready HGT species donor and node-event handoff tables. |
| `10_hgt/run_hgt_full_method_workflow.sh` | Implemented and CLI verified | Chain HGT full-method handoffs from optional NR searches through Condition matrices, OG inputs, event summaries, and visualization tables. |
| `10_hgt/run_hgt_family_integration_workflow.sh` | Implemented and CLI verified | Chain donor-taxonomy refinement and HGT-family evolution integration. |
| `10_hgt/00_run_blast2hgt_handoff.sh` | Reference-derived; cleaned wrapper | Run a parameterized blast2hgt handoff from NR BLAST/DIAMOND outputs to taxonomy-group HGT tables. |
| `10_hgt/filter_blast2hgt_candidates.py` | Implemented and CLI verified | Filter blast2hgt `.rp.tsv` output into candidate and rejected HGT tables. |
| `10_hgt/refine_hgt_donor_taxonomy.py` | Implemented and CLI verified | Refine HGT candidate donor taxonomy using local lineage or taxonomy tables. |
| `10_hgt/integrate_hgt_family_evolution.py` | Implemented and CLI verified | Integrate HGT candidates with donor taxonomy, orthogroups, target-family evidence, and family-evolution calls. |
| `10_hgt/01_classify_hgt_hits.py` | Implemented and CLI verified | Classify similarity hits by local taxonomy groups for HGT screening. |
| `10_hgt/02_score_hgt_candidates.py` | Implemented and CLI verified | Score conservative HGT candidates from classified hits. |
| `10_hgt/03_add_hgt_context.py` | Implemented and CLI verified | Merge HGT candidates with coordinate, annotation, intron, and synteny context. |
| `10_hgt/04_prepare_hgt_validation.py` | Implemented and CLI verified | Prepare candidate and donor ID lists for phylogenetic validation. |
| `11_visualization/run_visualization_handoff_workflow.sh` | Implemented and CLI verified | Chain gene-set and family visualization matrix handoffs. |
| `11_visualization/build_gene_set_matrix.py` | Implemented and CLI verified | Build UpSet/Venn-style gene-set membership matrices from multiple ID lists. |
| `11_visualization/prepare_family_visualization_matrices.py` | Implemented and CLI verified | Prepare expression, target-evolution, and HGT-family matrices plus a manifest. |

## Reference-derived or legacy scripts

| Script | Status | Preferred replacement or note |
|---|---|---|
| `03_repeat/stat.sh` | Deprecated historical reference | Prefer `03_repeat/repeat_stat.sh`. |
| `03_repeat/repeat_masked_to_lower_case.pl` | Reference-derived; review before use | Check mask conventions before use. |
| `06_annotation/kegg/*.pl` | Reference-derived; review before use | KEGG/pathway helper scripts; confirm input formats. |
| `07_gene_family/legacy_tree/*.pl` | Reference-derived; review before use | Prefer maintained `07_gene_family/` Python helpers where possible. |
| `07_gene_family/legacy_tree/rename_tree*.py` | Deprecated historical reference | Prefer `07_gene_family/rename_tree_tips.py`. |
| `11_visualization/circos/*.pl` | Reference-derived; review before use | Some scripts require BioPerl and format-specific checks. |
| `11_visualization/circos/simple2links.py` | Reference-derived; review before use | Prefer `09_synteny/anchors_to_circos_links.py`. |

## External tools not included

| Tool | Used for |
|---|---|
| fastp, FastQC, Trimmomatic, adapter FASTA files, Java | RNA/WGS raw-read filtering and QC. |
| BLASTN, local NT database, accession-to-taxid table, lineage dump | Contig decontamination. |
| Jellyfish, GenomeScope2, Smudgeplot | Genome survey and ploidy/heterozygosity estimation. |
| ploidyNGS and Rscript | WGS/BAM ploidy estimation and histogram plotting. |
| hifiasm, NextDenovo, SPAdes, Flye, Canu, Verkko | Genome assembly. |
| seqkit | Optional read-length filtering before hifiasm. |
| purge_dups, NextPolish | Redundancy removal and polishing. |
| chromap, YaHS, HapHiC, samtools, bedtools | Hi-C scaffolding. |
| BWA, minimap2, samtools, bedtools, PanDepth, GC-depth plotting script | Assembly coverage and GC-depth QC. |
| BUSCO, compleasm, Merqury | Assembly and annotation QC. |
| LTR_FINDER_parallel, GenomeTools, LTR_retriever, RepeatModeler, RepeatMasker, TRF, TEsorter | Repeat annotation, TE-domain parsing, and divergence summaries. |
| Introner-elements | Introner candidate discovery and filtering. |
| Bismark | Cytosine methylation CX reports for region metaprofiles. |
| HISAT2, BRAKER3, AUGUSTUS, GeneMark, ProtHint, TSEBRA, gffread | RNA evidence alignment and gene structure annotation. |
| InterProScan, eggNOG-mapper, KofamScan exec_annotation, DIAMOND, BLASTP | Functional annotation, COG/NOG summaries, KEGG/Kofam annotation, and HGT hit generation. |
| Local EnrichPipeline installation and its GO/KEGG/IPR data resources | Optional GO, KEGG, and IPR enrichment execution from foreground gene lists. |
| Semantic GO plotting tools | Optional external visualization from GO handoff tables. |
| blast2hgt, local NR DIAMOND database, accession/taxonomy databases, HGT/ALL orthogroups, gene-count matrices, node/species parent lists | HGT candidate screening, comparable species matrices, and HGT-family gain/expansion event summaries. |
| GO, KEGG, Pfam, and pathway mapping tables | Downstream annotation summaries and enrichment. |
| OrthoFinder | Orthogroups and gene-family count matrices. |
| RSEM or compatible TPM matrices | Expression evidence for target gene sets. |
| MAFFT, trimAl, RAxML, IQ-TREE, MrBayes | Alignment trimming and phylogenetic inference. |
| Count, CAFE/CAFE5 | Gene-family gain/loss, expansion, and contraction. |
| minimap2, WGDI, MCScanX, JCVI, Circos, bedtools, samtools | Synteny, WGD, and visualization. |

## Cleanup policy

- Maintained scripts should use explicit command-line options and should not depend on the current working directory unless documented.
- Reference-derived scripts must not contain user-specific paths or real project identifiers.
- External tools are documented but not vendored.
- New workflows must be added to the SOP, command templates, script reference, and validation checks where appropriate.
