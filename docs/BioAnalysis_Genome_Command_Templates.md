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

## 02 Assembly QC

```bash
python3 scripts/02_assembly/assembly_stats.py \
  --fasta Arabidopsis_thaliana.genome.fa \
  --out Arabidopsis_thaliana.assembly.stats.tsv \
  --lengths Arabidopsis_thaliana.assembly.lengths.tsv
```

## 03 Repeat annotation

```bash
seqkit seq -u Arabidopsis_thaliana.genome.fa > Arabidopsis_thaliana.genome.upper.fa
ln -s Arabidopsis_thaliana.genome.upper.fa genome.fa
```

```bash
bash scripts/03_repeat/LTR_Finder.sh --genome genome.fa --threads 30
bash scripts/03_repeat/LTR_harvest.sh --genome genome.fa --index-prefix genome.fa --out genome.fa.harvest.scn
bash scripts/03_repeat/repeatmodeler.sh --genome genome.fa --database mydb --threads 20
bash scripts/03_repeat/work.sh --genome genome.fa --harvest genome.fa.harvest.scn --finder genome.fa.finder.combine.scn --threads 12
```

```bash
bash scripts/03_repeat/rmout2gff.sh Arabidopsis_thaliana.repeatmasker.all.out > Arabidopsis_thaliana.repeatmasker.all.gff3
bash scripts/03_repeat/repeat_stat.sh Arabidopsis_thaliana.repeatmasker.all.out 150000000 Arabidopsis_thaliana.repeat.summary.tsv
```

```bash
bash scripts/03_repeat/trf.sh \
  --genome genome.fa \
  --out-prefix Arabidopsis_thaliana.trf \
  --trf-args "2 5 7 80 10 50 2000" \
  --gff Arabidopsis_thaliana.trf.gff3
```

## 04 GFF/CDS/PEP extraction

```bash
python3 scripts/04_gff/gff_cds_pep.py \
  --manifest manifest.tsv \
  --outdir gff_cds_pep_outputs
```

## 05 Intron and introner workflows

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

```bash
bash scripts/05_genome_features/run_introner_elements.sh \
  --gff Arabidopsis_thaliana.annotation.primary.gff3 \
  --directory-list directory_list.tsv \
  --tool-dir refs/Introner-elements-main
```

## 06 Functional annotation

```bash
python3 scripts/06_annotation/parse_interproscan_tsv.py --input Arabidopsis_thaliana.interproscan.tsv --out Arabidopsis_thaliana.iprscan.xls
python3 scripts/06_annotation/parse_kofam_detail.py --input Arabidopsis_thaliana.kofam.detail.txt --out Arabidopsis_thaliana.kofam.tsv
python3 scripts/06_annotation/merge_function_annotations.py --gff Arabidopsis_thaliana.annotation.primary.gff3 --out Arabidopsis_thaliana.functional_annotation.tsv
```

## 07 Phylogeny helpers

```bash
python3 scripts/07_phylogeny/prefix_fasta_ids.py \
  --input Arabidopsis_thaliana.protein.primary.fa \
  --prefix Arabidopsis_thaliana \
  --sep '|' \
  --out Arabidopsis_thaliana.protein.primary.prefixed.fa \
  --map Arabidopsis_thaliana.species_gene_id_map.tsv
```

```bash
python3 scripts/07_phylogeny/concat_alignments.py \
  --input-dir trimmed_alignment_dir \
  --suffix .trimmed.fa \
  --species-list species.list \
  --out-fasta supermatrix.fa \
  --out-partition partition.txt \
  --out-stats occupancy.tsv
```

## 08 CAFE

```bash
python3 scripts/08_cafe/prepare_cafe_input.py --orthofinder-count Orthogroups.GeneCount.tsv --species-tree species_tree.nwk --out cafe_input.tsv
python3 scripts/08_cafe/filter_cafe_families.py --input cafe_input.tsv --max-copy 100 --min-species 2 --remove-all-zero --out cafe_input.filtered.tsv --removed cafe_input.removed.tsv
```

## 09 Synteny

```bash
python3 scripts/09_synteny/anchors_to_circos_links.py \
  --simple Arabidopsis_thaliana.Arabidopsis_lyrata.anchors.simple \
  --ref-bed Arabidopsis_thaliana.gene.bed \
  --query-bed Arabidopsis_lyrata.gene.bed \
  --out block_link.txt
```

## 10 HGT screening and validation handoff

```bash
python3 scripts/10_hgt/01_classify_hgt_hits.py \
  --hits Arabidopsis_thaliana.nr_hits.tsv \
  --taxonomy subject_taxonomy.tsv \
  --ingroup-groups Viridiplantae,Brassicaceae \
  --donor-groups Bacteria,Fungi,Metazoa \
  --exclude-groups synthetic,vector \
  --out Arabidopsis_thaliana.hgt.classified_hits.tsv \
  --summary Arabidopsis_thaliana.hgt.classified_summary.tsv
```

```bash
python3 scripts/10_hgt/02_score_hgt_candidates.py \
  --classified-hits Arabidopsis_thaliana.hgt.classified_hits.tsv \
  --out Arabidopsis_thaliana.hgt.candidates.tsv \
  --rejected Arabidopsis_thaliana.hgt.rejected.tsv \
  --summary Arabidopsis_thaliana.hgt.score_summary.tsv
```

```bash
python3 scripts/10_hgt/03_add_hgt_context.py \
  --candidates Arabidopsis_thaliana.hgt.candidates.tsv \
  --gff Arabidopsis_thaliana.annotation.primary.gff3 \
  --functional-annotation Arabidopsis_thaliana.functional_annotation.tsv \
  --intron-details Arabidopsis_thaliana.introns.details.tsv \
  --out Arabidopsis_thaliana.hgt.context.tsv \
  --bed Arabidopsis_thaliana.hgt.candidates.bed \
  --summary Arabidopsis_thaliana.hgt.context_summary.tsv
```

```bash
python3 scripts/10_hgt/04_prepare_hgt_validation.py \
  --context Arabidopsis_thaliana.hgt.context.tsv \
  --classified-hits Arabidopsis_thaliana.hgt.classified_hits.tsv \
  --outdir hgt_validation
```
