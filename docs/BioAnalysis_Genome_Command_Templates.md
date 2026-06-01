# BioAnalysis Genome Workflow Command Reference

This document provides command-line examples for each stage of the BioAnalysis genome workflow. Commands are organized in execution order and show how each method step is run from the command line.

---

## 1. 基因组组装

### hifiasm

```bash
hifiasm \
  -o Arabidopsis_thaliana.asm \
  -t 20 \
  Arabidopsis_thaliana.longread.fastq.gz
```

```bash
hifiasm \
  -o Arabidopsis_thaliana.asm \
  -t 20 \
  --ont Arabidopsis_thaliana.ont.fastq.gz
```

```bash
hifiasm \
  -o Arabidopsis_thaliana.asm \
  -t 20 \
  --n-hap 2 \
  --h1 Arabidopsis_thaliana.HiC_R1.fastq.gz \
  --h2 Arabidopsis_thaliana.HiC_R2.fastq.gz \
  --ont Arabidopsis_thaliana.ont.fastq.gz
```

```bash
awk '/^S/{print ">"$2"\n"$3}' Arabidopsis_thaliana.asm.bp.p_ctg.gfa > Arabidopsis_thaliana.primary.fa
awk '/^S/{print ">"$2"\n"$3}' Arabidopsis_thaliana.asm.bp.hap1.p_ctg.gfa > Arabidopsis_thaliana.hap1.fa
awk '/^S/{print ">"$2"\n"$3}' Arabidopsis_thaliana.asm.bp.hap2.p_ctg.gfa > Arabidopsis_thaliana.hap2.fa
```

### NextDenovo

```bash
nextDenovo Arabidopsis_thaliana.run.cfg
```

```ini
[General]
job_type = local
job_prefix = Arabidopsis_thaliana
task = all
rewrite = yes
deltmp = yes
parallel_jobs = 10
input_type = raw
read_type = ont
input_fofn = Arabidopsis_thaliana.fofn
workdir = assembly/Arabidopsis_thaliana.nextdenovo

[correct_option]
read_cutoff = 1k
genome_size = 150m
sort_options = -m 20g -t 10
minimap2_options_raw = -t 10
pa_correction = 10
correction_options = -p 10

[assemble_option]
minimap2_options_cns = -t 10
nextgraph_options = -a 1
```

### SPAdes

```bash
spades.py \
  -1 Arabidopsis_thaliana.R1.fastq.gz \
  -2 Arabidopsis_thaliana.R2.fastq.gz \
  -o Arabidopsis_thaliana.spades \
  -k 21,45,65,85 \
  --max_threads 20
```

### Canu

```bash
canu \
  -p Arabidopsis_thaliana \
  -d Arabidopsis_thaliana.canu \
  genomeSize=150m \
  -nanopore Arabidopsis_thaliana.ont.fastq.gz \
  useGrid=false \
  maxThreads=20
```

---

## 2. polish 与去冗余

### purge_dups

```bash
minimap2 \
  -x map-ont \
  -t 20 \
  Arabidopsis_thaliana.assembly.fa \
  Arabidopsis_thaliana.ont.fastq.gz \
  > Arabidopsis_thaliana.reads_to_asm.paf
```

```bash
pbcstat Arabidopsis_thaliana.reads_to_asm.paf
calcuts PB.stat > cutoffs
```

```bash
split_fa Arabidopsis_thaliana.assembly.fa > Arabidopsis_thaliana.assembly.split.fa
```

```bash
minimap2 \
  -x asm5 \
  -DP \
  -t 20 \
  Arabidopsis_thaliana.assembly.split.fa \
  Arabidopsis_thaliana.assembly.split.fa \
  > Arabidopsis_thaliana.self.paf
```

```bash
purge_dups \
  -2 \
  -T cutoffs \
  -c PB.base.cov \
  Arabidopsis_thaliana.self.paf \
  > dups.bed
```

```bash
get_seqs \
  -e \
  dups.bed \
  Arabidopsis_thaliana.assembly.fa
```

### NextPolish

```bash
nextPolish Arabidopsis_thaliana.nextpolish.cfg
```

---

## 3. Hi-C 分析与挂载

### HiC-Pro

```bash
digest_genome.py \
  -r ^GATC \
  -o Arabidopsis_thaliana.digest.bed \
  Arabidopsis_thaliana.genome.fa
```

```bash
bowtie2-build \
  Arabidopsis_thaliana.genome.fa \
  Arabidopsis_thaliana.genome
```

```bash
HiC-Pro \
  -i Arabidopsis_thaliana.hic_fastq_dir \
  -o Arabidopsis_thaliana.hicpro_result \
  -c Arabidopsis_thaliana.config-hicpro.txt
```

