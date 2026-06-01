# BioAnalysis Run Checklist

This checklist is the execution entry point for a genome analysis project. Use it with the full SOP, command templates, software list, and script reference.

Examples use Arabidopsis-style placeholders such as `Arabidopsis_thaliana`, `Arabidopsis_lyrata`, and `Arabidopsis_halleri`. Replace them with project-specific IDs when running an analysis.

## How to use this checklist

For each stage, record the exact input files, command template, output files, QC result, and handoff target before moving to the next stage.

```text
Input -> Command/script -> Expected output -> QC pass criteria -> Next input
```

Stop at a stage if a required output is missing, empty, inconsistent with the previous stage, or fails the listed QC rule.

## 1. Project setup

| Item | Requirement |
|---|---|
| Input | Project ID, species/sample IDs, expected genome size, sequencing data types, software/database versions |
| Command/template | Copy `config/project.example.env` and edit values for the current project |
| Expected output | Project config, directory plan, species/sample manifest |
| QC pass criteria | No real historical paths or old species/sample names remain in reusable SOP outputs |
| Next input | Input inventory and raw data checks |
| Stop conditions | Missing project ID, ambiguous sample IDs, unknown genome version, or undocumented software/database versions |

## 2. Input inventory

| Item | Requirement |
|---|---|
| Input | Long reads, Hi-C reads, RNA-seq reads if available, existing genome resources if any |
| Command/template | Use the file naming and manifest rules in `BioAnalysis_Genome_Workflow_SOP.md` |
| Expected output | Raw data manifest, file sizes, read statistics, checksum or transfer record |
| QC pass criteria | Files exist, sample IDs match the manifest, paired files are balanced, naming is consistent |
| Next input | Assembly and polishing |
| Stop conditions | Missing files, sample ID conflicts, truncated FASTQ/FASTA, or unresolved data provenance |

## 3. Genome assembly

| Item | Requirement |
|---|---|
| Input | Long-read FASTQ/FASTA and expected genome size |
| Command/template | hifiasm, NextDenovo, SPAdes, or Canu command block from `BioAnalysis_Genome_Command_Templates.md` |
| Expected output | Draft assembly FASTA and assembly log |
| QC pass criteria | Non-empty FASTA, no duplicate sequence IDs, total length roughly matches expectation, assembly log has no fatal error |
| Next input | Purging, polishing, Hi-C scaffolding, and assembly QC |
| Stop conditions | Empty assembly, unexpected genome size, duplicated IDs, or unresolved assembler failure |

## 4. Purging, polishing, and Hi-C scaffolding

| Item | Requirement |
|---|---|
| Input | Draft assembly FASTA, reads used for polishing, optional Hi-C reads |
| Command/template | purge_dups, NextPolish, HiC-Pro, chromap, or HapHiC command block |
| Expected output | Purged/polished/chromosome-level FASTA, AGP or scaffold records, Hi-C heatmap if available |
| QC pass criteria | Assembly version is recorded, FASTA IDs remain stable, scaffolding logs are complete, no unexpected sequence loss |
| Next input | Assembly QC and repeat annotation |
| Stop conditions | Conflicting assembly versions, missing scaffold outputs, or unexplained length changes |

## 5. Assembly QC

| Item | Requirement |
|---|---|
| Input | Final genome FASTA and reads/databases needed for QC |
| Command/template | `assembly_stats.py`, BUSCO/compleasm, Merqury, LAI templates |
| Expected output | Assembly stats TSV, BUSCO/compleasm report, optional Merqury/QV report and LAI report |
| QC pass criteria | N50/L50/GC/N stats are recorded, completeness metrics are acceptable for the project, logs are retained |
| Next input | Repeat annotation and gene annotation |
| Stop conditions | Missing stats, failed BUSCO/compleasm run, or QC result inconsistent with project expectations |

## 6. Repeat annotation

| Item | Requirement |
|---|---|
| Input | Final uppercase genome FASTA, repeat libraries, repeat software on `PATH` |
| Command/template | `LTR_Finder.sh`, `LTR_harvest.sh`, `work.sh`, `repeatmodeler.sh`, RepeatMasker, `rmout2gff.sh`, `repeat_stat.sh` |
| Expected output | LTR candidates, LTR library, RepeatModeler library, RepeatMasker `.out`, repeat GFF3, repeat summary TSV |
| QC pass criteria | LTR and RepeatModeler outputs are non-empty when expected, RepeatMasker output is merged once, repeat GFF3 coordinates are valid |
| Next input | Soft-masked genome and repeat tracks for gene annotation/Circos |
| Stop conditions | Missing `.scn`, missing repeat library, unmerged RepeatMasker outputs, or repeat coordinates beyond chromosome lengths |

## 7. Gene structure annotation

