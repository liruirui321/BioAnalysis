# BioAnalysis Genome Workflow Command Templates

Commands use anonymized Arabidopsis-style placeholders. Replace paths and sample IDs only in project-specific run directories.

## 01 Preprocessing: NT-based contig decontamination

```bash
bash scripts/01_preprocessing/01_nt_decontaminate_contigs.sh \
  --id Arabidopsis_thaliana \
  --fasta Arabidopsis_thaliana.assembly.fa \
  --blast-db refs/nt_database \
  --accession2taxid refs/nucl_gb.accession2taxid.gz \
  --lineage refs/fullnamelineage.dmp.gz \
  --script-dir refs/nt_decontamination_helpers \
  --cpu 20 \
  --threshold 0.5
```

## 02 Assembly, Hi-C scaffolding, QC, and assessment

Run one assembly method at a time; do not combine these wrappers into a single assembly driver.

### hifiasm assembly

```bash
bash scripts/02_assembly/run_hifiasm_assembly.sh \
  --hifi Arabidopsis_thaliana.hifi.fa.gz \
  --outdir hifiasm_assembly \
  --prefix Arabidopsis_thaliana \
  --threads 32 \
  --hic-r1 Arabidopsis_thaliana.HiC_R1.fq.gz \
  --hic-r2 Arabidopsis_thaliana.HiC_R2.fq.gz
```

### NextDenovo assembly

```bash
bash scripts/02_assembly/run_nextdenovo_assembly.sh \
  --read Arabidopsis_thaliana.ont.fq.gz \
  --read-type ont \
  --genome-size 150m \
  --outdir nextdenovo_assembly \
  --prefix Arabidopsis_thaliana \
  --parallel-jobs 8
```

### SPAdes assembly

```bash
bash scripts/02_assembly/run_spades_assembly.sh \
  --pe1 Arabidopsis_thaliana.insert350_R1.fq.gz \
  --pe2 Arabidopsis_thaliana.insert350_R2.fq.gz \
  --pe1 Arabidopsis_thaliana.insert800_R1.fq.gz \
  --pe2 Arabidopsis_thaliana.insert800_R2.fq.gz \
  --outdir spades_assembly \
  --prefix Arabidopsis_thaliana \
  --threads 32 \
  --memory-gb 250 \
  --isolate
```

### Flye assembly

```bash
bash scripts/02_assembly/run_flye_assembly.sh \
  --read Arabidopsis_thaliana.ont.fq.gz \
  --read-type nano-raw \
  --genome-size 150m \
  --outdir flye_assembly \
  --prefix Arabidopsis_thaliana \
  --threads 32
```

### Canu assembly

```bash
bash scripts/02_assembly/run_canu_assembly.sh \
  --read Arabidopsis_thaliana.ont.fq.gz \
  --read-type nanopore \
  --genome-size 150m \
  --outdir canu_assembly \
  --prefix Arabidopsis_thaliana \
  --threads 32 \
  --memory-gb 250
```

### Verkko assembly

```bash
bash scripts/02_assembly/run_verkko_assembly.sh \
  --hifi Arabidopsis_thaliana.hifi.fa.gz \
  --hic-r1 Arabidopsis_thaliana.HiC_R1.fq.gz \
  --hic-r2 Arabidopsis_thaliana.HiC_R2.fq.gz \
  --outdir verkko_assembly \
  --prefix Arabidopsis_thaliana \
  --threads 32
```

### YaHS Hi-C scaffolding

```bash
bash scripts/02_assembly/run_yahs_scaffolding.sh \
  --assembly hifiasm_assembly/Arabidopsis_thaliana.hifiasm.assembly.fa \
  --hic-r1 Arabidopsis_thaliana.HiC_R1.fq.gz \
  --hic-r2 Arabidopsis_thaliana.HiC_R2.fq.gz \
  --outdir yahs_scaffolding \
  --prefix Arabidopsis_thaliana \
  --threads 32
```

### HapHiC Hi-C scaffolding

