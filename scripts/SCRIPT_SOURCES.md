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
| `01_preprocessing/01_nt_decontaminate_contigs.sh` | Reference-derived; cleaned wrapper | Run local NT-based contig decontamination using user-supplied BLAST database and helper scripts. |
| `02_assembly/assembly_stats.py` | Implemented and CLI verified | Compute assembly length, N50/L50, N90/L90, GC, and N statistics. |
| `03_repeat/LTR_Finder.sh` | Reference-derived; cleaned wrapper | Run `LTR_FINDER_parallel` from `PATH`. |
| `03_repeat/LTR_harvest.sh` | Reference-derived; cleaned wrapper | Run GenomeTools suffixerator and LTRharvest from `PATH`. |
| `03_repeat/work.sh` | Reference-derived; cleaned wrapper | Merge LTR candidates and run `LTR_retriever`. |
| `03_repeat/repeatmodeler.sh` | Reference-derived; cleaned wrapper | Build a RepeatModeler database and run RepeatModeler from `PATH`. |
| `03_repeat/trf.sh` | Reference-derived; cleaned wrapper | Run TRF and optional `trf2gff`. |
| `03_repeat/rmout2gff.sh` | Reference-derived; review before use | Convert RepeatMasker `.out` to GFF3. |
| `03_repeat/repeat_stat.sh` | Reference-derived; review before use | Summarize RepeatMasker coverage by repeat class. |
| `04_gff/gff_cds_pep.py` | Implemented and CLI verified | Extract clean GFF/CDS/PEP files and CDS QC tables. |
| `05_genome_features/extract_introns.py` | Implemented and CLI verified | Infer introns, unique intron loci, short introns, and AT-rich intron summaries. |
| `05_genome_features/run_introner_elements.sh` | Reference-derived; cleaned wrapper | Run an external Introner-elements workflow using user-supplied tool paths. |
| `06_annotation/parse_interproscan_tsv.py` | Implemented and CLI verified | Parse InterProScan TSV into a compact annotation table. |
| `06_annotation/parse_kofam_detail.py` | Implemented and CLI verified | Parse KofamScan detail output. |
| `06_annotation/merge_function_annotations.py` | Implemented and CLI verified | Merge structural, CDS QC, InterPro/Pfam, eggNOG, Kofam, SwissProt, and NR annotations. |
| `06_annotation/summarize_go_terms.py` | Implemented and CLI verified | Produce long gene-to-GO and GO term count tables. |
| `06_annotation/summarize_kegg_pathways.py` | Implemented and CLI verified | Map KO annotations to pathways and report pathway counts and unmapped KOs. |
| `06_annotation/summarize_pfam_domains.py` | Implemented and CLI verified | Produce long gene-to-Pfam and Pfam count tables. |
| `06_annotation/summarize_domain_architecture.py` | Implemented and CLI verified | Summarize ordered Pfam domain architectures from parsed InterProScan output. |
| `06_annotation/enrich_annotation_terms.py` | Implemented and CLI verified | Run GO, KEGG, or Pfam overrepresentation tests for foreground gene sets. |
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
| `08_gene_family_evolution/prepare_count_input.py` | Implemented and CLI verified | Convert OrthoFinder count tables to Count input while validating species names. |
| `08_gene_family_evolution/parse_count_gain_loss.py` | Implemented and CLI verified | Normalize Count gain/loss output to long or wide family-node tables. |
| `08_gene_family_evolution/summarize_family_gain_loss.py` | Implemented and CLI verified | Summarize Count gain/loss calls by family and node. |
| `08_gene_family_evolution/prepare_cafe_input.py` | Implemented and CLI verified | Convert OrthoFinder count tables to CAFE input. |
| `08_gene_family_evolution/filter_cafe_families.py` | Implemented and CLI verified | Filter CAFE families and record removed-family reasons. |
| `09_synteny/anchors_to_circos_links.py` | Implemented and CLI verified | Convert synteny anchors/blocks to Circos links. |
| `10_hgt/01_classify_hgt_hits.py` | Implemented and CLI verified | Classify similarity hits by local taxonomy groups for HGT screening. |
| `10_hgt/02_score_hgt_candidates.py` | Implemented and CLI verified | Score conservative HGT candidates from classified hits. |
| `10_hgt/03_add_hgt_context.py` | Implemented and CLI verified | Merge HGT candidates with coordinate, annotation, intron, and synteny context. |
| `10_hgt/04_prepare_hgt_validation.py` | Implemented and CLI verified | Prepare candidate and donor ID lists for phylogenetic validation. |

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
| BLASTN, local NT database, accession-to-taxid table, lineage dump | Contig decontamination. |
| hifiasm, NextDenovo, SPAdes, Canu | Genome assembly. |
| purge_dups, NextPolish | Redundancy removal and polishing. |
| HiC-Pro, chromap, HapHiC | Hi-C scaffolding. |
| BUSCO, compleasm, Merqury | Assembly and annotation QC. |
| LTR_FINDER_parallel, GenomeTools, LTR_retriever, RepeatModeler, RepeatMasker, TRF | Repeat annotation. |
| Introner-elements | Introner candidate discovery and filtering. |
| BRAKER3, AUGUSTUS, GeneMark, gffread | Gene structure annotation. |
| InterProScan, eggNOG-mapper, KofamScan, DIAMOND, BLASTP | Functional annotation and HGT hit generation. |
| GO, KEGG, Pfam, and pathway mapping tables | Downstream annotation summaries and enrichment. |
| OrthoFinder | Orthogroups and gene-family count matrices. |
| MAFFT, trimAl, RAxML, IQ-TREE, MrBayes | Alignment trimming and phylogenetic inference. |
| Count, CAFE/CAFE5 | Gene-family gain/loss, expansion, and contraction. |
| minimap2, WGDI, MCScanX, JCVI, Circos, bedtools, samtools | Synteny, WGD, and visualization. |

## Cleanup policy

- Maintained scripts should use explicit command-line options and should not depend on the current working directory unless documented.
- Reference-derived scripts must not contain user-specific paths or real project identifiers.
- External tools are documented but not vendored.
- New workflows must be added to the SOP, command templates, script reference, and validation checks where appropriate.