### chromap

```bash
chromap \
  --preset hic \
  -x Arabidopsis_thaliana.chromap.index \
  -r Arabidopsis_thaliana.genome.fa \
  -1 Arabidopsis_thaliana.HiC_R1.fastq.gz \
  -2 Arabidopsis_thaliana.HiC_R2.fastq.gz \
  -o Arabidopsis_thaliana.pairs \
  -t 20
```

### HapHiC

```bash
HapHiC pipeline \
  Arabidopsis_thaliana.assembly.fa \
  Arabidopsis_thaliana.hic.bam \
  Arabidopsis_thaliana \
  --threads 20
```

```bash
HapHiC plot Arabidopsis_thaliana
HapHiC build Arabidopsis_thaliana
```

---

## 4. 组装评估

### BUSCO

```bash
busco \
  -i Arabidopsis_thaliana.genome.fa \
  -o Arabidopsis_thaliana.busco_genome \
  -l embryophyta_odb10 \
  -m geno \
  --offline \
  -c 20
```

```bash
busco \
  -i Arabidopsis_thaliana.protein.fa \
  -o Arabidopsis_thaliana.busco_protein \
  -l embryophyta_odb10 \
  -m prot \
  --offline \
  -c 20
```

### compleasm

```bash
compleasm.py run \
  -a Arabidopsis_thaliana.genome.fa \
  -l embryophyta_odb10 \
  -o Arabidopsis_thaliana.compleasm_genome \
  -L busco_lineage_dir \
  -t 20
```

```bash
compleasm.py protein \
  -p Arabidopsis_thaliana.protein.fa \
  -l embryophyta_odb10 \
  -o Arabidopsis_thaliana.compleasm_protein \
  -L busco_lineage_dir \
  -t 20
```

### Merqury / meryl

```bash
best_k.sh 150000000
```

```bash
meryl count \
  k=21 \
  threads=20 \
  output Arabidopsis_thaliana.reads.meryl \
  Arabidopsis_thaliana.R1.fastq.gz Arabidopsis_thaliana.R2.fastq.gz
```

```bash
meryl count \
  k=21 \
  threads=20 \
  output Arabidopsis_thaliana.assembly.meryl \
  Arabidopsis_thaliana.genome.fa
```

```bash
meryl histogram \
  Arabidopsis_thaliana.reads.meryl \
  > Arabidopsis_thaliana.reads.hist
```

```bash
merqury.sh \
  Arabidopsis_thaliana.reads.meryl \
  Arabidopsis_thaliana.genome.fa \
  Arabidopsis_thaliana.merqury
```

### LAI 完整流程

```bash
LTR_FINDER_parallel \
  -seq Arabidopsis_thaliana.genome.fa \
  -threads 12 \
  -harvest_out \
  -size 1000000 \
  -time 300
```

```bash
gt suffixerator \
  -db Arabidopsis_thaliana.genome.fa \
  -indexname Arabidopsis_thaliana \
  -tis -suf -lcp -des -ssp -sds -dna
```

```bash
gt ltrharvest \
  -index Arabidopsis_thaliana \
  -similar 85 \
  -vic 10 \
  -seed 20 \
  -seqids yes \
  -minlenltr 100 \
  -maxlenltr 7000 \
  -mintsd 4 \
  -maxtsd 6 \
  > Arabidopsis_thaliana.harvest.scn
```

```bash
cat \
  Arabidopsis_thaliana.genome.fa.finder.combine.scn \
  Arabidopsis_thaliana.harvest.scn \
  > Arabidopsis_thaliana.raw_ltr.scn
```

```bash
LTR_retriever \
  -genome Arabidopsis_thaliana.genome.fa \
  -inharvest Arabidopsis_thaliana.raw_ltr.scn \
  -threads 12
```

```bash
RepeatMasker \
  -nolow \
  -no_is \
  -norna \
  -engine ncbi \
  -parallel 20 \
  -lib Arabidopsis_thaliana.genome.fa.LTRlib.fa \
  Arabidopsis_thaliana.genome.fa
```

```bash
LAI \
  -genome Arabidopsis_thaliana.genome.fa \
  -intact Arabidopsis_thaliana.genome.fa.pass.list \
  -all Arabidopsis_thaliana.genome.fa.out \
  -t 20
```

---

## 5. 重复注释

### genome 转大写

```bash
seqkit seq \
  -s \
  Arabidopsis_thaliana.genome.fa \
  | grep -q '[a-z]' && echo "lowercase_found" || echo "all_uppercase"
```