```bash
bash scripts/02_assembly/run_haphic_scaffolding.sh \
  --assembly hifiasm_assembly/Arabidopsis_thaliana.hifiasm.assembly.fa \
  --hic-r1 Arabidopsis_thaliana.HiC_R1.fq.gz \
  --hic-r2 Arabidopsis_thaliana.HiC_R2.fq.gz \
  --groups 5 \
  --outdir haphic_scaffolding \
  --prefix Arabidopsis_thaliana \
  --threads 32
```

### Assembly statistics

```bash
python3 scripts/02_assembly/assembly_stats.py \
  --fasta Arabidopsis_thaliana.genome.fa \
  --out Arabidopsis_thaliana.assembly.stats.tsv \
  --lengths Arabidopsis_thaliana.assembly.lengths.tsv
```

### BUSCO genome assessment

```bash
bash scripts/02_assembly/run_busco_qc_workflow.sh \
  --input Arabidopsis_thaliana.genome.fa \
  --lineage embryophyta_odb10 \
  --outdir busco_qc \
  --sample Arabidopsis_thaliana \
  --mode genome \
  --threads 20 \
  --offline \
  --force
```

### LAI assessment

```bash
bash scripts/02_assembly/run_lai_qc_workflow.sh \
  --genome Arabidopsis_thaliana.genome.fa \
  --outdir lai_qc \
  --prefix Arabidopsis_thaliana \
  --threads 20 \
  --max-length 7000 \
  --min-length 100 \
  --min-similarity 85
```

### Merqury QV assessment

```bash
bash scripts/02_assembly/run_merqury_qv_workflow.sh \
  --genome Arabidopsis_thaliana.genome.fa \
  --read Arabidopsis_thaliana.reads_1.fq.gz \
  --read Arabidopsis_thaliana.reads_2.fq.gz \
  --outdir merqury_qv \
  --prefix Arabidopsis_thaliana \
  --kmer 21 \
  --best-k
```

Use each assembly, scaffolding, and assessment script independently; do not chain these methods into a single driver.

## 03 Repeat annotation

```bash
bash scripts/03_repeat/run_repeat_annotation_workflow.sh \
  --genome Arabidopsis_thaliana.genome.fa \
  --outdir repeat_work \
  --prefix Arabidopsis_thaliana \
  --threads 20 \
  --ltr-finder-threads 30 \
  --ltr-retriever-threads 12 \
  --repeatmasker-out Arabidopsis_thaliana.repeatmasker.all.out \
  --genome-size 150000000
```

### TE/EVE post-processing handoff

```bash
bash scripts/03_repeat/run_te_eve_postprocessing_workflow.sh \
  --outdir repeat_postprocess \
  --prefix Arabidopsis_thaliana \
  --tesorter-domains Arabidopsis_thaliana.rexdb.dom.faa \
  --eve-input Arabidopsis_thaliana.eve_geve.raw.gff3 \
  --eve-format gff \
  --eve-feature-types region,match \
  --background-bed Arabidopsis_thaliana.callable_windows.bed \
  --repeatmasker-out Arabidopsis_thaliana.repeatmasker.all.out \
  --substitution-rate 7e-9
```

If the EVE/GEVE calls are already available as BED, pass `--eve-format bed`. The standardized BED generated by this driver is reused as the default TEsorter target-region input unless `--target-bed` is supplied explicitly.

## 04 GFF/CDS/PEP extraction and structure statistics

```bash
python3 scripts/04_gff/gff_cds_pep.py \
  --manifest manifest.tsv \
  --outdir gff_cds_pep_outputs
```

```bash
bash scripts/04_gff/run_gff_structure_workflow.sh \
  --gff Arabidopsis_thaliana.annotation.primary.gff3 \
  --species Arabidopsis_thaliana \
  --genome Arabidopsis_thaliana.genome.fa \
  --compare-species Arabidopsis_lyrata \
  --compare-gff Arabidopsis_lyrata.annotation.primary.gff3 \
  --compare-species Arabidopsis_halleri \
  --compare-gff Arabidopsis_halleri.annotation.primary.gff3 \
  --outdir gff_structure \
  --prefix Arabidopsis_thaliana.gff_structure
```

When `Rscript` is available, the workflow also writes base-R PDF plots. Add `--skip-r-plots` to produce only TSV statistics and plot-ready handoff tables.

## 05 Intron and introner workflows

