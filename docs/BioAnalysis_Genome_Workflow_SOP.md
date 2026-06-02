# BioAnalysis Genome Workflow SOP

This SOP describes an extensible, English-first genome analysis workflow. It is organized around numbered script stages under `scripts/` and uses anonymized Arabidopsis-style examples.

## Core rule

Each module must define:

```text
Input -> Command/script -> Expected output -> QC -> Next input
```

Missing data must be recorded as `missing` or `not_tested`; it must not be interpreted as biological absence.

## Workflow overview

```text
01 raw-read filtering, preprocessing, and contamination screening
02 genome survey and ploidy estimation
02 assembly, Hi-C scaffolding, statistics, and QC assessments
03 repeat annotation, TE post-processing, and EVE/GEVE region handoffs
04 GFF/CDS/PEP extraction and structure statistics
05 genome features, introns, region context, methylation, and introner evidence
06 functional annotation, COG/NOG summaries, and GO handoffs
07 gene families, target-family discovery, expression evidence, and phylogeny helpers
08 gene-family evolution with Count, CAFE, and target-family integration
09 synteny context, MCScan/JCVI summaries, heatmaps, and Circos links
10 HGT candidate screening and validation handoff
11 visualization matrices and final evidence tables
```

## 01 Raw-read filtering, preprocessing, and NT-based decontamination

### Purpose

Filter raw WGS and RNA-seq reads before downstream genome survey, assembly, coverage QC, RNA alignment, and gene prediction. Screen assembly contigs against a local NT database and remove likely contaminant contigs when a draft assembly is available. Private database paths, adapter FASTA files, and helper-script locations must be supplied at runtime.

### Main scripts

```text
scripts/01_preprocessing/run_fastp_rna_read_filtering_workflow.sh
scripts/01_preprocessing/run_fastp_wgs_read_filtering_workflow.sh
scripts/01_preprocessing/run_trimmomatic_rna_read_filtering_workflow.sh
scripts/01_preprocessing/run_trimmomatic_wgs_read_filtering_workflow.sh
scripts/01_preprocessing/01_nt_decontaminate_contigs.sh
```

### Raw-read filtering examples

```bash
bash scripts/01_preprocessing/run_fastp_rna_read_filtering_workflow.sh \
  --sample Arabidopsis_thaliana.flower \
  --r1 Arabidopsis_thaliana.flower_R1.fq.gz \
  --r2 Arabidopsis_thaliana.flower_R2.fq.gz \
  --outdir rna_fastp \
  --detect-adapter-for-pe

bash scripts/01_preprocessing/run_trimmomatic_wgs_read_filtering_workflow.sh \
  --sample Arabidopsis_thaliana.WGS \
  --pe1 Arabidopsis_thaliana.WGS_R1.fq.gz \
  --pe2 Arabidopsis_thaliana.WGS_R2.fq.gz \
  --outdir wgs_trimmomatic \
  --adapter-file refs/TruSeq3-PE.fa
```

### NT decontamination inputs

```text
Arabidopsis_thaliana.assembly.fa
local NT BLAST database directory
accession-to-taxid table
lineage table
helper script directory containing cn50.py, length_by_seq.pl, get_cov_list_nt.pl, exclude_fa.pl
```

### Expected outputs

```text
rna_fastp/*.rna.clean_R*.fastq.gz
wgs_fastp/*.wgs.clean_R*.fastq.gz
rna_trimmomatic/*.rna_*_paired.fq.gz
wgs_trimmomatic/*.wgs_*_paired.fq.gz
*/fastqc/*
*.fastp.html
*.fastp.json
*.trimmomatic.summary
*_manifest.tsv
*_running_time.txt
Arabidopsis_thaliana_rm/Arabidopsis_thaliana.n50
Arabidopsis_thaliana_rm/Arabidopsis_thaliana.m6
Arabidopsis_thaliana_rm/Arabidopsis_thaliana.nt.fa
Arabidopsis_thaliana_rm/Arabidopsis_thaliana.nt.fa.n50
```

### QC

- Record raw-read source, adapter FASTA source, quality thresholds, and tool versions.
- Confirm filtered read outputs are non-empty before passing WGS reads to Stage 02 or RNA reads to Stage 04 gene prediction.
- Record NT database version and taxonomy-file versions in project run notes.
- Inspect removed contigs before treating the filtered FASTA as final.
- Do not commit private database paths, adapter paths, or real sample IDs to this repository.

## 02 Genome survey, ploidy estimation, assembly, Hi-C scaffolding, statistics, and QC assessments

Run genome survey, ploidy estimation, assembly, scaffolding, and assessment wrappers independently. Genome survey and ploidy estimation live in `scripts/02_genome_survey/`; assembly, scaffolding, assembly statistics, and assembly assessments live in `scripts/02_assembly/`.