```bash
seqkit seq \
  -u \
  Arabidopsis_thaliana.genome.fa \
  > Arabidopsis_thaliana.genome.upper.fa
```

```bash
ln -s Arabidopsis_thaliana.genome.upper.fa genome.fa
```

### LTR_FINDER_parallel

```bash
bash scripts/repeat/LTR_Finder.sh \
  --genome genome.fa \
  --threads 30 \
  --size 1000000 \
  --time 300
```

### LTRharvest

```bash
bash scripts/repeat/LTR_harvest.sh \
  --genome genome.fa \
  --index-prefix genome.fa \
  --out genome.fa.harvest.scn
```

### RepeatModeler，与 LTR 流程并行

```bash
bash scripts/repeat/repeatmodeler.sh \
  --genome genome.fa \
  --database mydb \
  --threads 20 \
  --log repeatmodeler.log \
  --out run.out
```

### LTR_retriever，等待 LTR_FINDER_parallel 和 LTRharvest 完成后运行

```bash
bash scripts/repeat/work.sh \
  --genome genome.fa \
  --harvest genome.fa.harvest.scn \
  --finder genome.fa.finder.combine.scn \
  --threads 12 \
  --raw-ltr genome.fa.rawLTR.scn
```

### 合并 known / unknown repeat library

```bash
cat \
  curated_repeat_library.fa \
  taxon_known_repeat_library.fa \
  ltr_finder/genome.fa.LTRlib.fa \
  repeatmodeler/mydb-known.families.fa \
  > known.library
```

```bash
ln -s repeatmodeler/mydb-unknown.families.fa unknown.library
```

### RepeatMasker 注释

```bash
mkdir -p known unknown
```

```bash
RepeatMasker \
  -lib known.library \
  -pa 30 \
  genome.fa \
  -dir known
```

```bash
RepeatMasker \
  -lib unknown.library \
  -pa 30 \
  genome.fa \
  -dir unknown
```

### RepeatMasker 输出合并

```bash
awk 'FNR <= 3 && NR > 3 {next} {print}' \
  known/genome.fa.out \
  unknown/genome.fa.out \
  > Arabidopsis_thaliana.repeatmasker.all.out
```

### RepeatMasker .out 转 GFF3

```bash
bash rmout2gff.sh \
  Arabidopsis_thaliana.repeatmasker.all.out \
  > Arabidopsis_thaliana.repeatmasker.all.gff3
```

### repeat 分类统计

```bash
bash repeat_stat.sh \
  Arabidopsis_thaliana.repeatmasker.all.out \
  150000000 \
  > Arabidopsis_thaliana.repeat.summary.txt
```

### TRF，可选

```bash
bash scripts/repeat/trf.sh \
  --genome genome.fa \
  --out-prefix Arabidopsis_thaliana.trf \
  --trf-args "2 5 7 80 10 50 2000" \
  --gff Arabidopsis_thaliana.trf.gff3
```

### repeat density

```bash
samtools faidx genome.fa
```

```bash
bedtools makewindows \
  -g genome.fa.fai \
  -w 100000 \
  > Arabidopsis_thaliana.100kb.windows.bed
```

```bash
bedtools coverage \
  -a Arabidopsis_thaliana.100kb.windows.bed \
  -b Arabidopsis_thaliana.repeatmasker.all.gff3 \
  > Arabidopsis_thaliana.repeat_density.tsv
```

---

## 6. 基因结构注释与 GFF/CDS/PEP 整理

### BRAKER3

```bash
braker.pl \
  --genome=Arabidopsis_thaliana.softmasked.genome.fa \
  --prot_seq=Arabidopsis_lyrata.reference_proteins.fa \
  --rnaseq_sets_ids=Arabidopsis_thaliana_RNAseq \
  --rnaseq_sets_dirs=Arabidopsis_thaliana.rnaseq_dir \
  --species=Arabidopsis_thaliana \
  --workingdir=Arabidopsis_thaliana.braker3 \
  --gff3 \
  --AUGUSTUS_CONFIG_PATH=augustus_config \
  --threads 10 \
  --busco_lineage embryophyta_odb10
```

```bash
braker.pl \
  --genome=Arabidopsis_thaliana.softmasked.genome.fa \
  --prot_seq=Arabidopsis_lyrata.reference_proteins.fa \
  --species=Arabidopsis_thaliana \
  --workingdir=Arabidopsis_thaliana.braker3 \
  --gff3 \
  --AUGUSTUS_CONFIG_PATH=augustus_config \
  --threads 10 \
  --busco_lineage embryophyta_odb10
```

### GTF 转 GFF3