```bash
bash scripts/05_genome_features/run_genome_features_workflow.sh \
  --gff Arabidopsis_thaliana.annotation.primary.gff3 \
  --genome Arabidopsis_thaliana.genome.fa \
  --outdir genome_features \
  --prefix Arabidopsis_thaliana \
  --introner-tool-dir refs/Introner-elements-main \
  --directory-list directory_list.tsv
```

### Region context and methylation metaprofiles

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
  --bins 25,100,25 \
  --flank-bp 2000 \
  --min-coverage 3
```

Use `--skip-feature-enrichment` or `--skip-methylation` when only one branch of the region-context workflow is needed.

## 06 Functional annotation and downstream term summaries

```bash
bash scripts/06_annotation/run_functional_annotation_workflow.sh \
  --gff Arabidopsis_thaliana.annotation.primary.gff3 \
  --outdir annotation_work \
  --prefix Arabidopsis_thaliana \
  --interproscan Arabidopsis_thaliana.interproscan.tsv \
  --kofam-detail Arabidopsis_thaliana.kofam.detail.txt \
  --eggnog Arabidopsis_thaliana.eggnog.tsv \
  --ko-map refs/ko_to_pathway.tsv \
  --pathway-names refs/pathway_names.tsv \
  --foreground gained_family_genes.ids \
  --enrichment-mode kegg \
  --enrichment-term-column KEGG_ko
```

### GO enrichment plot handoff

```bash
bash scripts/06_annotation/run_go_enrichment_plot_handoff.sh \
  --annotation annotation_work/Arabidopsis_thaliana.functional_annotation.tsv \
  --foreground gained_family_genes.ids \
  --background all_tested_genes.ids \
  --outdir go_plot_handoff \
  --prefix Arabidopsis_thaliana.gained_families \
  --go-names refs/go_term_names.tsv \
  --q-value-cutoff 0.05 \
  --max-terms 200
```

The handoff output is a plot-ready table for external semantic-space or enrichment-plot tools; plotting dependencies are not vendored.

## 07 Gene families, orthogroups, and phylogeny helpers

```bash
bash scripts/07_gene_family/run_gene_family_workflow.sh \
  --protein-dir protein_dir \
  --orthogroups Orthogroups.tsv \
  --gene-count Orthogroups.GeneCount.tsv \
  --species-list species.list \
  --outdir gene_family_work \
  --target-list target_orthogroups.list \
  --id-map species_gene_id_map.tsv \
  --alignment-dir trimmed_alignment_dir \
  --alignment-suffix .trimmed.fa
```

### Target functional-family discovery and expression evidence

```bash
bash scripts/07_gene_family/run_target_family_workflow.sh \
  --annotation annotation_work/Arabidopsis_thaliana.functional_annotation.tsv \
  --rules refs/target_family_rules.tsv \
  --outdir target_family_work \
  --prefix Arabidopsis_thaliana.target_families \
  --blast-hits Arabidopsis_thaliana.target_family.diamond.tsv \
  --seed-ids refs/target_family_seed_genes.ids \
  --peptides Arabidopsis_thaliana.protein.primary.fa \
  --expression Arabidopsis_thaliana.rsem_tpm.tsv \
  --id-column transcript_id \
  --expression-id-column gene_id
```

The rule table is project-supplied and can combine annotation keywords, Pfam/InterPro signatures, KO IDs, seed genes, and BLAST/DIAMOND subject patterns without hardcoding biological family names into the scripts.

## 08 Gene-family evolution: Count and CAFE

```bash
bash scripts/08_gene_family_evolution/run_gene_family_evolution_workflow.sh \
  --orthofinder-count Orthogroups.GeneCount.tsv \
  --species-tree species_tree.nwk \
  --outdir family_evolution_work \
  --count-output count_gain_loss.raw.tsv \
  --family-summary orthofinder_gene_family_summary.tsv \
  --max-copy 100 \
  --min-species 2
```

Run Count between input preparation and parsing when `count_gain_loss.raw.tsv` is not already available:

```bash
Count -tree species_tree.nwk -table family_evolution_work/count_input.tsv > count_gain_loss.raw.tsv
```

Integrate target-family evidence with orthogroup evolution results:

```bash
python3 scripts/08_gene_family_evolution/integrate_target_family_evolution.py \
  --target-evidence target_family_work/Arabidopsis_thaliana.target_families.target_family_evidence.tsv \
  --orthogroups Orthogroups.tsv \
  --family-gain-loss family_evolution_work/family_gain_loss_summary.tsv \
  --out target_family_evolution.tsv \
  --summary target_family_evolution_summary.tsv