Maintained genome survey and ploidy wrappers:

```text
scripts/02_genome_survey/run_genome_survey_workflow.sh
scripts/02_genome_survey/run_ploidyngs_workflow.sh
```

Maintained assembly wrappers:

```text
scripts/02_assembly/run_hifiasm_assembly.sh
scripts/02_assembly/run_nextdenovo_assembly.sh
scripts/02_assembly/run_spades_assembly.sh
scripts/02_assembly/run_flye_assembly.sh
scripts/02_assembly/run_canu_assembly.sh
scripts/02_assembly/run_verkko_assembly.sh
```

Maintained Hi-C scaffolding and coverage wrappers:

```text
scripts/02_assembly/run_yahs_scaffolding.sh
scripts/02_assembly/run_haphic_scaffolding.sh
scripts/02_assembly/run_pandepth_coverage_workflow.sh
scripts/02_assembly/run_gc_depth_workflow.sh
```

Representative commands:

```bash
bash scripts/02_genome_survey/run_genome_survey_workflow.sh \
  --read Arabidopsis_thaliana.reads_1.fq.gz \
  --read Arabidopsis_thaliana.reads_2.fq.gz \
  --outdir genome_survey \
  --prefix Arabidopsis_thaliana \
  --kmer 21 \
  --ploidy 2 \
  --run-smudgeplot

bash scripts/02_genome_survey/run_ploidyngs_workflow.sh \
  --bam Arabidopsis_thaliana.sorted.bam \
  --outdir ploidy_ngs \
  --prefix Arabidopsis_thaliana \
  --guess-ploidy

bash scripts/02_assembly/run_hifiasm_assembly.sh \
  --hifi Arabidopsis_thaliana.hifi.fa.gz \
  --outdir hifiasm_assembly \
  --prefix Arabidopsis_thaliana \
  --threads 32

bash scripts/02_assembly/run_nextdenovo_assembly.sh \
  --read Arabidopsis_thaliana.ont.fq.gz \
  --read-type ont \
  --genome-size 150m \
  --outdir nextdenovo_assembly \
  --prefix Arabidopsis_thaliana

bash scripts/02_assembly/run_spades_assembly.sh \
  --pe1 Arabidopsis_thaliana.insert350_R1.fq.gz \
  --pe2 Arabidopsis_thaliana.insert350_R2.fq.gz \
  --outdir spades_assembly \
  --prefix Arabidopsis_thaliana \
  --isolate

bash scripts/02_assembly/run_flye_assembly.sh \
  --read Arabidopsis_thaliana.ont.fq.gz \
  --read-type nano-raw \
  --genome-size 150m \
  --outdir flye_assembly \
  --prefix Arabidopsis_thaliana

bash scripts/02_assembly/run_canu_assembly.sh \
  --read Arabidopsis_thaliana.ont.fq.gz \
  --read-type nanopore \
  --genome-size 150m \
  --outdir canu_assembly \
  --prefix Arabidopsis_thaliana

bash scripts/02_assembly/run_verkko_assembly.sh \
  --hifi Arabidopsis_thaliana.hifi.fa.gz \
  --outdir verkko_assembly \
  --prefix Arabidopsis_thaliana

bash scripts/02_assembly/run_yahs_scaffolding.sh \
  --assembly hifiasm_assembly/Arabidopsis_thaliana.hifiasm.assembly.fa \
  --hic-r1 Arabidopsis_thaliana.HiC_R1.fq.gz \
  --hic-r2 Arabidopsis_thaliana.HiC_R2.fq.gz \
  --outdir yahs_scaffolding \
  --prefix Arabidopsis_thaliana

bash scripts/02_assembly/run_haphic_scaffolding.sh \
  --assembly hifiasm_assembly/Arabidopsis_thaliana.hifiasm.assembly.fa \
  --hic-r1 Arabidopsis_thaliana.HiC_R1.fq.gz \
  --hic-r2 Arabidopsis_thaliana.HiC_R2.fq.gz \
  --groups 5 \
  --outdir haphic_scaffolding \
  --prefix Arabidopsis_thaliana

bash scripts/02_assembly/run_pandepth_coverage_workflow.sh \
  --genome Arabidopsis_thaliana.genome.fa \
  --wgs-r1 Arabidopsis_thaliana.WGS_R1.fq.gz \
  --wgs-r2 Arabidopsis_thaliana.WGS_R2.fq.gz \
  --outdir pandepth_qc \
  --output-name Arabidopsis_thaliana

bash scripts/02_assembly/run_gc_depth_workflow.sh \
  --genome Arabidopsis_thaliana.genome.fa \
  --hifi Arabidopsis_thaliana.hifi.fa.gz \
  --outdir gc_depth_qc \
  --output-name Arabidopsis_thaliana \
  --gc-depth-script gc_depth_analysis.py
```

QC and assessment commands remain independent:

```bash
python3 scripts/02_assembly/assembly_stats.py \
  --fasta Arabidopsis_thaliana.genome.fa \
  --out Arabidopsis_thaliana.assembly.stats.tsv \
  --lengths Arabidopsis_thaliana.assembly.lengths.tsv

bash scripts/02_assembly/run_busco_qc_workflow.sh \
  --input Arabidopsis_thaliana.genome.fa \
  --lineage embryophyta_odb10 \
  --outdir busco_qc \
  --sample Arabidopsis_thaliana \
  --mode genome \
  --threads 20 \
  --offline \
  --force

bash scripts/02_assembly/run_lai_qc_workflow.sh \
  --genome Arabidopsis_thaliana.genome.fa \
  --outdir lai_qc \
  --prefix Arabidopsis_thaliana \
  --threads 20 \
  --max-length 7000 \
  --min-length 100 \
  --min-similarity 85

bash scripts/02_assembly/run_merqury_qv_workflow.sh \
  --genome Arabidopsis_thaliana.genome.fa \
  --read Arabidopsis_thaliana.reads_1.fq.gz \
  --read Arabidopsis_thaliana.reads_2.fq.gz \
  --outdir merqury_qv \
  --prefix Arabidopsis_thaliana \
  --kmer 21 \
  --best-k
```

Expected handoff files:

```text
genome_survey/*.genome_survey_manifest.tsv
genome_survey/results/*.hist
genome_survey/results/*.GenomeScopeResults/
genome_survey/results/*.SmudgePlotResults*
ploidy_ngs/*.ploidyNGS_manifest.tsv
ploidy_ngs/*.ploidyNGS_running_time.txt
ploidy_ngs/*.ploidyNGS.pdf
ploidy_ngs/*.ploidyNGS_MaxDepth100_MinCov0.tab
*.<method>.assembly.fa
*.<method>.assembly_stats.tsv
*.<method>.assembly_lengths.tsv
*.yahs.scaffolds.fa
*.yahs.agp
*.haphic.scaffolds.fa
*.haphic.agp
*.pandepth.sorted.bam
*.pandepth.windows.bed
*.pandepth_manifest.tsv
*.gc_depth.sorted.bam
*.gc_depth.coverage.tsv
*.gc_depth.png
*.gc_depth_manifest.tsv
busco_qc/*.busco_summary.tsv
lai_qc/*.lai_summary.tsv
merqury_qv/*.merqury_qv_summary.tsv
```

QC requires non-empty FASTA/read/BAM inputs, unique sequence IDs where FASTA is produced, plausible genome survey and ploidy estimates, retained GenomeScope/Smudgeplot/ploidyNGS outputs when run, retained assembler/scaffolder logs, documented read technology, documented k-mer/ploidy/hash-size choices, documented genome-size estimates, documented Hi-C pairing when used, documented BUSCO lineage, documented LAI parameter thresholds, documented Merqury k-mer choice, and local tool/database versions recorded in project run notes.

## 03 Repeat annotation, TE post-processing, and EVE/GEVE handoffs

Repeat annotation uses portable wrappers around external tools available on `PATH`. Downstream TE/EVE post-processing standardizes external EVE/GEVE calls, summarizes TEsorter domains over target regions, and estimates RepeatMasker divergence summaries.

Primary workflow drivers:

```text
scripts/03_repeat/run_repeat_annotation_workflow.sh
scripts/03_repeat/run_te_eve_postprocessing_workflow.sh
```

Key helper scripts:

```text
scripts/03_repeat/LTR_Finder.sh
scripts/03_repeat/LTR_harvest.sh
scripts/03_repeat/repeatmodeler.sh
scripts/03_repeat/work.sh
scripts/03_repeat/rmout2gff.sh
scripts/03_repeat/repeat_stat.sh
scripts/03_repeat/trf.sh
scripts/03_repeat/parse_tesorter_domains.py
scripts/03_repeat/summarize_tesorter_regions.py
scripts/03_repeat/summarize_te_divergence.py
scripts/03_repeat/standardize_eve_geve_regions.py
```

Recommended handoffs:

```text
uppercase genome FASTA -> LTR_FINDER/LTRharvest/RepeatModeler -> LTR_retriever -> RepeatMasker -> GFF3 and summary tables
external EVE/GEVE calls + TEsorter domains + RepeatMasker .out -> standardized region BED/TSV, target-region TE-domain summaries, divergence summaries
```

Post-processing example:

```bash
bash scripts/03_repeat/run_te_eve_postprocessing_workflow.sh \
  --outdir repeat_postprocess \
  --prefix Arabidopsis_thaliana \
  --tesorter-domains Arabidopsis_thaliana.rexdb.dom.faa \
  --eve-input Arabidopsis_thaliana.eve_geve.raw.gff3 \
  --eve-format gff \
  --eve-feature-types region,match \
  --background-bed Arabidopsis_thaliana.callable_windows.bed \
  --repeatmasker-out Arabidopsis_thaliana.repeatmasker.all.out
```