```bash
gtf2gff.pl \
  --gff3 \
  Arabidopsis_thaliana.annotation.gtf \
  > Arabidopsis_thaliana.annotation.gff3
```

### gff-cds-pep manifest

```text
species_id	species_name	genome_fasta	annotation_gff	keep_ids
Ath	Arabidopsis_thaliana	Arabidopsis_thaliana.genome.fa	Arabidopsis_thaliana.annotation.gff3	Arabidopsis_thaliana.keep_ids.txt
Aly	Arabidopsis_lyrata	Arabidopsis_lyrata.genome.fa	Arabidopsis_lyrata.annotation.gff3	NA
```

### gff_cds_pep.py

```bash
python3 gff_cds_pep.py \
  --manifest manifest.tsv \
  --outdir gff_cds_pep_outputs
```

```bash
python3 gff_cds_pep.py \
  --manifest manifest.tsv \
  --outdir gff_cds_pep_outputs \
  --keep-bad-cds
```

```bash
python3 gff_cds_pep.py \
  --manifest manifest.tsv \
  --outdir gff_cds_pep_outputs \
  --transcript-regex 't1|\\.1$'
```

### 输出整理为下游输入

```bash
cp gff_cds_pep_outputs/Ath/hic/Ath.hic.pep Arabidopsis_thaliana.protein.primary.fa
cp gff_cds_pep_outputs/Ath/hic/Ath.hic.cds Arabidopsis_thaliana.cds.primary.fa
cp gff_cds_pep_outputs/Ath/hic/Ath.hic.gff Arabidopsis_thaliana.annotation.primary.gff3
```

```bash
mkdir -p protein_dir
cp Arabidopsis_thaliana.protein.primary.fa protein_dir/Arabidopsis_thaliana.fa
cp Arabidopsis_lyrata.protein.primary.fa protein_dir/Arabidopsis_lyrata.fa
```

### gffread 对照

```bash
gffread \
  Arabidopsis_thaliana.annotation.gff3 \
  -g Arabidopsis_thaliana.genome.fa \
  -x Arabidopsis_thaliana.gffread.cds.fa \
  -y Arabidopsis_thaliana.gffread.pep.fa
```

### protein BUSCO / compleasm

```bash
busco \
  -i Arabidopsis_thaliana.protein.primary.fa \
  -o Arabidopsis_thaliana.busco_protein_primary \
  -l embryophyta_odb10 \
  -m prot \
  --offline \
  -c 20
```

```bash
compleasm.py protein \
  -p Arabidopsis_thaliana.protein.primary.fa \
  -l embryophyta_odb10 \
  -o Arabidopsis_thaliana.compleasm_protein_primary \
  -L busco_lineage_dir \
  -t 20
```

---

## 7. 功能注释

### InterProScan

```bash
interproscan.sh \
  -i Arabidopsis_thaliana.protein.primary.fa \
  -o Arabidopsis_thaliana.interproscan.tsv \
  -f tsv \
  -goterms \
  -dp \
  -cpu 10 \
  -T temp_dir
```

```bash
python parse_interproscan_tsv.py \
  --input Arabidopsis_thaliana.interproscan.tsv \
  --out Arabidopsis_thaliana.iprscan.xls
```

```bash
awk -F '\t' 'NR==1 || $3=="Pfam"' \
  Arabidopsis_thaliana.iprscan.xls \
  > Arabidopsis_thaliana.pfam.tsv
```

### eggNOG-mapper

```bash
emapper.py \
  -i Arabidopsis_thaliana.protein.primary.fa \
  -o Arabidopsis_thaliana.eggnog \
  -d euk \
  --cpu 30 \
  --dbmem
```

```bash
grep -v '^##' \
  Arabidopsis_thaliana.eggnog.emapper.annotations \
  > Arabidopsis_thaliana.eggnog.annotations.tsv
```

### KofamScan

```bash
exec_annotation \
  -f detail \
  -o Arabidopsis_thaliana.kofam.detail.txt \
  Arabidopsis_thaliana.protein.primary.fa
```

```bash
awk '$1=="*" || NR==1' \
  Arabidopsis_thaliana.kofam.detail.txt \
  > Arabidopsis_thaliana.kofam.filtered.txt
```

```bash
python parse_kofam_detail.py \
  --input Arabidopsis_thaliana.kofam.detail.txt \
  --out Arabidopsis_thaliana.kofam.tsv
```

### DIAMOND SwissProt / NR

```bash
diamond blastp \
  --db swissprot.dmnd \
  --query Arabidopsis_thaliana.protein.primary.fa \
  --out Arabidopsis_thaliana.swissprot.diamond.tsv \
  --threads 10 \
  --evalue 1e-5 \
  --max-target-seqs 5 \
  --max-hsps 1 \
  --outfmt 6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore stitle \
  --ultra-sensitive
```

