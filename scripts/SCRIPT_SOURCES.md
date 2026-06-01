# BioAnalysis Script Sources

This file records the intended provenance and cleanup status of scripts under `scripts/`. Third-party bioinformatics programs are external dependencies and are not vendored in this repository.

Reusable examples should use Arabidopsis-style placeholders such as `Arabidopsis_thaliana`, `Arabidopsis_lyrata`, and `Arabidopsis_halleri`. Do not place real project paths, real sample IDs, or historical local installation paths in reusable SOP/script outputs.

## Status labels

| Status | Meaning |
|---|---|
| Implemented and CLI verified | Maintained BioAnalysis helper script with an argparse or documented CLI used by the SOP. |
| Implemented; limited placeholder behavior | Script exists, but its behavior is intentionally limited and must not be interpreted as a full implementation. |
| Reference-derived; cleaned wrapper | Historical/reference script retained as a portable wrapper after path cleanup. |
| Reference-derived; review before use | Historical/reference script retained for compatibility; confirm input format and dependencies before production use. |
| Deprecated historical reference | Older script kept to document prior logic; prefer the maintained replacement. |
| External tool; not included | Third-party program invoked by the SOP and installed separately. |

## Implemented BioAnalysis helper scripts

| Script | Status | Purpose | Notes |
|---|---|---|---|
| `assembly/assembly_stats.py` | Implemented and CLI verified | Compute FASTA assembly length, N50/L50, N90/L90, GC, and N statistics. | Use `--fasta`, `--out`, optional `--lengths`. |
| `annotation/parse_interproscan_tsv.py` | Implemented and CLI verified | Parse InterProScan TSV into a compact annotation table. | Used before annotation merge. |
| `annotation/parse_kofam_detail.py` | Implemented and CLI verified | Parse KofamScan detail output. | Keeps threshold-passing hits by default. |
| `annotation/merge_function_annotations.py` | Implemented and CLI verified | Merge GFF coordinates, CDS QC, InterPro/Pfam, eggNOG, Kofam, SwissProt, and NR annotations. | Check ID consistency before merging. |
| `cafe/prepare_cafe_input.py` | Implemented and CLI verified | Convert OrthoFinder gene-count table to CAFE input. | Validates species tree tips against count-matrix columns. |
| `cafe/filter_cafe_families.py` | Implemented and CLI verified | Filter CAFE families and write removed-family reasons. | Requires `--removed`. |
| `genome_features/extract_introns.py` | Implemented and CLI verified | Extract intron intervals and optional short-intron summaries from GFF3. | Coordinate conventions should be checked before Circos use. |
| `gff/gff_cds_pep.py` | Implemented and CLI verified | Extract clean GFF/CDS/PEP files and CDS QC tables from genome FASTA and annotation GFF. | Selects one representative transcript per gene. |
| `phylogeny/prefix_fasta_ids.py` | Implemented and CLI verified | Prefix FASTA IDs and write ID map. | Requires `--map`. |
| `phylogeny/extract_orthogroup_members.py` | Implemented and CLI verified | Extract orthogroup member lists from OrthoFinder outputs. | Use with OrthoFinder gene-family steps. |
| `phylogeny/clean_pep_for_tree.py` | Implemented and CLI verified | Clean peptide FASTA records before tree building. | Use before MAFFT/tree inference. |
| `phylogeny/concat_alignments.py` | Implemented and CLI verified | Concatenate aligned FASTA files into a supermatrix and partition table. | Writes FASTA, partition, and stats; it does not write PHYLIP. |
| `phylogeny/select_genes_by_function.py` | Implemented and CLI verified | Select genes using functional annotation fields. | Use for function-focused gene trees. |
| `phylogeny/select_blast_hits.py` | Implemented and CLI verified | Select sequence hits from BLAST/DIAMOND-style tables. | Confirm hit table columns before use. |
| `phylogeny/build_function_tree_tip_table.py` | Implemented and CLI verified | Build tree-tip annotation tables for selected functional genes. | Use before tree visualization/renaming. |
| `phylogeny/make_tree_tip_annotation.py` | Implemented and CLI verified | Create tree-tip annotation metadata. | Use with renamed/rooted tree outputs. |
| `phylogeny/rename_tree_tips.py` | Implemented and CLI verified | Rename tree tips using a mapping table. | Prefer over legacy `tree/rename_tree*.py`. |
| `phylogeny/root_tree.py` | Implemented; limited placeholder behavior | Preserve a tree and write a rooting handoff note. | Does not reroot Newick topology. |
| `phylogeny/summarize_gene_trees.py` | Implemented and CLI verified | Summarize gene-tree outputs and failures. | Use after batch tree inference. |
| `synteny/anchors_to_circos_links.py` | Implemented and CLI verified | Convert anchor/simple synteny records to Circos links using BED maps. | Prefer over legacy implicit-name converter when possible. |