```

## 09 Synteny context, MCScan/JCVI summaries, and heatmap matrices

```bash
bash scripts/09_synteny/run_synteny_context_workflow.sh \
  --input Arabidopsis_thaliana.Arabidopsis_lyrata.anchors \
  --format anchor \
  --outdir synteny_context \
  --prefix Arabidopsis_thaliana.Arabidopsis_lyrata \
  --pair-label Arabidopsis_thaliana.Arabidopsis_lyrata \
  --matrix-metric blocks \
  --symmetric \
  --gene-bed Arabidopsis_thaliana.gene.bed \
  --target-bed Arabidopsis_thaliana.eve_geve_regions.bed \
  --background-bed Arabidopsis_thaliana.callable_windows.bed
```

```bash
python3 scripts/09_synteny/anchors_to_circos_links.py \
  --simple Arabidopsis_thaliana.Arabidopsis_lyrata.anchors.simple \
  --ref-bed Arabidopsis_thaliana.gene.bed \
  --query-bed Arabidopsis_lyrata.gene.bed \
  --out block_link.txt
```

## 10 HGT screening and validation handoff

```bash
bash scripts/10_hgt/run_hgt_blast2hgt_workflow.sh \
  --query Arabidopsis_thaliana.protein.primary.fa \
  --blast2hgt-dir refs/blast2hgt \
  --blast-glob 'Arabidopsis_thaliana.protein.primary.fa_*.nr.out' \
  --outdir hgt_work \
  --self-group Brassicaceae=3700 \
  --define Viridiplantae=33090 \
  --define fungi=4751 \
  --define archaea=2157 \
  --define bacteria=2 \
  --define Metazoa=33208 \
  --define virus=10239 \
  --donor-groups bacteria,fungi,Metazoa \
  --min-alien-index 0 \
  --min-donor-bitscore 50 \
  --min-donor-taxon-count 1 \
  --gff Arabidopsis_thaliana.annotation.primary.gff3 \
  --functional-annotation Arabidopsis_thaliana.functional_annotation.tsv \
  --intron-details Arabidopsis_thaliana.introns.details.tsv
```

If NR taxon-group DIAMOND searches have not already been run, replace `--blast-glob` with `--diamond-db-dir refs/nr_by_taxon` and add repeated `--taxon` values for the self, vertical, and donor groups.

Integrate HGT candidates with donor taxonomy, orthogroups, target-family evidence, and family-evolution results:

```bash
bash scripts/10_hgt/run_hgt_family_integration_workflow.sh \
  --candidates hgt_work/Arabidopsis_thaliana.protein.primary.fa.hgt.candidates.tsv \
  --outdir hgt_family_integration \
  --prefix Arabidopsis_thaliana.hgt \
  --taxonomy refs/hgt_candidate_donor_taxonomy.tsv \
  --rank genus \
  --orthogroups Orthogroups.tsv \
  --target-evidence target_family_work/Arabidopsis_thaliana.target_families.target_family_evidence.tsv \
  --family-gain-loss family_evolution_work/family_gain_loss_summary.tsv
```

## 11 Visualization matrices and handoff utilities

```bash
bash scripts/11_visualization/run_visualization_handoff_workflow.sh \
  --outdir visualization_handoff \
  --prefix Arabidopsis_thaliana.summary \
  --gene-set HGT=hgt_candidate_genes.ids \
  --gene-set target_family=target_family_work/Arabidopsis_thaliana.target_families.target_gene_ids.txt \
  --gene-set gained=gained_family_genes.ids \
  --expression-summary target_family_work/Arabidopsis_thaliana.target_families.expression_family_summary.tsv \
  --target-evolution target_family_evolution.tsv \
  --hgt-family hgt_family_integration/Arabidopsis_thaliana.hgt.hgt_family_evolution.tsv
```

This stage writes plot-ready TSV matrices and manifests for external plotting tools; it does not vendor plotting dependencies.