```bash
sort -k1,1 -k12,12gr \
  Arabidopsis_thaliana.swissprot.diamond.tsv \
  | awk '!seen[$1]++' \
  > Arabidopsis_thaliana.swissprot.besthit.tsv
```

```bash
diamond blastp \
  --db nr.dmnd \
  --query Arabidopsis_thaliana.protein.primary.fa \
  --out Arabidopsis_thaliana.nr.diamond.tsv \
  --threads 20 \
  --evalue 1e-5 \
  --max-target-seqs 5 \
  --max-hsps 1 \
  --outfmt 6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore stitle \
  --ultra-sensitive
```

### BLASTP，可选

```bash
blastp \
  -query Arabidopsis_thaliana.protein.primary.fa \
  -db swissprot \
  -out Arabidopsis_thaliana.swissprot.blastp.tsv \
  -evalue 1e-5 \
  -outfmt 6 \
  -max_target_seqs 7 \
  -num_threads 20
```

```bash
sort -k1,1 -k12,12gr \
  Arabidopsis_thaliana.swissprot.blastp.tsv \
  | awk '!seen[$1]++' \
  > Arabidopsis_thaliana.swissprot.blastp.besthit.tsv
```

### 合并功能注释总表

```bash
python merge_function_annotations.py \
  --gff Arabidopsis_thaliana.annotation.primary.gff3 \
  --cds-check gff_cds_pep_outputs/Ath/hic/Ath.hic.cds.check \
  --iprscan Arabidopsis_thaliana.iprscan.xls \
  --eggnog Arabidopsis_thaliana.eggnog.annotations.tsv \
  --kofam Arabidopsis_thaliana.kofam.tsv \
  --swissprot Arabidopsis_thaliana.swissprot.besthit.tsv \
  --out Arabidopsis_thaliana.functional_annotation.tsv
```

---

## 8. 基因家族和系统发育

### OrthoFinder

```bash
orthofinder \
  -f protein_dir \
  -t 32 \
  -a 32
```

```bash
orthofinder \
  -f protein_dir \
  -t 60 \
  -a 60
```

```bash
orthofinder \
  -b WorkingDirectory \
  -t 32 \
  -a 32
```

### MAFFT

```bash
mafft \
  --maxiterate 1000 \
  --localpair \
  --thread 2 \
  --anysymbol \
  OG0000001.fa \
  > OG0000001.MSA.fa
```

### seqkit

```bash
seqkit seq \
  -w 0 \
  OG0000001.MSA.fa \
  > OG0000001.MSA.link.fa
```

### trimAl

```bash
trimal \
  -in OG0000001.MSA.fa \
  -out OG0000001.trimmed.fa \
  -automated1
```

```bash
trimal \
  -in OG0000001.MSA.fa \
  -out OG0000001.trimmed.fa \
  -gt 0.5
```

### AMAS

```bash
AMAS.py concat \
  -i trimmed_alignment_dir/*.fa \
  -f fasta \
  -d aa \
  -t supermatrix.fa \
  -p partition.txt \
  -u phylip
```

### RAxML

```bash
raxmlHPC-PTHREADS-SSE3 \
  -T 60 \
  -f a \
  -# 500 \
  -m PROTCATGTR \
  -p 12345 \
  -x 12345 \
  -n Arabidopsis_tree.PROTCATGTR \
  -s supermatrix.phy
```

```bash
raxmlHPC-PTHREADS-SSE3 \
  -T 60 \
  -f a \
  -# 500 \
  -m PROTGAMMAAUTO \
  -p 12345 \
  -x 12345 \
  -n Arabidopsis_tree.PROTGAMMAAUTO \
  -s supermatrix.phy
```

### IQ-TREE

```bash
iqtree2 \
  -s supermatrix.fa \
  -m MFP \
  -bb 2000 \
  -T 20
```

```bash
iqtree2 \
  -s supermatrix.fa \
  -m MFP \
  -b 500 \
  -T 20
```

### 单基因 / 基因家族树

#### 功能注释驱动：目标功能基因 + 外群 + marker/MAKER 基因

```bash
python select_genes_by_function.py \
  --annotation Arabidopsis_thaliana.functional_annotation.tsv \
  --pfam PF00001,PF00002 \
  --out Arabidopsis_thaliana.target_function.ids
```

```bash
python select_genes_by_function.py \
  --annotation Arabidopsis_thaliana.functional_annotation.tsv \
  --ko K00001,K00002 \
  --out Arabidopsis_thaliana.target_function.ids
```