QC requires non-empty LTR candidate files, repeat libraries, RepeatMasker `.out`, repeat GFF3, repeat coverage summaries, valid target/background BED coordinates, documented EVE/GEVE caller provenance, and TEsorter/RepeatMasker database-version notes.

## 04 Gene prediction and RNA evidence alignment

Use `scripts/04_gene_prediction/run_hisat2_rnaseq_alignment_workflow.sh` to build RNA-seq BAM evidence for annotation. Use `scripts/04_gene_prediction/run_braker3_annotation_workflow.sh` to run BRAKER3 from a soft-masked genome, protein evidence, and RNA-seq BAMs. Keep tool paths, AUGUSTUS config, GeneMark, ProtHint, and TSEBRA locations as runtime arguments instead of committing local paths.

```bash
bash scripts/04_gene_prediction/run_hisat2_rnaseq_alignment_workflow.sh \
  --masked-genome Arabidopsis_thaliana.genome.softmasked.fa \
  --pe1 Arabidopsis_thaliana.flower_R1.fq.gz \
  --pe2 Arabidopsis_thaliana.flower_R2.fq.gz \
  --outdir rnaseq_alignment \
  --output-name Arabidopsis_thaliana \
  --threads 16 \
  --dta

bash scripts/04_gene_prediction/run_braker3_annotation_workflow.sh \
  --genome Arabidopsis_thaliana.genome.softmasked.fa \
  --proteins Arabidopsis_thaliana.related_species.proteins.fa \
  --rnaseq-bam rnaseq_alignment/Arabidopsis_thaliana.rnaseq.sorted.bam \
  --species Arabidopsis_thaliana \
  --outdir braker3_annotation \
  --prefix Arabidopsis_thaliana \
  --rounds 20 \
  --threads 20 \
  --add-utr \
  --augustus-config-source refs/augustus_config
```

Expected handoff files:

```text
rnaseq_alignment/*.rnaseq.sorted.bam
rnaseq_alignment/*.rnaseq.sorted.bam.bai
rnaseq_alignment/*.hisat2_rnaseq_manifest.tsv
braker3_annotation/*.braker3.gff3
braker3_annotation/*.braker3.gtf
braker3_annotation/*.braker3.protein.fa
braker3_annotation/*.braker3.cds.fa
braker3_annotation/*.braker3_manifest.tsv
```

QC requires non-empty RNA evidence BAMs, matching genome and BAM reference names, documented RNA library sources, documented protein evidence source, writable AUGUSTUS config, retained BRAKER logs, and reviewed BRAKER GFF3 before downstream CDS/PEP extraction.

## 04 GFF/CDS/PEP extraction and structure statistics

Use `scripts/04_gff/gff_cds_pep.py` after gene structure annotation to produce clean downstream files. Use `scripts/04_gff/run_gff_structure_workflow.sh` to summarize gene-structure distributions and prepare plot-ready handoff tables across one or more species.

```bash
python3 scripts/04_gff/gff_cds_pep.py \
  --manifest manifest.tsv \
  --outdir gff_cds_pep_outputs

bash scripts/04_gff/run_gff_structure_workflow.sh \
  --gff Arabidopsis_thaliana.annotation.primary.gff3 \
  --species Arabidopsis_thaliana \
  --genome Arabidopsis_thaliana.genome.fa \
  --compare-species Arabidopsis_lyrata \
  --compare-gff Arabidopsis_lyrata.annotation.primary.gff3 \
  --outdir gff_structure \
  --prefix Arabidopsis_thaliana.gff_structure
```

Expected handoff files:

```text
Arabidopsis_thaliana.annotation.primary.gff3
Arabidopsis_thaliana.cds.primary.fa
Arabidopsis_thaliana.protein.primary.fa
gff_structure/*.metrics.tsv
gff_structure/*.distributions.tsv
gff_structure/*.feature_summary.tsv
gff_structure/*.chrom_summary.tsv
gff_structure/*.qc.tsv
gff_structure/*.reference_distribution.tsv
gff_structure/*.plot_handoff.*.tsv
gff_structure/*.gene_length_distribution.pdf
gff_structure/*.exon_number.pdf
```

QC requires matching FASTA/GFF seqids, reviewed CDS check tables, no unresolved duplicate IDs, valid Parent links, no out-of-bound coordinates when genome FASTA is supplied, and documented comparison-species GFF versions.

## 05 Genome features, introns, region context, methylation, and introner evidence

Primary workflow drivers:

```text
scripts/05_genome_features/run_genome_features_workflow.sh
scripts/05_genome_features/run_region_context_workflow.sh
```

### Intron extraction