| Item | Requirement |
|---|---|
| Input | Soft-masked genome FASTA, protein evidence, RNA-seq evidence if available |
| Command/template | BRAKER3/AUGUSTUS/GeneMark command block and GFF conversion templates |
| Expected output | Raw gene structure GFF/GTF and annotation logs |
| QC pass criteria | Gene count is plausible, seqids match genome FASTA, evidence sources and software versions are recorded |
| Next input | GFF/CDS/PEP extraction and QC |
| Stop conditions | Missing annotation output, mismatched seqids, or undocumented evidence sources |

## 8. GFF/CDS/PEP extraction and QC

| Item | Requirement |
|---|---|
| Input | Genome FASTA, gene annotation GFF/GTF, manifest TSV |
| Command/template | `scripts/gff/gff_cds_pep.py` |
| Expected output | Clean GFF3, CDS FASTA, protein FASTA, `summary.tsv`, CDS check tables |
| QC pass criteria | No retained internal-stop CDS unless explicitly justified, phase/length checks are reviewed, output IDs match downstream expectations |
| Next input | Functional annotation and OrthoFinder |
| Stop conditions | Missing FASTA seqids, widespread CDS errors, or unresolved ID convention conflicts |

## 9. Functional annotation

| Item | Requirement |
|---|---|
| Input | `protein.primary.fa`, clean GFF3, CDS check table, InterProScan/eggNOG/Kofam/DIAMOND outputs |
| Command/template | `parse_interproscan_tsv.py`, `parse_kofam_detail.py`, `merge_function_annotations.py` |
| Expected output | Parsed InterPro/Pfam table, Kofam table, `functional_annotation.tsv` |
| QC pass criteria | Query IDs match protein FASTA, annotation rates are recorded, comment/header rows are handled consistently |
| Next input | Gene selection, Pfam statistics, gene trees, evidence tables |
| Stop conditions | ID mismatch between annotation outputs and protein FASTA, missing major database output, or empty merged annotation table |

## 10. Orthogroups, species tree, and gene trees

| Item | Requirement |
|---|---|
| Input | One protein FASTA per species, species list, OrthoFinder outputs, target family/gene lists |
| Command/template | OrthoFinder, `prefix_fasta_ids.py`, `extract_orthogroup_members.py`, MAFFT, trimAl, IQ-TREE/RAxML, `summarize_gene_trees.py` |
| Expected output | `Orthogroups.tsv`, `Orthogroups.GeneCount.tsv`, alignments, trimmed alignments, tree files, `gene_tree_summary.tsv` |
| QC pass criteria | Species names match across files, alignments have expected taxa, failed families are logged, tree tips match input IDs |
| Next input | CAFE, function-focused trees, and comparative interpretation |
| Stop conditions | Missing OrthoFinder outputs, species-name mismatch, empty alignments, or untracked failed trees |

## 11. CAFE expansion/contraction

| Item | Requirement |
|---|---|
| Input | OrthoFinder count matrix and species tree with matching tip names |
| Command/template | `prepare_cafe_input.py`, `filter_cafe_families.py`, CAFE/CAFE5 |
| Expected output | CAFE input table, filtered table, removed-family table, CAFE result directory |
| QC pass criteria | Tree tips are present in the count matrix, extreme families are filtered with reasons, ultrametric tree handling is documented |
| Next input | Expansion/contraction interpretation and evidence tables |
| Stop conditions | Tree/count species mismatch, missing removed-family table, or undocumented CAFE tree calibration |

## 12. Synteny, WGD, and Circos

| Item | Requirement |
|---|---|
| Input | Genome FASTA, GFF3, protein FASTA, repeat GFF3, pairwise anchor/block files |
| Command/template | minimap2/dotPlotly, WGDI/MCScanX/JCVI, `anchors_to_circos_links.py`, Circos track templates |
| Expected output | Dotplots, synteny blocks, Circos link files, karyotype file, GC/gene/repeat/intron tracks, Circos figures |
| QC pass criteria | Chromosome IDs match across FASTA/GFF/BED/link files, coordinates are in bounds, BED/Circos coordinate conventions are documented |
| Next input | Final visualization and evidence integration |
| Stop conditions | Coordinate-system conflict, missing chromosome IDs, out-of-bound links, or incomplete track files |

## 13. Final evidence table and deliverables

| Item | Requirement |
|---|---|
| Input | QC summaries, repeat/gene/function/orthogroup/tree/synteny/domain outputs |
| Command/template | Project-specific merge tables based on SOP outputs |
| Expected output | Final evidence table, figure-ready tracks, reproducible methods notes, archived command logs |
| QC pass criteria | Every final claim maps back to a file and command, placeholder names are replaced only in project-specific outputs |
| Next input | Manuscript/report/table generation |
| Stop conditions | Missing provenance, mismatched IDs across modules, or figure/table values that cannot be traced to source files |