```bash
python select_genes_by_function.py \
  --annotation Arabidopsis_thaliana.functional_annotation.tsv \
  --keyword "methyltransferase" \
  --out Arabidopsis_thaliana.target_function.ids
```

```bash
seqkit grep \
  -f Arabidopsis_thaliana.target_function.ids \
  Arabidopsis_thaliana.protein.primary.fa \
  > gene_tree/function_tree/Arabidopsis_thaliana.target_function.pep.fa
```

```bash
diamond makedb \
  --in outgroup.protein.fa \
  --db outgroup.protein
```

```bash
diamond blastp \
  --query gene_tree/function_tree/Arabidopsis_thaliana.target_function.pep.fa \
  --db outgroup.protein \
  --out gene_tree/function_tree/target_vs_outgroup.diamond.tsv \
  --threads 20 \
  --evalue 1e-5 \
  --max-target-seqs 10 \
  --outfmt 6
```

```bash
python select_blast_hits.py \
  --blast gene_tree/function_tree/target_vs_outgroup.diamond.tsv \
  --mode top_per_query \
  --top 5 \
  --out gene_tree/function_tree/outgroup_target_gene.ids
```

```bash
seqkit grep \
  -f gene_tree/function_tree/outgroup_target_gene.ids \
  outgroup.protein.fa \
  > gene_tree/function_tree/outgroup.target_function.pep.fa
```

```bash
seqkit seq \
  -w 0 \
  marker_or_maker_genes.pep.fa \
  > gene_tree/function_tree/marker_or_maker_genes.clean.pep.fa
```

```bash
cat \
  gene_tree/function_tree/Arabidopsis_thaliana.target_function.pep.fa \
  gene_tree/function_tree/outgroup.target_function.pep.fa \
  gene_tree/function_tree/marker_or_maker_genes.clean.pep.fa \
  > gene_tree/function_tree/target_function.with_outgroup_marker.pep.fa
```

```bash
seqkit rmdup \
  -n \
  gene_tree/function_tree/target_function.with_outgroup_marker.pep.fa \
  > gene_tree/function_tree/target_function.with_outgroup_marker.nr.pep.fa
```

```bash
python build_function_tree_tip_table.py \
  --target-ids Arabidopsis_thaliana.target_function.ids \
  --outgroup-ids gene_tree/function_tree/outgroup_target_gene.ids \
  --marker-fasta gene_tree/function_tree/marker_or_maker_genes.clean.pep.fa \
  --functional-annotation Arabidopsis_thaliana.functional_annotation.tsv \
  --out gene_tree/function_tree/target_function.tip_annotation.tsv
```

```bash
mafft \
  --maxiterate 1000 \
  --localpair \
  --thread 4 \
  --anysymbol \
  gene_tree/function_tree/target_function.with_outgroup_marker.nr.pep.fa \
  > gene_tree/function_tree/target_function.aln.fa
```

```bash
trimal \
  -in gene_tree/function_tree/target_function.aln.fa \
  -out gene_tree/function_tree/target_function.trimmed.fa \
  -automated1
```

```bash
iqtree2 \
  -s gene_tree/function_tree/target_function.trimmed.fa \
  -m MFP \
  -bb 1000 \
  -alrt 1000 \
  -T 4 \
  --prefix gene_tree/function_tree/target_function
```

```bash
python rename_tree_tips.py \
  --tree gene_tree/function_tree/target_function.treefile \
  --tip-annotation gene_tree/function_tree/target_function.tip_annotation.tsv \
  --out gene_tree/function_tree/target_function.renamed.tree
```

#### Orthogroup 驱动：从 OrthoFinder 家族建树

```bash
python prefix_fasta_ids.py \
  --input Arabidopsis_thaliana.protein.primary.fa \
  --prefix Arabidopsis_thaliana \
  --sep '|' \
  --out Arabidopsis_thaliana.protein.primary.prefixed.fa \
  --map Arabidopsis_thaliana.species_gene_id_map.tsv
```

```bash
cat \
  Arabidopsis_thaliana.protein.primary.prefixed.fa \
  Arabidopsis_lyrata.protein.primary.prefixed.fa \
  Arabidopsis_halleri.protein.primary.prefixed.fa \
  Arabidopsis_suecica.protein.primary.prefixed.fa \
  > all_species.protein.primary.prefixed.fa
```

```bash
python extract_orthogroup_members.py \
  --orthogroups Orthogroups.tsv \
  --target-list target_orthogroups.list \
  --id-map species_gene_id_map.tsv \
  --outdir gene_tree/01_member_lists
```