Use `scripts/05_genome_features/extract_introns.py` to infer introns from exon or CDS features. BED outputs are 0-based half-open. Use unique intron loci for density tracks to avoid isoform double-counting.

```bash
python3 scripts/05_genome_features/extract_introns.py \
  --gff Arabidopsis_thaliana.annotation.primary.gff3 \
  --genome Arabidopsis_thaliana.genome.fa \
  --out Arabidopsis_thaliana.introns.bed \
  --short-out Arabidopsis_thaliana.short_introns_40_65bp.bed \
  --details-out Arabidopsis_thaliana.introns.details.tsv \
  --unique-bed Arabidopsis_thaliana.introns.unique.bed \
  --unique-details-out Arabidopsis_thaliana.introns.unique.details.tsv \
  --chrom-summary Arabidopsis_thaliana.introns.chrom_summary.tsv \
  --summary Arabidopsis_thaliana.introns.summary.tsv
```

### Region context and methylation metaprofiles

Use `scripts/05_genome_features/run_region_context_workflow.sh` when a target BED, such as standardized EVE/GEVE regions, needs feature enrichment and optional methylation summaries.

```bash
bash scripts/05_genome_features/run_region_context_workflow.sh \
  --target-bed Arabidopsis_thaliana.eve_geve_regions.bed \
  --outdir region_context \
  --prefix Arabidopsis_thaliana.eve_geve \
  --features Arabidopsis_thaliana.annotation.primary.gff3 \
  --feature-format gff \
  --feature-types gene,exon,CDS \
  --background-bed Arabidopsis_thaliana.callable_windows.bed \
  --cx Arabidopsis_thaliana.bismark.CX_report.txt.gz \
  --bins 25,100,25
```

The region-context workflow reports feature overlap counts, covered bp, coverage fractions, fold enrichment versus background when supplied, long methylation bin tables, and CG/CHG/CHH context summaries.

### Introner-elements workflow

Use `scripts/05_genome_features/run_introner_elements.sh` as an anonymized wrapper for an external Introner-elements installation. Supply tool paths at runtime.

The abstract method is:

```text
1. Identify candidate introner clusters from GFF.
2. Extract candidate coordinates from pass files.
3. Perform blast-back checks.
4. Screen candidates relative to nearby genes.
5. Remove duplicate candidate calls.
```

QC requires valid BED coordinate systems, comparable target/background region definitions, Bismark CX coverage thresholds, tool-version notes, candidate-count summaries, and manual review of high-confidence introner candidates.

## 06 Functional annotation, COG/NOG summaries, and GO handoffs

Functional annotation combines InterProScan, eggNOG, KofamScan, DIAMOND/BLASTP, optional local EnrichPipeline enrichment, and maintained parser scripts. Use `scripts/06_annotation/run_kofam_annotation_workflow.sh` to run KofamScan/KEGG annotation from protein FASTA when raw Kofam outputs are not already available. Use `scripts/06_annotation/run_functional_annotation_workflow.sh` as the primary stage driver when multiple annotation inputs are available. Use `scripts/06_annotation/run_enrichpipeline_enrichment_workflow.sh` only with a local external EnrichPipeline directory; do not commit the EnrichPipeline archive or extracted databases. Use `scripts/06_annotation/run_go_enrichment_plot_handoff.sh` when a foreground gene set needs GO enrichment plus a semantic-plot handoff table.

```bash
bash scripts/06_annotation/run_kofam_annotation_workflow.sh \
  --protein Arabidopsis_thaliana.protein.primary.fa \
  --outdir kofam_annotation \
  --prefix Arabidopsis_thaliana \
  --exec-option "--profile refs/kofam/profiles" \
  --exec-option "--ko-list refs/kofam/ko_list" \
  --evalue 1e-5

python3 scripts/06_annotation/parse_interproscan_tsv.py --input Arabidopsis_thaliana.interproscan.tsv --out Arabidopsis_thaliana.iprscan.xls
python3 scripts/06_annotation/parse_kofam_detail.py --input kofam_annotation/Arabidopsis_thaliana.kofam.detail.txt --out Arabidopsis_thaliana.kofam.tsv
python3 scripts/06_annotation/merge_function_annotations.py --gff Arabidopsis_thaliana.annotation.primary.gff3 --out Arabidopsis_thaliana.functional_annotation.tsv

bash scripts/06_annotation/run_enrichpipeline_enrichment_workflow.sh \
  --enrichpipeline-dir refs/EnrichPipeline \
  --class KEGG \
  --map-gene Arabidopsis_thaliana.KEGG.map.gene.txt \
  --supply expanded_family_genes.ids \
  --supply2 contracted_family_genes.ids \
  --outdir enrichpipeline_kegg_exp_con \
  --prefix Arabidopsis_thaliana.expansion_contraction
```

