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
01 preprocessing and contamination screening
02 assembly and assembly QC
03 repeat annotation
04 GFF/CDS/PEP extraction
05 genome features, introns, and introner evidence
06 functional annotation and downstream term summaries
07 gene families, orthogroups, and phylogeny helpers
08 gene-family evolution with Count and CAFE
09 synteny and Circos links
10 HGT candidate screening and validation handoff
11 visualization and final evidence tables
```

## 01 Preprocessing and NT-based decontamination

### Purpose

Screen assembly contigs against a local NT database and remove likely contaminant contigs using a local helper-script workflow. The repository stores only a portable wrapper; private database paths and helper-script locations must be supplied at runtime.

### Main script

```text
scripts/01_preprocessing/01_nt_decontaminate_contigs.sh
```

### Required inputs

```text
Arabidopsis_thaliana.assembly.fa
local NT BLAST database directory
accession-to-taxid table
lineage table
helper script directory containing cn50.py, length_by_seq.pl, get_cov_list_nt.pl, exclude_fa.pl
```

### Expected outputs

```text
Arabidopsis_thaliana_rm/Arabidopsis_thaliana.n50
Arabidopsis_thaliana_rm/Arabidopsis_thaliana.m6
Arabidopsis_thaliana_rm/Arabidopsis_thaliana.nt.fa
Arabidopsis_thaliana_rm/Arabidopsis_thaliana.nt.fa.n50
```

### QC

- Record NT database version and taxonomy-file versions in project run notes.
- Inspect removed contigs before treating the filtered FASTA as final.
- Do not commit private database paths or real sample IDs to this repository.

## 02 Assembly and assembly QC

Use external assemblers such as hifiasm, NextDenovo, SPAdes, or Canu. Use `scripts/02_assembly/assembly_stats.py` to produce standardized assembly statistics.

```bash
python3 scripts/02_assembly/assembly_stats.py \
  --fasta Arabidopsis_thaliana.genome.fa \
  --out Arabidopsis_thaliana.assembly.stats.tsv \
  --lengths Arabidopsis_thaliana.assembly.lengths.tsv
```

QC requires non-empty FASTA, unique sequence IDs, plausible total length, and retained assembly logs.

## 03 Repeat annotation

Repeat annotation uses portable wrappers around external tools available on `PATH`.

Key scripts:

```text
scripts/03_repeat/LTR_Finder.sh
scripts/03_repeat/LTR_harvest.sh
scripts/03_repeat/repeatmodeler.sh
scripts/03_repeat/work.sh
scripts/03_repeat/rmout2gff.sh
scripts/03_repeat/repeat_stat.sh
scripts/03_repeat/trf.sh
```

Recommended handoff:

```text
uppercase genome FASTA -> LTR_FINDER/LTRharvest/RepeatModeler -> LTR_retriever -> RepeatMasker -> GFF3 and summary tables
```

QC requires non-empty LTR candidate files, repeat libraries, RepeatMasker `.out`, repeat GFF3, and repeat coverage summaries.

## 04 GFF/CDS/PEP extraction

Use `scripts/04_gff/gff_cds_pep.py` after gene structure annotation to produce clean downstream files.

```bash
python3 scripts/04_gff/gff_cds_pep.py \
  --manifest manifest.tsv \
  --outdir gff_cds_pep_outputs
```

Expected handoff files:

```text
Arabidopsis_thaliana.annotation.primary.gff3
Arabidopsis_thaliana.cds.primary.fa
Arabidopsis_thaliana.protein.primary.fa
```

QC requires matching FASTA/GFF seqids and reviewed CDS check tables.

## 05 Genome features, introns, and introner evidence

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

QC requires tool-version notes, candidate-count summaries, and manual review of high-confidence introner candidates.

## 06 Functional annotation and downstream term summaries

Functional annotation combines InterProScan, eggNOG, KofamScan, DIAMOND/BLASTP, and maintained parser scripts.

```bash
python3 scripts/06_annotation/parse_interproscan_tsv.py --input Arabidopsis_thaliana.interproscan.tsv --out Arabidopsis_thaliana.iprscan.xls
python3 scripts/06_annotation/parse_kofam_detail.py --input Arabidopsis_thaliana.kofam.detail.txt --out Arabidopsis_thaliana.kofam.tsv
python3 scripts/06_annotation/merge_function_annotations.py --gff Arabidopsis_thaliana.annotation.primary.gff3 --out Arabidopsis_thaliana.functional_annotation.tsv
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