```bash
for ids in gene_tree/01_member_lists/*.ids
do
  og=$(basename "$ids" .ids)
  seqkit grep \
    -f "$ids" \
    all_species.protein.primary.prefixed.fa \
    > gene_tree/02_family_fasta/${og}.pep.fa
done
```

```bash
for fa in gene_tree/02_family_fasta/*.pep.fa
do
  og=$(basename "$fa" .pep.fa)
  python clean_pep_for_tree.py \
    --input "$fa" \
    --remove-terminal-stop \
    --out gene_tree/02_family_fasta/${og}.clean.pep.fa
done
```

```bash
for fa in gene_tree/02_family_fasta/*.clean.pep.fa
do
  og=$(basename "$fa" .clean.pep.fa)
  mafft \
    --maxiterate 1000 \
    --localpair \
    --thread 2 \
    --anysymbol \
    "$fa" \
    > gene_tree/03_alignment/${og}.aln.fa
done
```

```bash
for aln in gene_tree/03_alignment/*.aln.fa
do
  og=$(basename "$aln" .aln.fa)
  seqkit seq -w 0 "$aln" > gene_tree/03_alignment/${og}.aln.link.fa
  trimal \
    -in gene_tree/03_alignment/${og}.aln.link.fa \
    -out gene_tree/04_trimmed/${og}.trimmed.fa \
    -automated1
done
```

```bash
mkdir -p gene_tree/05_tree gene_tree/06_failed

for aln in gene_tree/04_trimmed/*.trimmed.fa
do
  og=$(basename "$aln" .trimmed.fa)
  nseq=$(grep -c '^>' "$aln")
  if [ "$nseq" -lt 3 ]; then
    echo -e "$og\ttoo_few_sequences\t$nseq" >> gene_tree/06_failed/failed.tsv
    continue
  fi
  iqtree2 \
    -s "$aln" \
    -m MFP \
    -bb 1000 \
    -alrt 1000 \
    -T 4 \
    --prefix gene_tree/05_tree/${og}
done
```

```bash
find gene_tree/05_tree \
  -name "*.treefile" \
  | sort \
  > gene_tree/gene_tree.list
```

```bash
python make_tree_tip_annotation.py \
  --functional-annotation Arabidopsis_thaliana.functional_annotation.tsv \
  --id-map species_gene_id_map.tsv \
  --out gene_tree/tree_tip_annotation.tsv
```

```bash
python rename_tree_tips.py \
  --tree gene_tree/05_tree/OG0000001.treefile \
  --tip-annotation gene_tree/tree_tip_annotation.tsv \
  --out gene_tree/07_renamed_tree/OG0000001.renamed.tree
```

```bash
python summarize_gene_trees.py \
  --orthogroups Orthogroups.tsv \
  --gene-tree-list gene_tree/gene_tree.list \
  --alignment-dir gene_tree/04_trimmed \
  --iqtree-dir gene_tree/05_tree \
  --functional-annotation-dir functional_annotation_dir \
  --failed gene_tree/06_failed/failed.tsv \
  --out gene_tree/gene_tree_summary.tsv
```

### CAFE5

```bash
python prepare_cafe_input.py \
  --orthofinder-count Orthogroups.GeneCount.tsv \
  --species-tree species_tree.nwk \
  --out cafe_input.tsv
```

```bash
python filter_cafe_families.py \
  --input cafe_input.tsv \
  --max-copy 100 \
  --min-species 2 \
  --remove-all-zero \
  --out cafe_input.filtered.tsv \
  --removed cafe_input.removed.tsv
```

```bash
cafe5 \
  -i cafe_input.filtered.tsv \
  -t ultrametric_tree.nwk \
  -o cafe_result \
  -k 3 \
  -p 0.05
```

---

## 9. 共线性和 Circos

### minimap2 + dotPlotly

```bash
minimap2 \
  -x asm20 \
  -t 20 \
  Arabidopsis_thaliana.genome.fa \
  Arabidopsis_lyrata.genome.fa \
  > Arabidopsis_thaliana_vs_Arabidopsis_lyrata.paf
```

```bash
Rscript pafCoordsDotPlotly.R \
  -i Arabidopsis_thaliana_vs_Arabidopsis_lyrata.paf \
  -o Arabidopsis_thaliana_vs_Arabidopsis_lyrata.dotplot \
  -s \
  -t \
  -m 5000 \
  -q 5000 \
  -l
```

### WGDI

```bash
awk '$3=="gene" {print $1"\t"$4"\t"$5"\t"$9}' Arabidopsis_thaliana.annotation.gff3 > Arabidopsis_thaliana.wgdi.gff
```