After `functional_annotation.tsv` is available, summarize downstream terms for figures, enrichment tests, and family-level interpretation.

```bash
python3 scripts/06_annotation/summarize_go_terms.py \
  --annotation Arabidopsis_thaliana.functional_annotation.tsv \
  --out Arabidopsis_thaliana.go.counts.tsv \
  --gene2go Arabidopsis_thaliana.gene2go.tsv

python3 scripts/06_annotation/summarize_pfam_domains.py \
  --annotation Arabidopsis_thaliana.functional_annotation.tsv \
  --out Arabidopsis_thaliana.pfam.counts.tsv \
  --gene2pfam Arabidopsis_thaliana.gene2pfam.tsv

python3 scripts/06_annotation/summarize_kegg_pathways.py \
  --annotation Arabidopsis_thaliana.functional_annotation.tsv \
  --ko-map refs/ko_to_pathway.tsv \
  --pathway-names refs/pathway_names.tsv \
  --out Arabidopsis_thaliana.kegg.pathway_counts.tsv \
  --gene2pathway Arabidopsis_thaliana.gene2pathway.tsv \
  --unmapped Arabidopsis_thaliana.kegg.unmapped_ko.tsv

python3 scripts/06_annotation/summarize_eggnog_categories.py \
  --eggnog Arabidopsis_thaliana.eggnog.tsv \
  --out Arabidopsis_thaliana.eggnog_category_summary.tsv \
  --gene2category Arabidopsis_thaliana.gene2eggnog_category.tsv

python3 scripts/06_annotation/summarize_domain_architecture.py \
  --iprscan Arabidopsis_thaliana.iprscan.xls \
  --out Arabidopsis_thaliana.domain_architecture.tsv \
  --summary Arabidopsis_thaliana.domain_architecture_summary.tsv
```

Use `scripts/06_annotation/enrich_annotation_terms.py` for simple foreground-vs-background overrepresentation tests when a target gene list is already defined. Use the GO handoff driver when downstream semantic-space plotting is planned:

```bash
bash scripts/06_annotation/run_go_enrichment_plot_handoff.sh \
  --annotation Arabidopsis_thaliana.functional_annotation.tsv \
  --foreground gained_family_genes.ids \
  --background all_tested_genes.ids \
  --outdir go_plot_handoff \
  --go-names refs/go_term_names.tsv
```

Unannotated genes should remain in merged tables with `NA` fields. Term-map sources, eggNOG database versions, foreground/background gene lists, and external GO visualization tools must be recorded in project run notes.

## 07 Gene families, target-family discovery, expression evidence, and phylogeny helpers

Gene-family and orthogroup analysis comes before alignment and tree-building. Use `scripts/07_gene_family/run_gene_family_workflow.sh` to chain OrthoFinder handoff, family summaries, member extraction, and optional supermatrix preparation. Use `scripts/07_gene_family/run_target_family_workflow.sh` when a project needs data-driven discovery of a functional family or gene set from annotation, BLAST/DIAMOND, seed IDs, peptide FASTA, and expression evidence.

Key handoffs:

```text
protein FASTA per species -> optional FASTA ID prefixing -> OrthoFinder -> gene-family summaries -> selected orthogroups -> alignments -> trimmed alignments -> gene trees -> tree summaries
functional annotation + target rule table + optional BLAST/seed/expression evidence -> target gene IDs -> peptide FASTA and tree-tip metadata -> family expression summaries
```

```bash
python3 scripts/07_gene_family/prefix_fasta_ids.py \
  --input Arabidopsis_thaliana.protein.primary.fa \
  --prefix Arabidopsis_thaliana \
  --sep '|' \
  --out Arabidopsis_thaliana.protein.primary.prefixed.fa \
  --map Arabidopsis_thaliana.species_gene_id_map.tsv

orthofinder \
  -f protein_dir \
  -t 32 \
  -a 32

python3 scripts/07_gene_family/summarize_orthofinder_gene_families.py \
  --orthogroups Orthogroups.tsv \
  --gene-count Orthogroups.GeneCount.tsv \
  --out orthofinder_gene_family_summary.tsv \
  --single-copy-list single_copy_orthogroups.list \
  --core-list core_orthogroups.list \
  --lineage-specific-list lineage_specific_orthogroups.list

bash scripts/07_gene_family/run_target_family_workflow.sh \
  --annotation Arabidopsis_thaliana.functional_annotation.tsv \
  --rules refs/target_family_rules.tsv \
  --outdir target_family_work \
  --peptides Arabidopsis_thaliana.protein.primary.fa \
  --expression Arabidopsis_thaliana.rsem_tpm.tsv
```

Target-family rule tables should record rule IDs, family IDs, evidence types, source fields, patterns, and match modes. Use `extract_orthogroup_members.py`, alignment tools, and tree helpers only after the family or orthogroup set is defined. `root_tree.py` is a rooting handoff helper only; it does not reroot topology. Use validated external tree tools for real rerooting.