python3 scripts/06_annotation/summarize_domain_architecture.py \
  --iprscan Arabidopsis_thaliana.iprscan.xls \
  --out Arabidopsis_thaliana.domain_architecture.tsv \
  --summary Arabidopsis_thaliana.domain_architecture_summary.tsv
```

Use `scripts/06_annotation/enrich_annotation_terms.py` for simple foreground-vs-background overrepresentation tests when a target gene list is already defined.

Unannotated genes should remain in merged tables with `NA` fields. Term-map sources and foreground/background gene lists must be recorded in project run notes.

## 07 Gene families, orthogroups, and phylogeny helpers

Gene-family and orthogroup analysis comes before alignment and tree-building. Use OrthoFinder to define families, summarize copy-number and occupancy patterns, then select families for downstream phylogeny helpers.

Key handoff:

```text
protein FASTA per species -> optional FASTA ID prefixing -> OrthoFinder -> gene-family summaries -> selected orthogroups -> alignments -> trimmed alignments -> gene trees -> tree summaries
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
```

Use `extract_orthogroup_members.py`, alignment tools, and tree helpers only after the family or orthogroup set is defined. `root_tree.py` is a rooting handoff helper only; it does not reroot topology. Use validated external tree tools for real rerooting.

## 08 Gene-family evolution: Count and CAFE

Use Count and CAFE after OrthoFinder has produced a species-by-family count matrix and the species tree has been checked against the same species names.

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

## 09 Synteny and Circos links

Use minimap2, WGDI/MCScanX/JCVI, and `scripts/09_synteny/anchors_to_circos_links.py`.

QC requires chromosome ID consistency and in-bound coordinates across FASTA, GFF, BED, and link files.

## 10 HGT candidate screening and validation handoff

HGT screening is a conservative local workflow. It does not download taxonomy or run remote services.

Required inputs:

```text
protein similarity hits from DIAMOND/BLASTP
local subject-to-taxonomy table
host/ingroup taxon groups
candidate donor taxon groups
optional GFF, functional annotation, intron details, and synteny evidence
```

Workflow:

```bash
python3 scripts/10_hgt/01_classify_hgt_hits.py \
  --hits Arabidopsis_thaliana.nr_hits.tsv \
  --taxonomy subject_taxonomy.tsv \
  --ingroup-groups Viridiplantae,Brassicaceae \
  --donor-groups Bacteria,Fungi,Metazoa \
  --exclude-groups synthetic,vector \
  --out Arabidopsis_thaliana.hgt.classified_hits.tsv \
  --summary Arabidopsis_thaliana.hgt.classified_summary.tsv

python3 scripts/10_hgt/02_score_hgt_candidates.py \
  --classified-hits Arabidopsis_thaliana.hgt.classified_hits.tsv \
  --out Arabidopsis_thaliana.hgt.candidates.tsv \
  --rejected Arabidopsis_thaliana.hgt.rejected.tsv \
  --summary Arabidopsis_thaliana.hgt.score_summary.tsv

python3 scripts/10_hgt/03_add_hgt_context.py \
  --candidates Arabidopsis_thaliana.hgt.candidates.tsv \
  --gff Arabidopsis_thaliana.annotation.primary.gff3 \
  --functional-annotation Arabidopsis_thaliana.functional_annotation.tsv \
  --intron-details Arabidopsis_thaliana.introns.details.tsv \
  --out Arabidopsis_thaliana.hgt.context.tsv \
  --bed Arabidopsis_thaliana.hgt.candidates.bed \
  --summary Arabidopsis_thaliana.hgt.context_summary.tsv

python3 scripts/10_hgt/04_prepare_hgt_validation.py \
  --context Arabidopsis_thaliana.hgt.context.tsv \
  --classified-hits Arabidopsis_thaliana.hgt.classified_hits.tsv \
  --outdir hgt_validation
```

Interpretation rules:

- Treat HGT calls as candidates until phylogenetic and contamination/context evidence are reviewed.
- Mark ambiguous taxonomy as `unknown`.
- Mark missing context data as `missing` or `not_tested`.
- Do not treat lack of synteny or missing introns alone as HGT evidence.

## 11 Visualization and final evidence tables

Use visualization scripts and external plotting tools only after coordinates and IDs have been validated. Final evidence tables should link every claim back to source files, command templates, and QC outputs.