```ini
[dotplot]
blast = Arabidopsis_thaliana_vs_Arabidopsis_lyrata.blastp.tsv
gff1 = Arabidopsis_thaliana.wgdi.gff
gff2 = Arabidopsis_lyrata.wgdi.gff
lens1 = Arabidopsis_thaliana.lens
lens2 = Arabidopsis_lyrata.lens
genome1_name = Arabidopsis_thaliana
genome2_name = Arabidopsis_lyrata
multiple = 1
score = 100
evalue = 1e-5
repeat_number = 5
position = order
markersize = 0.5
figsize = 10,10
savefig = Arabidopsis_thaliana_vs_Arabidopsis_lyrata.wgdi.dotplot.pdf
```

```bash
wgdi \
  -d Arabidopsis_thaliana_vs_Arabidopsis_lyrata.conf
```

### MCScanX

```bash
blastp \
  -query Arabidopsis_all.protein.fa \
  -db Arabidopsis_all.protein.db \
  -out Arabidopsis_all.blast \
  -evalue 1e-5 \
  -outfmt 6 \
  -num_alignments 5 \
  -num_threads 20
```

```bash
awk '$3=="gene" {split($9,a,";"); print $1"\t"a[1]"\t"$4"\t"$5}' Arabidopsis_all.annotation.gff3 > Arabidopsis_all.gff
```

```bash
MCScanX Arabidopsis_all
```

### JCVI

```bash
python3 -m jcvi.compara.catalog ortholog \
  Arabidopsis_thaliana \
  Arabidopsis_lyrata \
  --cscore=.99
```

```bash
python3 -m jcvi.compara.synteny screen \
  --minspan=30 \
  --simple \
  Arabidopsis_thaliana.Arabidopsis_lyrata.anchors \
  Arabidopsis_thaliana.Arabidopsis_lyrata.anchors.simple
```

### Circos

```bash
samtools faidx Arabidopsis_thaliana.genome.fa
```

```bash
awk '{print "chr - "$1" "$1" 0 "$2" Arabidopsis_thaliana"}' Arabidopsis_thaliana.genome.fa.fai > genome_karyotype.txt
```

```bash
bedtools makewindows \
  -g Arabidopsis_thaliana.genome.fa.fai \
  -w 100000 \
  > Arabidopsis_thaliana.windows.bed
```

```bash
bedtools nuc \
  -fi Arabidopsis_thaliana.genome.fa \
  -bed Arabidopsis_thaliana.windows.bed \
  > Arabidopsis_thaliana.gc.raw.tsv
```

```bash
awk 'NR>1 {print $1"\t"$2"\t"$3"\t"$5}' Arabidopsis_thaliana.gc.raw.tsv > Arabidopsis_thaliana.gc.circos.txt
```

```bash
bedtools coverage \
  -a Arabidopsis_thaliana.windows.bed \
  -b Arabidopsis_thaliana.repeat.gff \
  > Arabidopsis_thaliana.repeat_density.raw.tsv
```

```bash
circos \
  -conf circos.conf
```

---

## 10. Pfam / domain 统计

```python
import pandas as pd

files = {
    "Arabidopsis_thaliana": "Arabidopsis_thaliana.iprscan.xls",
    "Arabidopsis_lyrata": "Arabidopsis_lyrata.iprscan.xls",
    "Arabidopsis_halleri": "Arabidopsis_halleri.iprscan.xls",
    "Arabidopsis_suecica": "Arabidopsis_suecica.iprscan.xls",
}

all_counts = []
status_rows = []
descriptions = {}

for species, file in files.items():
    df = pd.read_csv(file, sep="\t")
    pfam = df[df["Subject_DB"] == "Pfam"].copy()
    count = pfam.groupby("Subject_id").size().rename(species)
    all_counts.append(count)
    status_rows.append({
        "species": species,
        "iprscan_file": file,
        "pfam_rows": len(pfam),
    })
    for _, row in pfam.iterrows():
        pfam_id = row["Subject_id"]
        desc = row.get("Subject_annotation", "")
        if pfam_id not in descriptions:
            descriptions[pfam_id] = desc

matrix = pd.concat(all_counts, axis=1).fillna(0).astype(int)
status_df = pd.DataFrame(status_rows)
desc_df = pd.DataFrame([
    {"Pfam": k, "Description": v}
    for k, v in descriptions.items()
])

with pd.ExcelWriter("Arabidopsis_pfam_count.xlsx") as writer:
    matrix.to_excel(writer, sheet_name="pfam_count")
    status_df.to_excel(writer, sheet_name="input_status", index=False)
    desc_df.to_excel(writer, sheet_name="pfam_description", index=False)
```