## 08 Gene-family evolution: Count, CAFE, and target-family integration

Use Count and CAFE after OrthoFinder has produced a species-by-family count matrix and the species tree has been checked against the same species names. Use `scripts/08_gene_family_evolution/run_gene_family_evolution_workflow.sh` as the primary stage driver for Count input preparation, optional Count parsing, and CAFE filtering. Use `integrate_target_family_evolution.py` to connect Stage 07 target-family evidence to orthogroup gain/loss and expansion/contraction results.

```bash
python3 scripts/08_gene_family_evolution/prepare_count_input.py \
  --orthofinder-count Orthogroups.GeneCount.tsv \
  --species-tree species_tree.nwk \
  --out count_input.tsv \
  --rejected count_rejected_families.tsv \
  --species-order count_species_order.tsv

Count \
  -tree species_tree.nwk \
  -table count_input.tsv \
  > count_gain_loss.raw.tsv

python3 scripts/08_gene_family_evolution/parse_count_gain_loss.py \
  --input count_gain_loss.raw.tsv \
  --format long \
  --out count_gain_loss.tsv

python3 scripts/08_gene_family_evolution/summarize_family_gain_loss.py \
  --count-gain-loss count_gain_loss.tsv \
  --family-summary orthofinder_gene_family_summary.tsv \
  --out family_gain_loss_summary.tsv \
  --node-summary node_gain_loss_summary.tsv
```

Integrate target-family evidence with family-evolution calls:

```bash
python3 scripts/08_gene_family_evolution/integrate_target_family_evolution.py \
  --target-evidence target_family_work/Arabidopsis_thaliana.target_families.target_family_evidence.tsv \
  --orthogroups Orthogroups.tsv \
  --family-gain-loss family_gain_loss_summary.tsv \
  --out target_family_evolution.tsv \
  --summary target_family_evolution_summary.tsv
```

For CAFE handoff:

```bash
python3 scripts/08_gene_family_evolution/prepare_cafe_input.py \
  --orthofinder-count Orthogroups.GeneCount.tsv \
  --species-tree species_tree.nwk \
  --out cafe_input.tsv

python3 scripts/08_gene_family_evolution/filter_cafe_families.py \
  --input cafe_input.tsv \
  --max-copy 100 \
  --min-species 2 \
  --remove-all-zero \
  --out cafe_input.filtered.tsv \
  --removed cafe_input.removed.tsv
```

QC requires tree tips to match count-matrix columns, rejected or filtered families to retain reasons, and Count/CAFE model assumptions to be recorded.

## 09 Synteny context, MCScan/JCVI summaries, heatmaps, and Circos links

Use minimap2, WGDI/MCScanX/JCVI, and `scripts/09_synteny/run_synteny_context_workflow.sh` to normalize synteny outputs, build heatmap-ready matrices, and compare synteny support in target regions versus background regions. Use `anchors_to_circos_links.py` when Circos link files are needed.

```bash
bash scripts/09_synteny/run_synteny_context_workflow.sh \
  --input Arabidopsis_thaliana.Arabidopsis_lyrata.anchors \
  --format anchor \
  --outdir synteny_context \
  --pair-label Arabidopsis_thaliana.Arabidopsis_lyrata \
  --gene-bed Arabidopsis_thaliana.gene.bed \
  --target-bed Arabidopsis_thaliana.eve_geve_regions.bed \
  --background-bed Arabidopsis_thaliana.callable_windows.bed
```

QC requires chromosome ID consistency, in-bound coordinates across FASTA/GFF/BED/link files, traceable MCScan/JCVI input format, and documented target/background region definitions.

## 10 HGT candidate screening, full-method event summaries, and validation handoff

HGT screening starts by generating BLAST/DIAMOND similarity results against a broad local database such as NR, then uses the external `blast2hgt` workflow to convert those hits into taxonomy-group HGT candidate signals. BioAnalysis separates single-species candidate validation from multi-species HGT-family event summaries. The workflow does not download taxonomy or run remote services; local NR, blast2hgt, accession/taxonomy databases, orthogroups, and node lists must be prepared outside this repository.

Required inputs:

```text
query protein FASTA
split or concatenated BLAST/DIAMOND outfmt 6 output from a broad local database such as NR
local blast2hgt installation with configured accession/taxonomy database
self/ingroup taxon group used as the first blast2hgt definition
candidate donor taxon groups
species-to-rp.tsv manifest for comparable multi-species matrices
Orthogroups.HGT.txt and Orthogroups.all.txt when running node HGT event summaries
ALL and HGT gene-count matrices plus node/species parent lists
optional GFF, functional annotation, intron details, synteny evidence, and protein FASTA
```

Main Stage 10 scripts:

```text
scripts/10_hgt/run_hgt_nr_taxonlist_workflow.sh
scripts/10_hgt/run_hgt_blast2hgt_workflow.sh
scripts/10_hgt/build_hgt_condition_matrices.py
scripts/10_hgt/prepare_hgt_orthogroup_inputs.py
scripts/10_hgt/summarize_hgt_family_events.py
scripts/10_hgt/prepare_hgt_visualization_handoff.py
scripts/10_hgt/run_hgt_full_method_workflow.sh
scripts/10_hgt/run_hgt_family_integration_workflow.sh
```

Single-species blast2hgt screening and validation handoff:

```bash
bash scripts/10_hgt/run_hgt_blast2hgt_workflow.sh \
  --query Arabidopsis_thaliana.protein.primary.fa \
  --blast2hgt-dir refs/blast2hgt \
  --blast-glob 'nr_by_taxon/Arabidopsis_thaliana_*.nr.out' \
  --outdir hgt_work \
  --self-group Brassicaceae=3700 \
  --define Viridiplantae=33090 \
  --define fungi=4751 \
  --define archaea=2157 \
  --define bacteria=2 \
  --define Metazoa=33208 \
  --define virus=10239 \
  --donor-groups bacteria,fungi,Metazoa,virus,archaea,other \
  --min-alien-index 0 \
  --min-donor-bitscore 50 \
  --min-donor-taxon-count 1 \
  --gff Arabidopsis_thaliana.annotation.primary.gff3 \
  --functional-annotation Arabidopsis_thaliana.functional_annotation.tsv \
  --intron-details Arabidopsis_thaliana.introns.details.tsv
```

Comparable multi-species HGT full-method order:

```bash
python3 scripts/10_hgt/build_hgt_condition_matrices.py \
  --species-manifest hgt_species_rp_manifest.tsv \
  --outdir hgt_conditions \
  --donor-groups bacteria,fungi,Metazoa,virus,archaea,other

python3 scripts/10_hgt/prepare_hgt_orthogroup_inputs.py \
  --candidates hgt_conditions/Condition2_HGT_candidates.tsv \
  --protein Arabidopsis_thaliana.protein.primary.fa \
  --outdir hgt_orthogroup_inputs \
  --prefix tree_species.Condition2

python3 scripts/10_hgt/summarize_hgt_family_events.py \
  --method m2 \
  --count-hgt Orthogroups.HGT.GeneCount.result.txt \
  --count-all Orthogroups.all.GeneCount.result.txt \
  --node-list node.list \
  --txt-hgt Orthogroups.HGT.txt \
  --txt-all Orthogroups.all.txt \
  --outdir hgt_family_events_m2

python3 scripts/10_hgt/prepare_hgt_visualization_handoff.py \
  --condition-matrix hgt_conditions/Condition2_Matching_taxon_counts_matrix.tsv \
  --event-summary hgt_family_events_m2/M2_Summary_Evolution.tsv \
  --source-breakdown hgt_family_events_m2/M2_HGT_Source_Breakdown.tsv \
  --outdir hgt_visualization \
  --prefix tree_species.Condition2.M2
```

Method definitions:

- Condition1: `alien_index > 0` and `AI_taxon` is in the external donor whitelist.
- Condition2: Condition1 plus `AI_taxon == h_taxon`.
- M1 gene-centric: mark an ALL orthogroup as HGT when HGT genes are more than the configured family ratio cutoff.
- M2 family-centric: map HGT-only orthogroups back to ALL orthogroups by best overlap, then count ALL-family gain/expansion events; this is the preferred event-summary method when HGT-only clustering is available.

Interpretation rules:

- Treat HGT calls as candidates until phylogenetic and contamination/context evidence are reviewed.
- Node HGT numbers are family gain/expansion events, not sums of species-level HGT genes.
- Mark ambiguous taxonomy as `unknown`.
- Mark missing context data as `missing` or `not_tested`.
- Do not treat lack of synteny or missing introns alone as HGT evidence.

## 11 Visualization matrices and final evidence tables

Use `scripts/11_visualization/run_visualization_handoff_workflow.sh` after coordinates, IDs, target-family evidence, HGT candidates, and family-evolution tables have been validated. This stage writes plot-ready TSV matrices and manifests for external plotting tools; plotting dependencies are not vendored.

```bash
bash scripts/11_visualization/run_visualization_handoff_workflow.sh \
  --outdir visualization_handoff \
  --prefix Arabidopsis_thaliana.summary \
  --gene-set HGT=hgt_candidate_genes.ids \
  --gene-set target_family=target_family_genes.ids \
  --expression-summary target_family_expression_summary.tsv \
  --target-evolution target_family_evolution.tsv \
  --hgt-family hgt_family_evolution.tsv
```

Final evidence tables should link every claim back to source files, command templates, QC outputs, and matrix manifest rows.