## Reference-derived or historical scripts

| Script | Status | Purpose | Notes |
|---|---|---|---|
| `repeat/LTR_Finder.sh` | Reference-derived; cleaned wrapper | Run `LTR_FINDER_parallel` on a genome FASTA. | Uses tools on `PATH`; no local installation path should be embedded. |
| `repeat/LTR_harvest.sh` | Reference-derived; cleaned wrapper | Build GenomeTools index and run `gt ltrharvest`. | Uses `gt` from `PATH`. |
| `repeat/work.sh` | Reference-derived; cleaned wrapper | Merge LTR_FINDER/LTRharvest candidates and run `LTR_retriever`. | Kept name for compatibility; functionally an LTR_retriever wrapper. |
| `repeat/repeatmodeler.sh` | Reference-derived; cleaned wrapper | Build RepeatModeler database and run RepeatModeler. | Uses `BuildDatabase` and `RepeatModeler` from `PATH`. |
| `repeat/trf.sh` | Reference-derived; cleaned wrapper | Run TRF and optional TRF-to-GFF conversion. | Confirm TRF output naming for each TRF version. |
| `repeat/rmout2gff.sh` | Reference-derived; review before use | Convert RepeatMasker `.out` to GFF3. | Check repeat class parsing on current RepeatMasker output. |
| `repeat/repeat_stat.sh` | Reference-derived; review before use | Summarize RepeatMasker repeat coverage by class. | Preferred over `repeat/stat.sh`. |
| `repeat/stat.sh` | Deprecated historical reference | Older inline repeat-stat command pipeline. | Prefer `repeat/repeat_stat.sh`. |
| `repeat/repeat_masked_to_lower_case.pl` | Reference-derived; review before use | Convert masked regions to lowercase. | Confirm FASTA and mask conventions before use. |
| `tree/Fasta2Phylip.pl` | Reference-derived; review before use | Convert FASTA alignment to PHYLIP-like format. | Confirm name-length constraints before use. |
| `tree/Orhogroup2fa.pl` | Reference-derived; review before use | Extract orthogroup FASTA files using historical directory conventions. | Prefer maintained phylogeny helpers when possible. |
| `tree/trim_phy.pl` | Reference-derived; review before use | Historical alignment trimming helper. | Prefer trimAl command templates. |
| `tree/rename_tree.py` | Deprecated historical reference | Legacy tree-tip renaming logic. | Prefer `phylogeny/rename_tree_tips.py`. |
| `tree/rename_tree2.py` | Deprecated historical reference | Legacy tree-tip renaming logic. | Prefer `phylogeny/rename_tree_tips.py`. |
| `visualization/circos/*.pl` | Reference-derived; review before use | Circos density/track helper scripts. | Some require BioPerl and format-specific input checks. |
| `visualization/circos/simple2links.py` | Reference-derived; review before use | Convert simple synteny links using implicit BED filenames. | Prefer `synteny/anchors_to_circos_links.py` for explicit inputs. |
| `kegg/getKO.pl` | Reference-derived; review before use | Extract KO-related records for pathway analysis. | Confirm input table format. |
| `kegg/pathfind.pl` | Reference-derived; review before use | KEGG/pathway enrichment or summary helper. | Confirm dependency and input file assumptions. |
| `kegg/pathfind.v2.pl` | Reference-derived; review before use | Alternative KEGG/pathway helper. | Confirm version-specific behavior before use. |

## External tools not included

| Tool | Used for |
|---|---|
| hifiasm, NextDenovo, SPAdes, Canu | Genome assembly |
| purge_dups, NextPolish | Redundancy removal and polishing |
| HiC-Pro, chromap, HapHiC | Hi-C scaffolding and chromosome-level assembly |
| BUSCO, compleasm, Merqury | Assembly and annotation quality assessment |
| LTR_FINDER_parallel, GenomeTools `gt`, LTR_retriever, RepeatModeler, RepeatMasker, TRF | Repeat annotation |
| BRAKER3, AUGUSTUS, GeneMark, gffread | Gene structure annotation and validation |
| InterProScan, eggNOG-mapper, KofamScan, DIAMOND, BLASTP | Functional annotation |
| OrthoFinder, MAFFT, trimAl, RAxML, IQ-TREE, MrBayes | Orthogroups and phylogenomics |
| CAFE/CAFE5 | Gene-family expansion/contraction |
| minimap2, WGDI, MCScanX, JCVI, Circos, bedtools, samtools | Synteny, WGD, and visualization |

## Cleanup policy

- Maintained helper scripts should expose explicit command-line options and avoid relying on the current working directory.
- Reference-derived scripts must not contain user-specific installation paths or real project identifiers.
- External software must be documented in the software list rather than copied into this repository.
- If a reference script is kept only for historical compatibility, mark it as review-required or deprecated in both this file and `docs/BioAnalysis_Template_Script_List.md`.
