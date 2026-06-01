# BioAnalysis Genome Workflow

This document describes the BioAnalysis genome workflow as a methods pipeline. It focuses on software choices, execution order, key parameters, expected outputs, quality-control checkpoints and handoffs between workflow steps.

---

## 1. 总体流程

```text
原始测序数据质控
  ↓
长读长 / 混合基因组组装
  ↓
组装 polish、去冗余与污染检查
  ↓
Hi-C 辅助挂载与染色体级组装
  ↓
组装质量评估：连续性、完整性、k-mer、LTR Assembly Index
  ↓
重复序列注释：de novo repeat、LTR、RepeatMasker
  ↓
基因结构注释：BRAKER / AUGUSTUS / GeneMark 等
  ↓
功能注释：InterProScan、eggNOG、KEGG、SwissProt、NR
  ↓
基因家族聚类：OrthoFinder
  ↓
单拷贝基因提取、比对、修剪、串联
  ↓
系统发育树构建：RAxML / IQ-TREE / MrBayes
  ↓
基因家族扩张收缩：CAFE 或等价方法
  ↓
共线性与基因组结构分析：minimap2、WGDI、MCScanX、JCVI
  ↓
Circos 与宏观结构可视化
  ↓
Pfam / domain 统计与比较
  ↓
异常染色体或特殊区域证据表整合
```

---

## 2. 输出到下一步输入衔接总表

本节用于检查每一步“产生什么输出、如何处理、变成下一步什么输入”。执行项目时，每一步结束后都应先完成本表对应的后处理和检查，再进入下一步。

| 流程步骤 | 本步主要输出 | 输出后必须做的处理 | 下一步输入 | 进入下一步前检查 |
|---|---|---|---|---|
| 原始数据整理 | 标准化 reads、样本信息表、文件清单 | 统一命名；记录数据类型；检查空文件；统计 reads 数和碱基量 | 组装软件输入 reads；Hi-C/RNA-seq 证据输入 | 样本名唯一；文件非空；read 类型清楚 |
| hifiasm / NextDenovo / Canu / SPAdes 组装 | GFA、contig FASTA、primary/hap FASTA | GFA 转 FASTA；统一命名为 `Arabidopsis_thaliana.assembly.fa`；统计长度/N50；去除明显临时文件干扰 | polish、purge_dups、Hi-C 挂载、组装评估 | assembly size 接近预期；FASTA header 唯一；无空序列 |
| purge_dups 去冗余 | `dups.bed`、purged FASTA、haplotig FASTA | 选择 purged primary assembly 作为代表基因组；重命名为 `Arabidopsis_thaliana.purged.fa`；记录去除长度和比例 | polish、Hi-C 挂载、BUSCO/Merqury | 去冗余后总长不过度下降；BUSCO duplicated 不异常 |
| NextPolish / polish | polished FASTA | 对 polished FASTA 重新建 index；重命名为当前基因组版本；记录 polish 轮次 | Hi-C 挂载、评估、重复注释 | QV/BUSCO 不下降；版本号清楚 |
| Hi-C 处理 | HiC-Pro/chromap 比对结果、pairs/BAM、heatmap | 将 Hi-C BAM/pairs 与当前 assembly 匹配；检查比对率和 contact map | HapHiC/3D scaffolding、人工检查 | Hi-C 数据对应同一 assembly 版本 |
| Hi-C 挂载 | chromosome-level FASTA、agp、未挂载 scaffold、heatmap | 根据 heatmap 检查错拼；确认染色体编号；输出最终 genome FASTA | 组装质量评估、重复注释、基因注释 | 染色体数合理；坐标版本固定 |
| 组装连续性统计 | seqkit/assembly stats 表 | 将总长、N50、L50、contig/scaffold 数写入 QC 表 | 组装版本选择 | 统计来自最终 FASTA |
| BUSCO/compleasm genome | genome 完整性报告 | 抽取 C/S/D/F/M 比例；和预期类群比较 | 组装版本选择；是否继续注释 | lineage 正确；duplicated 可解释 |
| Merqury/meryl | QV、completeness、spectra-cn | 整理 QV 和 k-mer completeness；判断是否需要重新 polish/去冗余 | 最终 genome 确认 | reads 与 assembly 样本一致 |
| LAI | LAI 分值、LTR 相关结果 | 确认 `pass.list`、`.out` 和 LAI 来自同一 genome | 组装质量综合评价 | 不把 LTR 识别失败误判为组装差 |
| 重复注释前处理 | 大写 genome.fa | 用 `seqkit seq -u` 转大写；统一链接为 `genome.fa` | LTR_FINDER、LTRharvest、RepeatModeler、RepeatMasker | 序列全大写；ID 保持原样 |
| LTR_FINDER_parallel | `genome.fa.finder.combine.scn` | 检查 scn 非空；保留日志 | LTR_retriever | 与 LTRharvest 使用同一 genome.fa |
| LTRharvest | `genome.fa.harvest.scn` | 检查 scn 非空；与 finder 结果准备合并 | LTR_retriever | index 与 genome.fa 一致 |
| RepeatModeler | repeat family library，如 known/unknown/classified | 确认 BuildDatabase 和 RepeatModeler 完成；识别实际输出文件名 | RepeatMasker library 合并 | families 文件非空 |
| LTR_retriever | `genome.fa.LTRlib.fa`、`pass.list`、`genome.fa.out` | 将 LTR library 加入 known.library；`pass.list` 和 `.out` 留给 LAI | RepeatMasker library、LAI | rawLTR.scn 非空；LTRlib 非空 |
| RepeatMasker | known/unknown `.out`、`.masked` | 合并 `.out`；转 GFF3；统计分类比例；准备 soft-masked genome | 基因结构注释、Circos repeat track、special chromosome evidence | `.out`、`.gff3`、summary 都存在 |
| 基因结构注释 | BRAKER/AUGUSTUS/GeneMark GFF/GTF | 若为 GTF 先转 GFF3；检查 transcript/CDS feature 和 ID/Parent | gff-cds-pep | GFF seqid 存在于 genome FASTA |
| gff-cds-pep | clean GFF、CDS、PEP、raw/final CDS check、summary | 默认过滤非 3 倍数 CDS 和 internal stop；复制为 `protein.primary.fa`、`cds.primary.fa`、`annotation.primary.gff3` | 功能注释、OrthoFinder、共线性、Circos | final check 中 `phase_ok=0` 和 `internal_stop>0` 应为 0 |
| protein BUSCO/compleasm | protein 完整性报告 | 记录 protein-level BUSCO；判断基因注释质量 | 功能注释和比较基因组 | protein primary 数量合理 |
| InterProScan | `.interproscan.tsv` | 解析为 `.iprscan.xls`；筛选 Pfam；整理 GO/InterPro | Pfam/domain 统计、功能总表 | Query_id 对应 protein.primary.fa |
| eggNOG | `.emapper.annotations` 等 | 去除 `##` 注释行；提取 COG/GO/KO/description | 功能总表 | 注释率合理；字段完整 |
| KofamScan | `kofam.detail.txt` | 过滤通过阈值的 KO；解析为 `kofam.tsv` | 功能总表、KEGG 解释 | 保留 score/threshold |
| DIAMOND/BLASTP | SwissProt/NR hits | 按 query 取 best hit；保留 description | 功能总表 | bitscore 列与排序列一致 |
| 功能注释合并 | `functional_annotation.tsv` | 合并 GFF 坐标、CDS check、Pfam、GO、KO、SwissProt/NR；未注释基因保留 NA | domain 统计、扩张收缩解释、特殊染色体证据、图表 | transcript_id 与 protein/GFF 一致 |
| OrthoFinder | Orthogroups、GeneCount、单拷贝列表、基因树/物种树可选输出 | 提取 `Orthogroups.tsv`、`GeneCount.tsv`、single-copy 序列；整理每个 orthogroup 的成员 | 系统树、基因树、CAFE、扩张收缩 | species 列名与 protein 文件名一致 |
| 单拷贝基因选择 | 选定 orthogroup ID 列表 | 按目标数量筛选；复制每个 OG 的 FASTA | MAFFT 比对 | 每个 OG 每物种一条序列 |
| 单拷贝 MAFFT 比对 | per-gene `.MSA.fa` | 去换行；修剪低质量列；剔除过短/缺失严重基因 | supermatrix 串联 | 每个 alignment 物种数正确 |
| supermatrix 串联 | `supermatrix.fa/.phy`、partition、occupancy | 统计缺失率、矩阵长度、最终基因数 | RAxML/IQ-TREE/MrBayes 物种树 | 所有预期物种存在 |
| 物种树构建 | ML tree、bootstrap tree、bipartitions、Bayesian tree 可选 | 标准化物种名；root/rename；记录 bootstrap/PP | CAFE、图形展示、拓扑解释 | bootstrap 完成；树物种名与 GeneCount 一致 |
| 基因树构建 | 每个基因家族的 alignment、trimmed alignment、treefile、support | 整理 tree list；过滤低质量树；与功能注释/orthogroup 合并 | 基因家族进化、复制事件、特定基因家族展示 | tree tips 与 family members 一致 |
| CAFE | 分支扩张/收缩结果 | 提取显著 family；连接 functional_annotation 和 Orthogroups | 扩张收缩结果表和图 | ultrametric tree 与 count matrix 物种名一致 |
| genome-level dotplot | PAF、dotplot 图 | 根据图判断宏观共线性；必要时调 asm preset | WGDI/MCScanX/JCVI 细化 | PAF 非空；图可读 |
| BLASTP/DIAMOND synteny | pairwise protein hits | 确保 ID 对应 GFF；准备 WGDI/MCScanX 输入 | WGDI/MCScanX/JCVI | hit 文件非空；ID 可映射 |
| WGDI/MCScanX/JCVI | anchors、blocks、collinearity、dotplot | 转为 summary、links、anchor table | Circos links、共线性统计 | block/anchor 数不异常为 0 |
| Circos | karyotype、GC/gene/repeat/intron tracks、links、图 | 检查坐标不越界；生成 legend；输出图表 | 论文图、特殊染色体证据 | track ID 与 karyotype 一致 |
| Pfam/domain 统计 | Pfam count matrix、description、input status | 合并多物种矩阵；连接 functional_annotation | domain 比较、特殊区域功能解释 | 列为预期物种；缺失文件记录 |
| 特殊区域证据整合 | evidence table | 汇总 GC、gene density、repeat、domain、synteny、表达/HGT 可选 | 最终图表和方法描述 | 缺失数据标 missing，不当作 absence |

---

# Part I. 数据准备与预检查

## 1.1 原始数据整理

### 目的

在正式组装和注释前，统一样本命名、文件格式和数据类型，避免下游脚本中出现 ID 不一致、路径硬编码、样本混淆等问题。

### 推荐输入

```text
Arabidopsis_thaliana.longread.fastq.gz
Arabidopsis_thaliana.HiC_R1.fastq.gz
Arabidopsis_thaliana.HiC_R2.fastq.gz
Arabidopsis_thaliana.RNAseq_R1.fastq.gz
Arabidopsis_thaliana.RNAseq_R2.fastq.gz
```

### 操作要点

1. 建立样本信息表，至少包含：
   - species_id
   - genome_size_estimate
   - long_read_type
   - hic_available
   - rnaseq_available
   - expected_ploidy
2. 统一 FASTA / FASTQ 文件命名。
3. 检查文件是否为空。
4. 对 FASTA 文件检查重复序列 ID。
5. 对 FASTQ 文件检查 read 数量和碱基量。

### 检查项

```text
1. 文件存在且非空。
2. 样本名唯一。
3. FASTA header 不包含复杂空格。
4. 每个物种 / 样本有明确的数据类型说明。
5. 真实物种名和路径不写入最终方法模板。
```

---

# Part II. 基因组组装

## 2.1 hifiasm 组装

### 目的

使用 HiFi 或 ONT 长读长数据进行初始基因组组装。

### 软件

```text
hifiasm
```

### 基本命令

```bash
hifiasm \
  -o Arabidopsis_thaliana.asm \
  -t 20 \
  Arabidopsis_thaliana.longread.fastq.gz
```

### ONT 模式

```bash
hifiasm \
  -o Arabidopsis_thaliana.asm \
  -t 20 \
  --ont Arabidopsis_thaliana.ont.fastq.gz
```

### Hi-C phased assembly 模式

```bash
hifiasm \
  -o Arabidopsis_thaliana.asm \
  -t 20 \
  --n-hap 2 \
  --h1 Arabidopsis_thaliana.HiC_R1.fastq.gz \
  --h2 Arabidopsis_thaliana.HiC_R2.fastq.gz \
  --ont Arabidopsis_thaliana.ont.fastq.gz
```

### GFA 转 FASTA

```bash
awk '/^S/{print ">"$2"\n"$3}' Arabidopsis_thaliana.asm.bp.p_ctg.gfa > Arabidopsis_thaliana.primary.fa
```

若存在 haplotype 输出：

```bash
awk '/^S/{print ">"$2"\n"$3}' Arabidopsis_thaliana.asm.bp.hap1.p_ctg.gfa > Arabidopsis_thaliana.hap1.fa
awk '/^S/{print ">"$2"\n"$3}' Arabidopsis_thaliana.asm.bp.hap2.p_ctg.gfa > Arabidopsis_thaliana.hap2.fa
```

### 关键参数

```text
-t       线程数
-o       输出前缀
--ont    指定 ONT reads
--h1     Hi-C read1
--h2     Hi-C read2
--n-hap  预期 haplotype 数量
```

### 检查项

```text
1. primary contig FASTA 是否生成。
2. 总组装大小是否接近预期基因组大小。
3. contig N50 是否合理。
4. 是否存在明显过量重复组装。
```

---

## 2.2 NextDenovo 组装

### 目的

使用 ONT / PacBio 长读长数据进行纠错和组装。

### 软件

```text
NextDenovo
minimap2-nd
nextcorrect.py
```

### 主命令

```bash
nextDenovo Arabidopsis_thaliana.run.cfg
```

### 配置文件模板

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

### 历史脚本中常见内部参数

```bash
minimap2-nd \
  --step 1 \
  -x ava-ont \
  -t 10 \
  -k 17 \
  -w 17 \
  --minlen 2000 \
  Arabidopsis_thaliana.reads.fa \
  Arabidopsis_thaliana.reads.fa
```

```bash
nextcorrect.py \
  -p 10 \
  -r ont \
  -max_lq_length 10000 \
  Arabidopsis_thaliana
```

### 检查项

```text
1. run.cfg 中 genome_size 是否合理。
2. read_type 与真实数据类型是否一致。
3. correction 和 assembly 步骤是否完整完成。
4. 最终 fasta 是否非空，是否存在异常短片段过多。
```

---

## 2.3 SPAdes 组装

### 目的

用于小基因组、细胞器基因组或局部组装。

### 软件

```text
SPAdes
```

### 双端短读长模板

```bash
spades.py \
  -1 Arabidopsis_thaliana.R1.fastq.gz \
  -2 Arabidopsis_thaliana.R2.fastq.gz \
  -o Arabidopsis_thaliana.spades \
  -k 21,45,65,85 \
  --max_threads 20
```

### 混合组装模板

```bash
spades.py \
  --pe1-1 Arabidopsis_thaliana.R1.fastq.gz \
  --pe1-2 Arabidopsis_thaliana.R2.fastq.gz \
  --nanopore Arabidopsis_thaliana.longread.fastq.gz \
  -o Arabidopsis_thaliana.spades \
  -k 21,45,65,85 \
  --max_threads 20
```

### 检查项

```text
1. K-mer 设置是否适合 read 长度。
2. contigs.fasta 是否生成。
3. 是否仅用于目标小基因组 / 局部区域，而非默认替代主基因组组装。
```

---

## 2.4 Canu 组装

### 目的

作为长读长组装或纠错方案。

### 软件

```text
Canu
```

### ONT 模板

```bash
canu \
  -p Arabidopsis_thaliana \
  -d Arabidopsis_thaliana.canu \
  genomeSize=150m \
  -nanopore Arabidopsis_thaliana.ont.fastq.gz \
  useGrid=false \
  maxThreads=20
```

### PacBio 模板

```bash
canu \
  -p Arabidopsis_thaliana \
  -d Arabidopsis_thaliana.canu \
  genomeSize=150m \
  -pacbio Arabidopsis_thaliana.pb.fastq.gz \
  useGrid=false \
  maxThreads=20
```

### 检查项

```text
1. genomeSize 是否合理。
2. read 类型是否正确。
3. correction、trimming、unitigging 是否完成。
```

---

# Part III. 组装 polish、去冗余与染色体挂载

## 3.1 purge_dups 去冗余

### 目的

识别并移除 haplotig 或冗余组装片段，得到更接近单套代表基因组的 assembly。

### 软件

```text
minimap2
pbcstat
calcuts
split_fa
purge_dups
get_seqs
```

### 长读长比对

PacBio 模式：

```bash
minimap2 \
  -x map-pb \
  -t 20 \
  Arabidopsis_thaliana.assembly.fa \
  Arabidopsis_thaliana.longread.fastq.gz \
  > Arabidopsis_thaliana.reads_to_asm.paf
```

ONT 模式：

```bash
minimap2 \
  -x map-ont \
  -t 20 \
  Arabidopsis_thaliana.assembly.fa \
  Arabidopsis_thaliana.ont.fastq.gz \
  > Arabidopsis_thaliana.reads_to_asm.paf
```

### 覆盖度统计与 cutoff 计算

```bash
pbcstat Arabidopsis_thaliana.reads_to_asm.paf
calcuts PB.stat > cutoffs
```

### 组装自比对

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

### 冗余片段识别与去除

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

### 检查项

```text
1. 去冗余后总长度不应异常大幅下降。
2. BUSCO duplicated 比例应下降或保持合理。
3. 不能仅凭 purge_dups 输出自动删除关键大 scaffold，需要结合覆盖度和 BUSCO 检查。
```

---

## 3.2 NextPolish polish

### 目的

利用短读长或长读长对组装进行碱基级纠错。

### 软件

```text
NextPolish
```

### 配置文件模板

```ini
[General]
job_type = local
job_prefix = Arabidopsis_thaliana.nextpolish
task = best
rewrite = yes
rerun = 3
parallel_jobs = 10
multithread_jobs = 10
genome = Arabidopsis_thaliana.assembly.fa
genome_size = 150m
workdir = Arabidopsis_thaliana.nextpolish

[sgs_option]
sgs_fofn = Arabidopsis_thaliana.shortread.fofn
sgs_options = -max_depth 100

[lgs_option]
lgs_fofn = Arabidopsis_thaliana.longread.fofn
lgs_options = -min_read_len 1k -max_depth 100
```

### 主命令

```bash
nextPolish Arabidopsis_thaliana.nextpolish.cfg
```

### 检查项

```text
1. polish 后 N 数量是否变化异常。
2. BUSCO 完整度是否改善。
3. Merqury QV 是否改善。
4. 不同 polish 轮次是否记录清楚。
```

---

## 3.3 HiC-Pro 处理 Hi-C 数据

### 目的

将 Hi-C reads 比对到组装基因组，生成用于挂载或交互矩阵分析的结果。

### 软件

```text
HiC-Pro
bowtie2
```

### 酶切位点文件

```bash
digest_genome.py \
  -r ^GATC \
  -o Arabidopsis_thaliana.digest.bed \
  Arabidopsis_thaliana.genome.fa
```

### bowtie2 index

```bash
bowtie2-build \
  Arabidopsis_thaliana.genome.fa \
  Arabidopsis_thaliana.genome
```

### HiC-Pro 主命令

```bash
HiC-Pro \
  -i Arabidopsis_thaliana.hic_fastq_dir \
  -o Arabidopsis_thaliana.hicpro_result \
  -c Arabidopsis_thaliana.config-hicpro.txt
```

### 检查项

```text
1. 酶切位点是否与实验使用的 restriction enzyme 一致。
2. Hi-C reads 比对率是否合理。
3. valid interaction 数量是否足够。
4. Hi-C heatmap 是否显示清晰的染色体内信号。
```

---

## 3.4 chromap / HapHiC 挂载

### chromap Hi-C 比对

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

### HapHiC 主流程

```bash
HapHiC pipeline \
  Arabidopsis_thaliana.assembly.fa \
  Arabidopsis_thaliana.hic.bam \
  Arabidopsis_thaliana \
  --threads 20
```

### HapHiC 绘图与构建

```bash
HapHiC plot Arabidopsis_thaliana
HapHiC build Arabidopsis_thaliana
```

### 检查项

```text
1. 挂载后染色体数是否符合预期。
2. Hi-C heatmap 是否存在明显错拼或跨染色体强信号。
3. 未挂载 scaffold 数量和长度是否记录。
```

---

# Part IV. 组装质量评估

## 4.1 连续性统计

### 目的

统计组装总长、contig/scaffold 数、N50、L50、最大序列长度等。

### 常用操作

```bash
seqkit stats Arabidopsis_thaliana.genome.fa > Arabidopsis_thaliana.seqkit.stats.txt
```

```bash
python assembly_stats.py \
  --fasta Arabidopsis_thaliana.genome.fa \
  --out Arabidopsis_thaliana.assembly.stats.tsv \
  --lengths Arabidopsis_thaliana.assembly.lengths.tsv
```

### 检查项

```text
1. assembly size 是否接近预期。
2. N50 是否达到项目目标。
3. scaffold 数量是否与染色体级组装预期一致。
```

---

## 4.2 BUSCO 完整性评估

### genome 模式

```bash
busco \
  -i Arabidopsis_thaliana.genome.fa \
  -o Arabidopsis_thaliana.busco_genome \
  -l embryophyta_odb10 \
  -m geno \
  --offline \
  -c 20
```

### protein 模式

```bash
busco \
  -i Arabidopsis_thaliana.protein.fa \
  -o Arabidopsis_thaliana.busco_protein \
  -l embryophyta_odb10 \
  -m prot \
  --offline \
  -c 20
```

### 检查项

```text
1. Complete BUSCO 比例。
2. Single-copy 与 duplicated BUSCO 比例。
3. Fragmented 和 missing BUSCO 比例。
4. duplicated 偏高时需检查未去冗余或真实多倍化。
```

---

## 4.3 compleasm 完整性评估

### genome 模式

```bash
compleasm.py run \
  -a Arabidopsis_thaliana.genome.fa \
  -l embryophyta_odb10 \
  -o Arabidopsis_thaliana.compleasm_genome \
  -L busco_lineage_dir \
  -t 20
```

### protein 模式

```bash
compleasm.py protein \
  -p Arabidopsis_thaliana.protein.fa \
  -l embryophyta_odb10 \
  -o Arabidopsis_thaliana.compleasm_protein \
  -L busco_lineage_dir \
  -t 20
```

### 检查项

```text
1. compleasm 与 BUSCO 结果是否一致。
2. 若差异较大，检查 lineage、输入模式和软件版本。
```

---

## 4.4 Merqury / meryl k-mer 评估

### 目的

利用测序 reads 的 k-mer 频率评估组装准确性、完整性和 QV。

### 估计 k 值

```bash
best_k.sh 150000000
```

### 构建 reads meryl database

```bash
meryl count \
  k=21 \
  threads=20 \
  output Arabidopsis_thaliana.reads.meryl \
  Arabidopsis_thaliana.R1.fastq.gz Arabidopsis_thaliana.R2.fastq.gz
```

### 构建 assembly meryl database

```bash
meryl count \
  k=21 \
  threads=20 \
  output Arabidopsis_thaliana.assembly.meryl \
  Arabidopsis_thaliana.genome.fa
```

### k-mer histogram

```bash
meryl histogram \
  Arabidopsis_thaliana.reads.meryl \
  > Arabidopsis_thaliana.reads.hist
```

### Merqury 主流程

```bash
merqury.sh \
  Arabidopsis_thaliana.reads.meryl \
  Arabidopsis_thaliana.genome.fa \
  Arabidopsis_thaliana.merqury
```

### 检查项

```text
1. QV 是否达到预期。
2. completeness 是否合理。
3. k-mer spectra-cn 是否支持当前组装版本。
```

---

## 4.5 LAI 评估：完整流程

### 目的

LAI，即 LTR Assembly Index，用于评估基因组重复区域尤其是 LTR retrotransposon 区域的组装质量。它不能只运行 `LAI` 命令，前面必须有完整的 LTR 候选识别、LTR_retriever 整理和全基因组重复注释结果。

### 软件

```text
LTR_FINDER_parallel
GenomeTools / LTRharvest
LTR_retriever
RepeatMasker
LAI
```

### Step 1. LTR_FINDER_parallel 识别 LTR 候选

```bash
LTR_FINDER_parallel \
  -seq Arabidopsis_thaliana.genome.fa \
  -threads 12 \
  -harvest_out \
  -size 1000000 \
  -time 300
```

该步骤通常生成类似：

```text
Arabidopsis_thaliana.genome.fa.finder.combine.scn
```

### Step 2. LTRharvest 可选补充

如果使用 LTRharvest：

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

### Step 3. 合并 LTR 候选

如果同时使用 LTR_FINDER_parallel 和 LTRharvest，需要合并候选：

```bash
cat \
  Arabidopsis_thaliana.genome.fa.finder.combine.scn \
  Arabidopsis_thaliana.harvest.scn \
  > Arabidopsis_thaliana.raw_ltr.scn
```

若只使用 LTR_FINDER_parallel，则直接使用其输出作为 `raw_ltr.scn`。

### Step 4. LTR_retriever 整理高置信 LTR

```bash
LTR_retriever \
  -genome Arabidopsis_thaliana.genome.fa \
  -inharvest Arabidopsis_thaliana.raw_ltr.scn \
  -threads 12
```

关键输出通常包括：

```text
Arabidopsis_thaliana.genome.fa.pass.list
Arabidopsis_thaliana.genome.fa.out
Arabidopsis_thaliana.genome.fa.LTRlib.fa
```

### Step 5. 使用 LTR library 或 repeat library 做 RepeatMasker

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

如果已有整合 repeat library，也可使用：

```bash
RepeatMasker \
  -nolow \
  -no_is \
  -norna \
  -engine ncbi \
  -parallel 20 \
  -lib Arabidopsis_thaliana.repeat_library.fa \
  Arabidopsis_thaliana.genome.fa
```

### Step 6. 运行 LAI

LAI 需要完整 LTR 候选和 RepeatMasker 全基因组注释结果。

```bash
LAI \
  -genome Arabidopsis_thaliana.genome.fa \
  -intact Arabidopsis_thaliana.genome.fa.pass.list \
  -all Arabidopsis_thaliana.genome.fa.out \
  -t 20
```

### Step 7. LAI 结果解释

```text
LAI < 10      draft quality
10 <= LAI < 20 reference quality
LAI >= 20     gold quality
```

具体阈值需结合类群、基因组大小和重复序列比例解释。

### 检查项

```text
1. LAI 前必须确认 pass.list 存在。
2. LAI 前必须确认 RepeatMasker .out 文件存在。
3. LTR_retriever 输入的 scn 是否来自当前版本 genome。
4. RepeatMasker 使用的 genome 是否与 LTR_retriever 的 genome 完全一致。
5. 若 LAI 异常低，检查 LTR 候选识别是否失败，而不是直接解释为组装差。
```

---

# Part V. 重复序列注释

## 5.1 总体策略

### 目的

对基因组重复序列进行 de novo 识别、LTR 专项整理、RepeatMasker 全基因组注释、GFF 转换和分类统计。该流程以 `LTR_FINDER_parallel + LTRharvest + LTR_retriever` 生成 LTR 库，以 `RepeatModeler` 生成 de novo repeat 库，二者结果完成后再合并为 RepeatMasker 注释库。

### 推荐流程

```text
检查基因组序列大小写
  ↓
必要时将序列统一转为大写
  ↓
并行运行：
  ├─ LTR_FINDER_parallel + LTRharvest
  └─ RepeatModeler
  ↓
LTR_FINDER_parallel 和 LTRharvest 均完成后运行 LTR_retriever work.sh
  ↓
合并 LTR_retriever 的 LTR library 与 RepeatModeler library
  ↓
RepeatMasker 分 known / unknown 库注释基因组
  ↓
RepeatMasker .out 转 GFF3
  ↓
重复序列分类统计与窗口密度统计
```

### 软件

```text
seqkit
LTR_FINDER_parallel
GenomeTools / LTRharvest
LTR_retriever
RepeatModeler
BuildDatabase
RepeatMasker
bedtools
TRF，可选
```

---

## 5.2 基因组序列大写检查与转换

### 目的

在运行 LTR_FINDER、LTRharvest、RepeatModeler 和 RepeatMasker 前，确保基因组序列部分全部为大写。FASTA ID 的大小写不用处理；只需要转换序列本身。

### 检查序列是否含小写碱基

```bash
seqkit seq \
  -s \
  Arabidopsis_thaliana.genome.fa \
  | grep -q '[a-z]' && echo "lowercase_found" || echo "all_uppercase"
```

### 转换为大写

```bash
seqkit seq \
  -u \
  Arabidopsis_thaliana.genome.fa \
  > Arabidopsis_thaliana.genome.upper.fa
```

### 建议统一命名

后续重复注释目录中建议统一使用：

```bash
ln -s Arabidopsis_thaliana.genome.upper.fa genome.fa
```

如果原始基因组已经全是大写，也可以直接链接：

```bash
ln -s Arabidopsis_thaliana.genome.fa genome.fa
```

### 检查项

```text
1. 转换只影响序列，不要求修改 FASTA ID 大小写。
2. 后续所有重复注释步骤必须使用同一个 genome.fa。
3. genome.fa 必须与后续 LAI、RepeatMasker、统计步骤完全一致。
```

---

## 5.3 LTR_FINDER_parallel 与 LTRharvest

### 目的

分别使用 LTR_FINDER_parallel 和 LTRharvest 识别 LTR retrotransposon 候选。两个结果都生成后，再交给 LTR_retriever 整合。

### LTR_FINDER_parallel

```bash
LTR_FINDER_parallel \
  -seq genome.fa \
  -threads 30 \
  -harvest_out \
  -size 1000000 \
  -time 300
```

预期关键结果：

```text
genome.fa.finder.combine.scn
```

### LTRharvest index

```bash
gt suffixerator \
  -db genome.fa \
  -indexname genome.fa \
  -tis -suf -lcp -des -ssp -sds -dna
```

### LTRharvest 搜索

```bash
gt ltrharvest \
  -index genome.fa \
  -minlenltr 100 \
  -maxlenltr 7000 \
  -mintsd 4 \
  -maxtsd 6 \
  -motif TGCA \
  -motifmis 1 \
  -similar 85 \
  -vic 10 \
  -seed 20 \
  -seqids yes \
  > genome.fa.harvest.scn
```

### 检查项

```text
1. LTR_FINDER_parallel 输出 `genome.fa.finder.combine.scn`。
2. LTRharvest 输出 `genome.fa.harvest.scn`。
3. 两个 scn 文件都应来自同一个大写版本 genome.fa。
4. 若任一 scn 为空，应检查 genome.fa、软件环境和参数，而不是直接进入 LTR_retriever。
```

---

## 5.4 RepeatModeler de novo 重复库构建

### 目的

使用 RepeatModeler 从当前基因组 de novo 构建重复序列库。该步骤可以与 LTR_FINDER_parallel / LTRharvest 并行运行。

### BuildDatabase

```bash
BuildDatabase \
  -name mydb \
  genome.fa \
  > repeatmodeler.log
```

### RepeatModeler

```bash
RepeatModeler \
  -database mydb \
  -threads 20 \
  > run.out
```

### 预期结果

不同版本 RepeatModeler 输出文件名可能不同，常见形式包括：

```text
mydb-families.fa
mydb-known.families.fa
mydb-unknown.families.fa
consensi.fa.classified
```

### 检查项

```text
1. BuildDatabase 是否成功完成。
2. RepeatModeler 是否生成 repeat families。
3. 若存在 known / unknown families，应保留两类库。
4. RepeatModeler 使用的 genome.fa 必须与 LTR 流程一致。
```

---

## 5.5 LTR_retriever 整合 LTR 候选

### 目的

在 LTR_FINDER_parallel 和 LTRharvest 均完成后，将两个 scn 结果合并，并用 LTR_retriever 生成高置信 LTR 库和 LAI 所需输入。

### 合并 LTR 候选

```bash
cat \
  genome.fa.harvest.scn \
  genome.fa.finder.combine.scn \
  > genome.fa.rawLTR.scn
```

### 运行 LTR_retriever

```bash
LTR_retriever \
  -genome genome.fa \
  -inharvest genome.fa.rawLTR.scn \
  -threads 12
```

### 预期结果

```text
genome.fa.LTRlib.fa
genome.fa.pass.list
genome.fa.out
```

其中：

```text
genome.fa.LTRlib.fa  用于后续 RepeatMasker library 合并
genome.fa.pass.list  用于 LAI
genome.fa.out        可用于 LAI 的 all repeat 输入之一
```

### 检查项

```text
1. `genome.fa.rawLTR.scn` 不应为空。
2. `genome.fa.LTRlib.fa` 必须存在后才能合并注释库。
3. `genome.fa.pass.list` 和 `genome.fa.out` 是后续 LAI 的关键文件。
```

---

## 5.6 构建 RepeatMasker 注释库

### 目的

将公共 / 已知重复库、LTR_retriever 生成的 LTR 库、RepeatModeler 生成的 de novo 库合并，作为 RepeatMasker 的注释库。

### known library

如果 RepeatModeler 输出 known families，可将其与 LTR 库和公共已知库合并：

```bash
cat \
  curated_repeat_library.fa \
  taxon_known_repeat_library.fa \
  ltr_finder/genome.fa.LTRlib.fa \
  repeatmodeler/mydb-known.families.fa \
  > known.library
```

如果没有单独的 known families，可使用 RepeatModeler 分类后的总库替代：

```bash
cat \
  curated_repeat_library.fa \
  taxon_known_repeat_library.fa \
  ltr_finder/genome.fa.LTRlib.fa \
  repeatmodeler/consensi.fa.classified \
  > known.library
```

### unknown library

如果 RepeatModeler 输出 unknown families：

```bash
ln -s repeatmodeler/mydb-unknown.families.fa unknown.library
```

如果没有单独 unknown 文件，可跳过 unknown 分库注释，或从 RepeatModeler 总库中按分类信息拆分后再运行。

### 检查项

```text
1. known.library 必须包含 LTR_retriever 的 `genome.fa.LTRlib.fa`。
2. RepeatModeler 输出文件名因版本不同需要确认。
3. 不要把旧项目的真实物种库名和绝对路径写入通用 SOP。
```

---

## 5.7 RepeatMasker 全基因组重复注释

### 目的

使用合并后的 known / unknown repeat library 对基因组进行全基因组重复注释。

### known 库注释

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

### unknown 库注释

```bash
RepeatMasker \
  -lib unknown.library \
  -pa 30 \
  genome.fa \
  -dir unknown
```

### 可选参数说明

历史脚本使用的是简洁参数：

```text
-lib    指定 repeat library
-pa     并行线程数
genome  当前大写基因组
-dir    输出目录
```

如果项目要求更严格控制，也可增加：

```bash
RepeatMasker \
  -nolow \
  -no_is \
  -norna \
  -engine ncbi \
  -parallel 30 \
  -lib known.library \
  genome.fa \
  -dir known
```

### 合并 RepeatMasker .out

```bash
awk 'FNR <= 3 && NR > 3 {next} {print}' \
  known/genome.fa.out \
  unknown/genome.fa.out \
  > Arabidopsis_thaliana.repeatmasker.all.out
```

如果只跑一个库，则直接使用对应的 `.out` 文件作为最终 RepeatMasker 输出。

### 检查项

```text
1. known/genome.fa.out 和 unknown/genome.fa.out 是否生成。
2. RepeatMasker 输入 genome.fa 是否仍为大写版本。
3. `.masked` 文件可用于后续 soft-masked genome，但正式基因注释前需确认是否使用 known、unknown 或 merged mask。
```

---

## 5.8 RepeatMasker .out 转 GFF3

### 目的

将 RepeatMasker `.out` 转换为 GFF3，方便后续统计、Circos track 和浏览器展示。

### 命令模板

```bash
bash rmout2gff.sh \
  Arabidopsis_thaliana.repeatmasker.all.out \
  > Arabidopsis_thaliana.repeatmasker.all.gff3
```

转换脚本逻辑要点：

```text
1. 跳过 RepeatMasker .out 前 3 行 header。
2. 将 RepeatMasker 坐标转换为 GFF3 similarity feature。
3. 将 C 链转换为负链。
4. 按 LINE、SINE、DNA、LTR、RC、Low_complexity、Satellite、Simple_repeat、Unknown 添加颜色标签。
```

### 检查项

```text
1. GFF3 第一行应为 `##gff-version 3`。
2. 坐标必须不超过 genome.fa 的 scaffold/chromosome 长度。
3. GFF3 中 repeat 分类应能用于后续统计。
```

---

## 5.9 重复序列分类统计

### 目的

统计全基因组重复序列总占比和主要类别占比，包括 DNA transposon、SINE、LINE、LTR、Unknown、Satellite、Simple_repeat 等。

### 命令模板

```bash
bash repeat_stat.sh \
  Arabidopsis_thaliana.repeatmasker.all.out \
  150000000 \
  > Arabidopsis_thaliana.repeat.summary.txt
```

统计逻辑：

```text
1. 从 RepeatMasker .out 提取 scaffold、start、end。
2. 按类别 grep DNA / SINE / LINE / LTR / Unknown / Satellite / Simple_repeat。
3. 每类区间排序后用 bedtools merge 合并重叠区域。
4. 计算非冗余覆盖长度。
5. 用覆盖长度 / genome size 得到百分比。
```

### 检查项

```text
1. genome size 参数应为当前 genome.fa 的总长度。
2. 分类统计应基于合并区间，避免重复命中导致比例虚高。
3. 总重复比例和各分类比例需与 RepeatMasker 原始 summary 交叉检查。
```

---

## 5.10 TRF 串联重复注释，可选

### 目的

识别 tandem repeat，作为 RepeatMasker 结果的补充。

### TRF 命令

```bash
trf \
  genome.fa \
  2 5 7 80 10 50 2000 \
  -d -h
```

### TRF 转 GFF3

```bash
trf2gff \
  -o - \
  < genome.fa.2.5.7.80.10.50.2000.dat \
  > Arabidopsis_thaliana.trf.gff3
```

### 检查项

```text
1. TRF 输出文件名由参数自动拼接，需确认实际 `.dat` 文件名。
2. TRF 结果可作为 Simple_repeat / tandem repeat 补充，不应与 RepeatMasker 分类混淆。
```

---

## 5.11 Repeat density 统计

### 窗口划分

```bash
samtools faidx genome.fa
```

```bash
bedtools makewindows \
  -g genome.fa.fai \
  -w 100000 \
  > Arabidopsis_thaliana.100kb.windows.bed
```

### repeat coverage

```bash
bedtools coverage \
  -a Arabidopsis_thaliana.100kb.windows.bed \
  -b Arabidopsis_thaliana.repeatmasker.all.gff3 \
  > Arabidopsis_thaliana.repeat_density.tsv
```

### 检查项

```text
1. repeat GFF3 坐标体系需与 bedtools 兼容。
2. 窗口大小可按基因组大小调整，例如 10 kb、50 kb、100 kb。
3. Circos 使用的 repeat density track 应记录窗口大小和输入 GFF3。
```

---

## 5.12 重复注释流程检查项

```text
1. 跑所有重复注释前，确认 genome.fa 序列全为大写。
2. LTR_FINDER_parallel 和 RepeatModeler 可以同时跑。
3. LTR_FINDER_parallel 目录下需先跑 LTR_Finder.sh 和 LTR_harvest.sh。
4. LTR_Finder 和 LTR_harvest 两个结果都完成后，再跑 work.sh / LTR_retriever。
5. LTR_retriever 和 RepeatModeler 都有结果后，再合并 library。
6. RepeatMasker 必须使用当前项目的 genome.fa 和当前项目生成的 repeat library。
7. known / unknown 注释结果要分开保存，也要生成合并后的总表。
8. `.out`、`.gff3`、`.masked`、summary、density 文件都应保留。
9. 不要直接复用参考脚本中的真实路径、真实物种名和旧项目数据库名。
```

---

# Part VI. 基因结构注释与 GFF/CDS/PEP 整理

## 6.1 BRAKER3 注释

### 目的

整合 soft-masked genome、蛋白证据和 RNA-seq 证据预测基因结构。该步骤的直接输出通常是 GFF/GTF、蛋白序列、CDS 序列和中间训练文件；但这些结果不能直接进入所有下游分析，必须经过 ID、主转录本和 CDS 质量整理。

### 软件

```text
BRAKER3
AUGUSTUS
GeneMark
gff_cds_pep.py
gffread，可选对照
BUSCO / compleasm protein mode
```

### 输入

```text
Arabidopsis_thaliana.softmasked.genome.fa
Arabidopsis_lyrata.reference_proteins.fa
Arabidopsis_thaliana.rnaseq_dir，可选
repeatmasker / repeat annotation 产生的 soft-masked genome
```

### 同时使用蛋白和 RNA-seq 证据

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

### 仅使用蛋白证据

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

### BRAKER 输出后处理

BRAKER 完成后，先确定最终 GFF/GFF3 文件。若输出是 GTF，可先转 GFF3：

```bash
gtf2gff.pl \
  --gff3 \
  Arabidopsis_thaliana.annotation.gtf \
  > Arabidopsis_thaliana.annotation.gff3
```

如果 BRAKER 已直接输出 GFF3，则保留为：

```text
Arabidopsis_thaliana.annotation.gff3
```

### 检查项

```text
1. soft-masked genome 是否来自当前重复注释流程。
2. genome FASTA 与 GFF/GFF3 坐标必须匹配。
3. GFF/GFF3 中 transcript feature 应为 `mRNA` 或 `transcript`。
4. transcript feature 应含 `ID=`。
5. CDS feature 应含 `Parent=`，并指向 transcript ID。
6. `--species` 不要复用旧项目名称。
7. 注释输出不能只看文件存在，还要进入 GFF/CDS/PEP 质检流程。
```

---

## 6.2 使用 gff-cds-pep 整理 GFF、CDS 和 PEP

### 目的

参考 `gff-cds-pep` 流程，在基因结构注释结束后，从 genome FASTA 和 GFF/GFF3 中生成干净的 GFF、CDS FASTA、peptide FASTA、CDS 质量检查表和可选染色体级子集。该步骤是功能注释、OrthoFinder、JCVI、GENESPACE、Circos 等下游分析的标准输入准备步骤。

### 推荐输入

```text
species_id
species_name
genome_fasta
annotation_gff
keep_ids，可选
```

### manifest.tsv

```text
species_id	species_name	genome_fasta	annotation_gff	keep_ids
Ath	Arabidopsis_thaliana	Arabidopsis_thaliana.genome.fa	Arabidopsis_thaliana.annotation.gff3	Arabidopsis_thaliana.keep_ids.txt
Aly	Arabidopsis_lyrata	Arabidopsis_lyrata.genome.fa	Arabidopsis_lyrata.annotation.gff3	NA
```

`keep_ids` 为可选文件，一行一个 chromosome/scaffold ID，用于生成 chromosome-level 或指定 scaffold 子集。如果不需要子集，填 `NA`。

### 运行核心脚本

```bash
python3 gff_cds_pep.py \
  --manifest manifest.tsv \
  --outdir gff_cds_pep_outputs
```

如需保留不合格 CDS 以便排查：

```bash
python3 gff_cds_pep.py \
  --manifest manifest.tsv \
  --outdir gff_cds_pep_outputs \
  --keep-bad-cds
```

如需先用正则筛选 transcript ID：

```bash
python3 gff_cds_pep.py \
  --manifest manifest.tsv \
  --outdir gff_cds_pep_outputs \
  --transcript-regex 't1|\.1$'
```

### 脚本内部处理逻辑

```text
1. 读取 genome FASTA，并将序列转为大写用于提取 CDS。
2. 解析 GFF/GFF3 属性字段。
3. 识别 `mRNA` 或 `transcript` feature。
4. 读取 transcript 的 `ID=`。
5. 读取 CDS 的 `Parent=` 并关联到 transcript。
6. 每个 gene 选择一个 transcript：优先 `.t1`；没有 `.t1` 时选字典序第一个。
7. 按 CDS 片段基因组坐标升序拼接 CDS。
8. 负链 transcript 拼接后反向互补。
9. 使用标准遗传密码表翻译 peptide。
10. 生成 CDS 质量检查表。
11. 默认过滤 `phase_ok = 0` 或 `internal_stop > 0` 的 CDS。
12. 输出 clean GFF、CDS、PEP 和 check 表。
```

### 输出目录结构

```text
gff_cds_pep_outputs/
  summary.tsv
  Ath/
    hic/
      Ath.hic.gff
      Ath.hic.cds
      Ath.hic.pep
      Ath.hic.raw.cds.check
      Ath.hic.cds.check
    chromosome/
      Ath.chr.gff
      Ath.chr.cds
      Ath.chr.pep
      Ath.chr.raw.cds.check
      Ath.chr.cds.check
```

### summary.tsv 字段

```text
species
species_name
level
transcripts_selected
raw_cds_written
filtered_bad_cds
cds_written
gff_features
outdir
```

### CDS 检查表字段

```text
transcript_id
seqid
cds_len
phase_ok
start_ok
terminal_stop
internal_stop
ambiguous_nt
```

### 输出后处理为下游输入

```bash
cp gff_cds_pep_outputs/Ath/hic/Ath.hic.pep Arabidopsis_thaliana.protein.primary.fa
cp gff_cds_pep_outputs/Ath/hic/Ath.hic.cds Arabidopsis_thaliana.cds.primary.fa
cp gff_cds_pep_outputs/Ath/hic/Ath.hic.gff Arabidopsis_thaliana.annotation.primary.gff3
```

用于 OrthoFinder：

```bash
mkdir -p protein_dir
cp Arabidopsis_thaliana.protein.primary.fa protein_dir/Arabidopsis_thaliana.fa
cp Arabidopsis_lyrata.protein.primary.fa protein_dir/Arabidopsis_lyrata.fa
```

用于功能注释：

```text
Arabidopsis_thaliana.protein.primary.fa
```

用于 CDS-based 分析：

```text
Arabidopsis_thaliana.cds.primary.fa
```

用于共线性 / JCVI / GENESPACE / Circos：

```text
Arabidopsis_thaliana.annotation.primary.gff3
Arabidopsis_thaliana.protein.primary.fa
Arabidopsis_thaliana.cds.primary.fa
```

### 质量检查项

```text
1. summary.tsv 中每个 species 的 cds_written 是否合理。
2. filtered_bad_cds 是否异常偏高。
3. 最终 `.cds.check` 中不应有 `phase_ok = 0`。
4. 最终 `.cds.check` 中不应有 `internal_stop > 0`。
5. 如果 bad_start、terminal_stop 缺失或 ambiguous_nt 异常偏高，应检查注释质量或 genome/GFF 版本匹配。
6. 如果大量 CDS 异常，优先怀疑 GFF 与 genome FASTA 不是同一版本。
7. 下游所有蛋白输入建议使用 `.pep`，FASTA header 保持 transcript_id，不加长描述。
```

---

## 6.3 gffread 作为快速对照

### 目的

`gffread` 可快速从 GFF/GFF3 提取 CDS 和 protein，但不替代 `gff_cds_pep.py` 的主转录本选择和 CDS 质检。建议作为快速对照或临时检查。

### 命令

```bash
gffread \
  Arabidopsis_thaliana.annotation.gff3 \
  -g Arabidopsis_thaliana.genome.fa \
  -x Arabidopsis_thaliana.gffread.cds.fa \
  -y Arabidopsis_thaliana.gffread.pep.fa
```

### 对照检查

```bash
seqkit stats \
  Arabidopsis_thaliana.gffread.cds.fa \
  Arabidopsis_thaliana.cds.primary.fa \
  Arabidopsis_thaliana.gffread.pep.fa \
  Arabidopsis_thaliana.protein.primary.fa
```

### 检查项

```text
1. gffread 输出数量通常可能多于 primary transcript 输出。
2. 如果 gffread 大量报错，说明 GFF 或 genome 版本可能有问题。
3. 最终交付仍应以经过主转录本和 CDS 质检的结果为准。
```

---

## 6.4 protein-level 完整性评估

### 目的

对整理后的 primary peptide FASTA 做 BUSCO/compleasm protein mode，确认基因注释结果质量。

### BUSCO protein mode

```bash
busco \
  -i Arabidopsis_thaliana.protein.primary.fa \
  -o Arabidopsis_thaliana.busco_protein_primary \
  -l embryophyta_odb10 \
  -m prot \
  --offline \
  -c 20
```

### compleasm protein mode

```bash
compleasm.py protein \
  -p Arabidopsis_thaliana.protein.primary.fa \
  -l embryophyta_odb10 \
  -o Arabidopsis_thaliana.compleasm_protein_primary \
  -L busco_lineage_dir \
  -t 20
```

### 输出后衔接

```text
protein.primary.fa 进入功能注释、OrthoFinder、共线性 BLASTP/DIAMOND。
annotation.primary.gff3 进入 JCVI/WGDI/MCScanX/Circos gene density。
cds.primary.fa 进入 CDS-based 比对、Ka/Ks 或密码子分析。
```

---

# Part VII. 功能注释

## 7.1 总体策略

### 目的

对 `protein.primary.fa` 进行多数据库功能注释，并将 InterPro/Pfam、GO、eggNOG、KEGG/KOfam、SwissProt/NR 等结果整理为统一 gene/transcript annotation table，供后续 domain 统计、基因家族解释、扩张收缩解释、特殊染色体功能统计和图表绘制使用。

### 推荐输入

```text
Arabidopsis_thaliana.protein.primary.fa
Arabidopsis_thaliana.cds.primary.fa
Arabidopsis_thaliana.annotation.primary.gff3
gff_cds_pep_outputs/Ath/hic/Ath.hic.cds.check
```

### 推荐输出

```text
Arabidopsis_thaliana.interproscan.tsv
Arabidopsis_thaliana.iprscan.xls
Arabidopsis_thaliana.eggnog.annotations.tsv
Arabidopsis_thaliana.kofam.detail.txt
Arabidopsis_thaliana.swissprot.diamond.tsv
Arabidopsis_thaliana.nr.diamond.tsv，可选
Arabidopsis_thaliana.functional_annotation.tsv
Arabidopsis_thaliana.pfam_count.tsv
```

---

## 7.2 InterProScan

### 目的

获得 Pfam、InterPro、GO 和 domain 注释。该结果是后续 Pfam/domain 统计的主要输入。

### 运行

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

### 输出后处理

将 TSV 解析为项目统一的 `.iprscan.xls` 格式，建议字段为：

```text
Query_id
Subject_id
Subject_DB
Query_start
Query_end
E_value
Subject_annotation
```

示例解析命令：

```bash
python parse_interproscan_tsv.py \
  --input Arabidopsis_thaliana.interproscan.tsv \
  --out Arabidopsis_thaliana.iprscan.xls
```

提取 Pfam 记录：

```bash
awk -F '\t' 'NR==1 || $3=="Pfam"' \
  Arabidopsis_thaliana.iprscan.xls \
  > Arabidopsis_thaliana.pfam.tsv
```

### 检查项

```text
1. protein.primary.fa 中的 transcript_id 应出现在 InterProScan Query_id 中。
2. `.iprscan.xls` 是否包含 Subject_DB == Pfam 的行。
3. GO、InterPro 和 Pfam 字段是否能被后续脚本解析。
4. temp_dir 空间不足会导致任务失败，需要保留日志。
```

---

## 7.3 eggNOG-mapper

### 目的

获得 orthology-based 功能描述、COG、GO、KEGG KO、pathway 等注释。

### 运行

```bash
emapper.py \
  -i Arabidopsis_thaliana.protein.primary.fa \
  -o Arabidopsis_thaliana.eggnog \
  -d euk \
  --cpu 30 \
  --dbmem
```

### 输出后处理

常用输出为：

```text
Arabidopsis_thaliana.eggnog.emapper.annotations
Arabidopsis_thaliana.eggnog.emapper.seed_orthologs
Arabidopsis_thaliana.eggnog.emapper.hits
```

过滤注释表中的注释行：

```bash
grep -v '^##' \
  Arabidopsis_thaliana.eggnog.emapper.annotations \
  > Arabidopsis_thaliana.eggnog.annotations.tsv
```

### 检查项

```text
1. 输入蛋白 ID 是否与 primary peptide ID 一致。
2. 注释表是否包含 preferred_name、GOs、KEGG_ko、COG_category、Description 等字段。
3. 若注释率很低，检查数据库、物种距离和蛋白序列质量。
```

---

## 7.4 KofamScan / KEGG

### 目的

基于 profile HMM 获取 KEGG Orthology 注释，作为 eggNOG KEGG 字段的补充或校验。

### 运行

```bash
exec_annotation \
  -f detail \
  -o Arabidopsis_thaliana.kofam.detail.txt \
  Arabidopsis_thaliana.protein.primary.fa
```

### 输出后处理

保留通过阈值的 KO：

```bash
awk '$1=="*" || NR==1' \
  Arabidopsis_thaliana.kofam.detail.txt \
  > Arabidopsis_thaliana.kofam.filtered.txt
```

如 detail 格式不含 header，应按实际列号解析：

```bash
python parse_kofam_detail.py \
  --input Arabidopsis_thaliana.kofam.detail.txt \
  --out Arabidopsis_thaliana.kofam.tsv
```

### 检查项

```text
1. 是否保留 score、threshold 和 KO ID。
2. 是否只把通过阈值的命中纳入最终功能注释。
3. KO ID 与 eggNOG 结果冲突时需保留来源字段。
```

---

## 7.5 DIAMOND 注释 SwissProt / NR

### 目的

通过蛋白同源比对获得最佳同源蛋白、功能描述和物种来源。SwissProt 用于高置信功能描述；NR 可选，用于更广覆盖。

### SwissProt

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

### NR，可选

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

### 输出后处理

取每个 query 的最佳命中：

```bash
sort -k1,1 -k12,12gr \
  Arabidopsis_thaliana.swissprot.diamond.tsv \
  | awk '!seen[$1]++' \
  > Arabidopsis_thaliana.swissprot.besthit.tsv
```

### 检查项

```text
1. outfmt 必须包含 qseqid 和功能描述字段，方便合并总表。
2. best hit 排序字段需与 outfmt 中 bitscore 列一致。
3. NR 注释体量大，建议作为可选步骤。
```

---

## 7.6 BLASTP 注释，可选

### 目的

当项目要求使用 BLASTP 或需要与旧脚本兼容时，使用 BLASTP 进行蛋白数据库比对。

### 运行

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

### 输出后处理

```bash
sort -k1,1 -k12,12gr \
  Arabidopsis_thaliana.swissprot.blastp.tsv \
  | awk '!seen[$1]++' \
  > Arabidopsis_thaliana.swissprot.blastp.besthit.tsv
```

---

## 7.7 合并功能注释总表

### 目的

将 protein primary ID、GFF 位置信息、CDS 质检、InterPro/Pfam、eggNOG、Kofam、SwissProt/NR 注释合并成一个统一表，供后续所有比较基因组模块使用。

### 推荐输入

```text
Arabidopsis_thaliana.annotation.primary.gff3
Arabidopsis_thaliana.cds.primary.fa
Arabidopsis_thaliana.protein.primary.fa
Ath.hic.cds.check
Arabidopsis_thaliana.iprscan.xls
Arabidopsis_thaliana.eggnog.annotations.tsv
Arabidopsis_thaliana.kofam.tsv
Arabidopsis_thaliana.swissprot.besthit.tsv
Arabidopsis_thaliana.nr.besthit.tsv，可选
```

### 合并命令模板

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

### 推荐字段

```text
transcript_id
gene_id
seqid
start
end
strand
cds_len
phase_ok
start_ok
terminal_stop
internal_stop
ambiguous_nt
Pfam_ids
InterPro_ids
GO_terms
eggNOG_ortholog
COG_category
KEGG_ko
Kofam_ko
SwissProt_best_hit
SwissProt_description
NR_best_hit
NR_description
annotation_source_priority
```

### 检查项

```text
1. functional_annotation.tsv 的 transcript_id 必须能对应 protein.primary.fa。
2. Pfam_ids 可直接用于 domain 统计。
3. KEGG_ko / Kofam_ko 冲突时保留来源，不要覆盖。
4. 未注释基因保留行，字段填 NA，而不是删除。
5. 该总表是扩张收缩、特殊染色体、domain 统计和绘图解释的核心输入。
```

---

## 7.8 功能注释输出到下一步输入

### Pfam/domain 统计

输入：

```text
Arabidopsis_thaliana.iprscan.xls
```

输出：

```text
Arabidopsis_thaliana.pfam_count.tsv
多物种 Pfam count matrix
```

### 基因家族注释解释

输入：

```text
Orthogroups.tsv
Arabidopsis_thaliana.functional_annotation.tsv
```

输出：

```text
Orthogroup functional summary
expanded family annotation
contracted family annotation
```

### 共线性和 Circos

输入：

```text
Arabidopsis_thaliana.annotation.primary.gff3
Arabidopsis_thaliana.functional_annotation.tsv
Arabidopsis_thaliana.repeatmasker.all.gff3
```

输出：

```text
gene density track
functional marker track
repeat density track
special chromosome evidence table
```

---

# Part VIII. 基因家族、系统发育与扩张收缩

## 8.1 OrthoFinder 基因家族聚类

### 目的

在多个物种之间识别 orthogroup，为系统发育和扩张收缩提供输入。

### 命令

```bash
orthofinder \
  -f protein_dir \
  -t 32 \
  -a 32
```

大规模任务：

```bash
orthofinder \
  -f protein_dir \
  -t 60 \
  -a 60
```

续跑：

```bash
orthofinder \
  -b WorkingDirectory \
  -t 32 \
  -a 32
```

### 检查项

```text
1. protein_dir 下每个物种一个 protein FASTA。
2. 文件名即 species_id，避免空格和特殊字符。
3. Orthogroups.tsv、Orthogroups.GeneCount.tsv 是否生成。
4. Single-copy orthogroups 数量是否记录。
```

---

## 8.2 单拷贝基因选择

### 原则

```text
1. 优先使用严格单拷贝基因。
2. 如果目标是固定数量，例如 256 个，则从合格单拷贝基因中筛选。
3. 如果不足目标数量，则使用所有合格单拷贝基因并记录最终数量。
4. 避免直接用低拷贝代表基因，除非单拷贝基因数量严重不足。
```

---

## 8.3 MAFFT 比对

```bash
mafft \
  --maxiterate 1000 \
  --localpair \
  --thread 2 \
  --anysymbol \
  OG0000001.fa \
  > OG0000001.MSA.fa
```

批量模板：

```bash
for fa in singlecopy_dir/*.fa
do
  name=$(basename "$fa" .fa)
  mafft \
    --maxiterate 1000 \
    --localpair \
    --thread 2 \
    --anysymbol \
    "$fa" \
    > alignment_dir/${name}.MSA.fa
done
```

---

## 8.4 seqkit 去换行

```bash
seqkit seq \
  -w 0 \
  OG0000001.MSA.fa \
  > OG0000001.MSA.link.fa
```

---

## 8.5 比对修剪

历史脚本中存在自定义 `trim_phy.pl 50`，但需确认脚本含义后再直接复用。

```bash
perl trim_phy.pl \
  OG0000001.alignment.phy \
  50 \
  > OG0000001.trimmed.phy
```

推荐可替代方案：

```bash
trimal \
  -in OG0000001.MSA.fa \
  -out OG0000001.trimmed.fa \
  -automated1
```

或：

```bash
trimal \
  -in OG0000001.MSA.fa \
  -out OG0000001.trimmed.fa \
  -gt 0.5
```

---

## 8.6 串联 supermatrix

历史 concat 脚本可能硬编码物种数，不建议直接复制，应重新参数化。

```bash
python concat_alignments.py \
  --input-dir trimmed_alignment_dir \
  --suffix .trimmed.fa \
  --species-list species.list \
  --out-fasta supermatrix.fa \
  --out-partition partition.txt \
  --out-stats occupancy.tsv
```

`concat_alignments.py` 输出 FASTA、partition 和统计表；如需 PHYLIP，使用 AMAS 或其它格式转换工具。

AMAS 方案：

```bash
AMAS.py concat \
  -i trimmed_alignment_dir/*.fa \
  -f fasta \
  -d aa \
  -t supermatrix.fa \
  -p partition.txt \
  -u phylip
```

检查项：

```text
1. 所有预期物种是否都在 supermatrix 中。
2. 每个物种缺失比例是否统计。
3. 最终基因数量和矩阵长度是否记录。
```

---

## 8.7 RAxML 建树

历史脚本中最稳定的 RAxML 模板如下：

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

参数说明：

```text
-T 60           线程数
-f a            rapid bootstrap + best ML tree
-# 500          bootstrap 次数
-m PROTCATGTR   蛋白模型
-p 12345        parsimony random seed
-x 12345        bootstrap random seed
-n              输出名称
-s              输入 PHYLIP 比对
```

可选模型：

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

检查项：

```text
1. 500 次 bootstrap 是否完成。
2. bestTree、bootstrap、bipartitions 文件是否生成。
3. 物种名称是否与后续 CAFE / 绘图一致。
```

---

## 8.8 IQ-TREE 可选建树

```bash
iqtree2 \
  -s supermatrix.fa \
  -m MFP \
  -bb 2000 \
  -T 20
```

传统 bootstrap：

```bash
iqtree2 \
  -s supermatrix.fa \
  -m MFP \
  -b 500 \
  -T 20
```

---

## 8.9 MrBayes 贝叶斯树

历史目录未确认可靠完整模板，因此需要单独写参数并记录收敛情况。

NEXUS 模板：

```nexus
#NEXUS

begin data;
  dimensions ntax=4 nchar=100000;
  format datatype=protein gap=- missing=?;
  matrix
  Arabidopsis_thaliana  MAA...
  Arabidopsis_lyrata    MAA...
  Arabidopsis_halleri   MAA...
  Arabidopsis_suecica   MAA...
  ;
end;

begin mrbayes;
  set autoclose=yes nowarn=yes;
  lset rates=gamma;
  prset aamodelpr=mixed;
  mcmc ngen=5000000 samplefreq=1000 printfreq=1000 nchains=4 diagnfreq=5000 burninfrac=0.25;
  sump burnin=1250;
  sumt burnin=1250;
end;
```

检查项：

```text
1. 平均分裂频率标准差。
2. ESS 或同类收敛指标。
3. burn-in 设置。
4. posterior probability。
5. 若任务过慢，需记录中止原因。
```

---

## 8.10 单基因 / 基因家族树构建

### 目的

对目标基因家族、扩张基因家族、候选功能基因、共线性锚定基因或特定 orthogroup 构建 gene tree。基因树与物种树不同：物种树通常使用严格单拷贝基因串联矩阵；基因树通常保留同一基因家族中的多个 paralog，用于判断复制、丢失、扩张分支、ortholog/paralog 关系和候选基因演化。

### 当前 SOP 里已有的基因树相关细节

当前已经写了这些基础环节：

```text
1. OrthoFinder 产生 Orthogroups.tsv、GeneCount.tsv 和单拷贝基因列表。
2. MAFFT 用 `--maxiterate 1000 --localpair --thread 2 --anysymbol` 做蛋白比对。
3. seqkit `seq -w 0` 去换行。
4. trimAl 或历史 trim 脚本做比对修剪。
5. RAxML / IQ-TREE 可用于树构建。
```

但这些只够支撑“单拷贝串联物种树”，不够支撑“逐个基因家族建树”。因此基因树需要补充以下完整流程。

---

### 8.10.1 选择需要建树的基因家族

#### 输入来源

```text
Orthogroups.tsv
Orthogroups.GeneCount.tsv
functional_annotation.tsv
expanded_family_list.tsv
contracted_family_list.tsv
candidate_gene_list.tsv
Pfam/domain target list
```

#### 常见选择方式

```text
1. 从 CAFE 扩张结果中选择显著扩张 orthogroup。
2. 从 functional_annotation.tsv 中选择含目标 Pfam / KO / keyword 的基因。
3. 从某个候选基因列表反查所属 orthogroup。
4. 从 OrthoFinder 中选择某个 orthogroup ID，例如 OG0000001。
5. 对所有 orthogroup 批量建树，但只建议在算力足够且有明确用途时执行。
```

#### 输出

```text
target_orthogroups.list
candidate_gene_to_orthogroup.tsv
```

#### 输出后处理成下一步输入

`target_orthogroups.list` 一行一个 orthogroup ID，用于从 OrthoFinder 结果或蛋白总库中提取每个家族的蛋白序列。

示例：

```text
OG0000001
OG0000123
OG0000456
```

---

### 8.10.2 功能注释驱动的基因树入口

### 目的

除了从 OrthoFinder 的 orthogroup 出发，也可以根据功能注释结果构建“某功能基因 + 外群同源基因 + marker/MAKER 基因”的基因树。这类树常用于验证目标功能基因的来源、复制关系、是否与已知 marker 基因聚在一起，以及候选基因是否属于目标功能分支。

这里的 `marker/MAKER 基因` 指用户指定的参考基因、已知功能 marker、MAKER 注释得到的目标基因或人工整理的关键基因集合。最终目标是把这些序列与目标物种中的候选功能基因、外群同源基因合并成一个 FASTA，再按基因树流程比对和建树。

#### 输入来源

```text
functional_annotation.tsv
Arabidopsis_thaliana.protein.primary.fa
Arabidopsis_lyrata.protein.primary.fa
outgroup.protein.fa
marker_or_maker_genes.pep.fa
Pfam target list
KO target list
keyword target list
candidate_gene_list.tsv
```

#### 目标功能基因筛选方式

按 Pfam：

```bash
python select_genes_by_function.py \
  --annotation Arabidopsis_thaliana.functional_annotation.tsv \
  --pfam PF00001,PF00002 \
  --out Arabidopsis_thaliana.target_function.ids
```

按 KO：

```bash
python select_genes_by_function.py \
  --annotation Arabidopsis_thaliana.functional_annotation.tsv \
  --ko K00001,K00002 \
  --out Arabidopsis_thaliana.target_function.ids
```

按关键词：

```bash
python select_genes_by_function.py \
  --annotation Arabidopsis_thaliana.functional_annotation.tsv \
  --keyword "methyltransferase" \
  --out Arabidopsis_thaliana.target_function.ids
```

按用户候选基因列表：

```bash
cut -f1 candidate_gene_list.tsv \
  > Arabidopsis_thaliana.target_function.ids
```

#### 输出

```text
Arabidopsis_thaliana.target_function.ids
```

#### 输出后处理成下一步输入

用候选 ID 从目标物种 protein primary FASTA 中提取序列：

```bash
seqkit grep \
  -f Arabidopsis_thaliana.target_function.ids \
  Arabidopsis_thaliana.protein.primary.fa \
  > gene_tree/function_tree/Arabidopsis_thaliana.target_function.pep.fa
```

---

### 8.10.3 外群同源基因准备

#### 目的

外群序列用于给基因树提供参照分支，帮助判断目标基因家族的深层关系和 root 方向。外群可以来自外群物种蛋白组、数据库下载的已知 homolog，或人工整理的参考序列。

#### 方式 A：外群已有明确基因 ID

```bash
seqkit grep \
  -f outgroup_target_gene.ids \
  outgroup.protein.fa \
  > gene_tree/function_tree/outgroup.target_function.pep.fa
```

#### 方式 B：用目标功能基因搜索外群蛋白库

建立外群库：

```bash
diamond makedb \
  --in outgroup.protein.fa \
  --db outgroup.protein
```

目标基因搜索外群：

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

提取外群 best hits 或 top hits：

```bash
python select_blast_hits.py \
  --blast gene_tree/function_tree/target_vs_outgroup.diamond.tsv \
  --mode top_per_query \
  --top 5 \
  --out gene_tree/function_tree/outgroup_target_gene.ids
```

提取外群序列：

```bash
seqkit grep \
  -f gene_tree/function_tree/outgroup_target_gene.ids \
  outgroup.protein.fa \
  > gene_tree/function_tree/outgroup.target_function.pep.fa
```

#### 输出

```text
gene_tree/function_tree/outgroup.target_function.pep.fa
gene_tree/function_tree/outgroup_target_gene.ids
```

#### 输出后处理成下一步输入

外群序列与目标功能基因、marker/MAKER 基因合并成一个建树 FASTA。

---

### 8.10.4 marker / MAKER 基因准备

#### 目的

将已知功能 marker、MAKER 注释得到的目标基因或人工校正基因加入基因树，用作功能分支参照或候选基因验证。

#### 输入形式

```text
marker_or_maker_genes.pep.fa
marker_or_maker_gene.ids
marker_or_maker_annotation.tsv
```

#### 如果已有 marker/MAKER 蛋白 FASTA

```bash
seqkit seq \
  -w 0 \
  marker_or_maker_genes.pep.fa \
  > gene_tree/function_tree/marker_or_maker_genes.clean.pep.fa
```

#### 如果只有 marker/MAKER 基因 ID

```bash
seqkit grep \
  -f marker_or_maker_gene.ids \
  Arabidopsis_thaliana.protein.primary.fa \
  > gene_tree/function_tree/marker_or_maker_genes.clean.pep.fa
```

#### 输出

```text
gene_tree/function_tree/marker_or_maker_genes.clean.pep.fa
```

#### 检查项

```text
1. marker/MAKER 序列 header 应清楚标明来源。
2. 如果 marker 来自外部数据库，应记录 accession 和功能描述。
3. 如果 marker 来自 MAKER 注释，应确认其 genome/GFF 版本。
4. marker 不应与目标功能基因重复；若重复，应在 ID map 中标记。
```

---

### 8.10.5 合并功能基因、外群和 marker/MAKER 序列

#### 合并 FASTA

```bash
cat \
  gene_tree/function_tree/Arabidopsis_thaliana.target_function.pep.fa \
  gene_tree/function_tree/outgroup.target_function.pep.fa \
  gene_tree/function_tree/marker_or_maker_genes.clean.pep.fa \
  > gene_tree/function_tree/target_function.with_outgroup_marker.pep.fa
```

#### 去除重复序列 ID

```bash
seqkit rmdup \
  -n \
  gene_tree/function_tree/target_function.with_outgroup_marker.pep.fa \
  > gene_tree/function_tree/target_function.with_outgroup_marker.nr.pep.fa
```

#### 建立 tip 注释表

```bash
python build_function_tree_tip_table.py \
  --target-ids Arabidopsis_thaliana.target_function.ids \
  --outgroup-ids gene_tree/function_tree/outgroup_target_gene.ids \
  --marker-fasta gene_tree/function_tree/marker_or_maker_genes.clean.pep.fa \
  --functional-annotation Arabidopsis_thaliana.functional_annotation.tsv \
  --out gene_tree/function_tree/target_function.tip_annotation.tsv
```

推荐字段：

```text
tip_id
source_group
species
transcript_id
gene_id
function_source
Pfam_ids
KO_ids
marker_name
note
```

#### 输出

```text
gene_tree/function_tree/target_function.with_outgroup_marker.nr.pep.fa
gene_tree/function_tree/target_function.tip_annotation.tsv
```

#### 输出后处理成下一步输入

合并后的非冗余 FASTA 进入 MAFFT 比对；tip annotation 用于树重命名和绘图上色。

#### 检查项

```text
1. 合并后 FASTA 至少包含目标基因、外群基因和 marker/MAKER 基因三类序列。
2. 序列 ID 不重复。
3. 外群序列不能过多，否则会压缩目标分支可读性。
4. marker/MAKER 基因如果与目标基因重复，应只保留一个序列并在注释表中保留双重来源。
```

---

### 8.10.6 功能驱动基因树的比对和建树

#### MAFFT

```bash
mafft \
  --maxiterate 1000 \
  --localpair \
  --thread 4 \
  --anysymbol \
  gene_tree/function_tree/target_function.with_outgroup_marker.nr.pep.fa \
  > gene_tree/function_tree/target_function.aln.fa
```

#### 修剪

```bash
trimal \
  -in gene_tree/function_tree/target_function.aln.fa \
  -out gene_tree/function_tree/target_function.trimmed.fa \
  -automated1
```

#### IQ-TREE

```bash
iqtree2 \
  -s gene_tree/function_tree/target_function.trimmed.fa \
  -m MFP \
  -bb 1000 \
  -alrt 1000 \
  -T 4 \
  --prefix gene_tree/function_tree/target_function
```

#### tip 重命名

```bash
python rename_tree_tips.py \
  --tree gene_tree/function_tree/target_function.treefile \
  --tip-annotation gene_tree/function_tree/target_function.tip_annotation.tsv \
  --out gene_tree/function_tree/target_function.renamed.tree
```

#### 可选 rooting handoff

`root_tree.py` 只复制 tree 并写出 rooting note，不执行真实 Newick reroot；需要真正定根时使用 ETE、Newick utilities、FigTree 或其它经过验证的树工具。

如果外群明确，可先生成 handoff 文件：

```bash
python root_tree.py \
  --tree gene_tree/function_tree/target_function.renamed.tree \
  --outgroup-file gene_tree/function_tree/outgroup_target_gene.ids \
  --out gene_tree/function_tree/target_function.rooting_handoff.tree
```

#### 输出

```text
target_function.aln.fa
target_function.trimmed.fa
target_function.treefile
target_function.renamed.tree
target_function.rooting_handoff.tree，可选；真实 rooted tree 需由外部树工具生成
target_function.iqtree
target_function.tip_annotation.tsv
```

#### 输出后处理成下一步输入

```text
renamed tree / externally rooted tree → ggtree / iTOL / FigTree 出图
tip_annotation.tsv → 颜色、分组、功能标签
target_function.iqtree → 模型和支持值记录
```

---

### 8.10.7 功能驱动基因树解释要点

```text
1. 目标功能基因是否与已知 marker/MAKER 基因聚成同一分支。
2. 目标物种内是否出现 lineage-specific duplication。
3. 外群基因是否位于合理外部分支。
4. 候选基因如果不与 marker 聚类，需要回查功能注释是否误注释。
5. 分支支持值低时，不应强解释复制/丢失关系。
6. 如果功能基因来自多 domain 家族，建议按 domain 组合进一步筛选后重建树。
```

---

### 8.10.8 准备全物种 protein primary 库

#### 输入

```text
Arabidopsis_thaliana.protein.primary.fa
Arabidopsis_lyrata.protein.primary.fa
Arabidopsis_halleri.protein.primary.fa
Arabidopsis_suecica.protein.primary.fa
```

#### 处理

为避免不同物种 gene ID 重名，建议在 FASTA header 前加 species 前缀。格式推荐：

```text
>Arabidopsis_thaliana|Ath.t000001
>Arabidopsis_lyrata|Aly.t000001
```

命令模板：

```bash
python prefix_fasta_ids.py \
  --input Arabidopsis_thaliana.protein.primary.fa \
  --prefix Arabidopsis_thaliana \
  --sep '|' \
  --out Arabidopsis_thaliana.protein.primary.prefixed.fa \
  --map Arabidopsis_thaliana.species_gene_id_map.tsv
```

合并所有物种蛋白：

```bash
cat \
  Arabidopsis_thaliana.protein.primary.prefixed.fa \
  Arabidopsis_lyrata.protein.primary.prefixed.fa \
  Arabidopsis_halleri.protein.primary.prefixed.fa \
  Arabidopsis_suecica.protein.primary.prefixed.fa \
  > all_species.protein.primary.prefixed.fa
```

建立 ID 索引：

```bash
seqkit fx2tab \
  -n \
  all_species.protein.primary.prefixed.fa \
  > all_species.protein.primary.prefixed.ids
```

#### 输出

```text
all_species.protein.primary.prefixed.fa
all_species.protein.primary.prefixed.ids
species_gene_id_map.tsv
```

#### 输出后处理成下一步输入

`all_species.protein.primary.prefixed.fa` 作为每个 orthogroup 提取序列的总蛋白库；`species_gene_id_map.tsv` 用于把树 tip 名称追溯回原始 gene/transcript ID 和功能注释。

#### 检查项

```text
1. FASTA header 不应含空格。
2. 不同物种之间 ID 不应重复。
3. prefix 后的 ID 必须能回溯到原始 transcript_id。
4. protein 应来自 gff-cds-pep 过滤后的 primary peptide。
```

---

### 8.10.9 从 Orthogroups.tsv 提取每个家族成员

#### 输入

```text
Orthogroups.tsv
target_orthogroups.list
all_species.protein.primary.prefixed.fa
species_gene_id_map.tsv
```

#### 处理

从 `Orthogroups.tsv` 中提取目标 orthogroup 的成员，整理为每个家族一个 gene ID list。

命令模板：

```bash
python extract_orthogroup_members.py \
  --orthogroups Orthogroups.tsv \
  --target-list target_orthogroups.list \
  --id-map species_gene_id_map.tsv \
  --outdir gene_tree/01_member_lists
```

每个输出文件示例：

```text
gene_tree/01_member_lists/OG0000001.ids
gene_tree/01_member_lists/OG0000123.ids
```

#### 输出后处理成下一步输入

每个 `.ids` 文件用于从 `all_species.protein.primary.prefixed.fa` 中提取对应家族的 protein FASTA。

提取序列：

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

#### 检查项

```text
1. 每个 `.ids` 文件不应为空。
2. seqkit grep 提取到的序列数应等于 `.ids` 行数。
3. 若提取数少于 ID 数，检查 OrthoFinder ID 与 protein.primary.fa ID 是否一致。
4. family tree 通常保留 paralog，不要强行每物种只留一条，除非目标是 ortholog tree。
```

---

### 8.10.10 gene family FASTA 质控

#### 输入

```text
gene_tree/02_family_fasta/OG0000001.pep.fa
```

#### 处理

统计每个家族序列数和长度：

```bash
seqkit stats \
  gene_tree/02_family_fasta/*.pep.fa \
  > gene_tree/02_family_fasta.stats.tsv
```

检查重复 ID：

```bash
for fa in gene_tree/02_family_fasta/*.pep.fa
do
  og=$(basename "$fa" .pep.fa)
  seqkit fx2tab -n "$fa" | sort | uniq -d > gene_tree/02_family_fasta/${og}.duplicate_ids.txt
done
```

清理蛋白序列中末端终止符号，内部终止应在 gff-cds-pep 阶段已过滤：

```bash
python clean_pep_for_tree.py \
  --input gene_tree/02_family_fasta/OG0000001.pep.fa \
  --remove-terminal-stop \
  --out gene_tree/02_family_fasta/OG0000001.clean.pep.fa
```

批量清理：

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

#### 输出

```text
gene_tree/02_family_fasta/OG0000001.clean.pep.fa
gene_tree/02_family_fasta.stats.tsv
```

#### 输出后处理成下一步输入

`.clean.pep.fa` 进入 MAFFT 多序列比对。

#### 过滤建议

```text
1. 序列数 < 3 的家族通常不建树。
2. 序列过短的家族应记录并跳过。
3. 含大量 X 或异常长/短序列的家族应单独标记。
4. 内部 stop codon 不建议直接替换，优先回查 CDS check 和注释来源。
```

---

### 8.10.11 MAFFT 多序列比对

#### 小到中等规模家族

```bash
mafft \
  --maxiterate 1000 \
  --localpair \
  --thread 2 \
  --anysymbol \
  gene_tree/02_family_fasta/OG0000001.clean.pep.fa \
  > gene_tree/03_alignment/OG0000001.aln.fa
```

#### 大家族快速模式

如果某个 orthogroup 序列很多，可使用更快模式：

```bash
mafft \
  --auto \
  --thread 4 \
  --anysymbol \
  gene_tree/02_family_fasta/OG0000001.clean.pep.fa \
  > gene_tree/03_alignment/OG0000001.aln.fa
```

#### 批量运行

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

#### 输出

```text
gene_tree/03_alignment/OG0000001.aln.fa
```

#### 输出后处理成下一步输入

比对结果进入去换行、修剪和 alignment 质量检查。

#### 检查项

```text
1. alignment 中序列数应等于输入 family FASTA 序列数。
2. 序列 ID 不应被 MAFFT 截断或改名。
3. 如果 MAFFT 失败，检查是否有空序列或非法字符。
```

---

### 8.10.12 比对去换行与修剪

#### 去换行

```bash
seqkit seq \
  -w 0 \
  gene_tree/03_alignment/OG0000001.aln.fa \
  > gene_tree/03_alignment/OG0000001.aln.link.fa
```

#### trimAl 自动修剪

```bash
trimal \
  -in gene_tree/03_alignment/OG0000001.aln.link.fa \
  -out gene_tree/04_trimmed/OG0000001.trimmed.fa \
  -automated1
```

#### 或按 gap 阈值修剪

```bash
trimal \
  -in gene_tree/03_alignment/OG0000001.aln.link.fa \
  -out gene_tree/04_trimmed/OG0000001.trimmed.fa \
  -gt 0.5
```

#### 输出后统计

```bash
seqkit stats \
  gene_tree/04_trimmed/OG0000001.trimmed.fa \
  > gene_tree/04_trimmed/OG0000001.trimmed.stats.txt
```

#### 输出

```text
gene_tree/04_trimmed/OG0000001.trimmed.fa
```

#### 输出后处理成下一步输入

`trimmed.fa` 进入 IQ-TREE 或 RAxML 建树。

#### 检查项

```text
1. 修剪后 alignment 长度不能过短。
2. 修剪后序列数不能减少，除非修剪软件显式删除全 gap 序列。
3. 若修剪后长度 < 30 aa，建议跳过该家族树。
4. 保留 raw alignment 和 trimmed alignment，便于回查。
```

---

### 8.10.13 IQ-TREE 构建基因树，推荐

#### 目的

对每个基因家族 alignment 自动选择模型并构建 ML gene tree，适合大批量基因家族树。

#### 单个家族

```bash
iqtree2 \
  -s gene_tree/04_trimmed/OG0000001.trimmed.fa \
  -m MFP \
  -bb 1000 \
  -alrt 1000 \
  -T 4 \
  --prefix gene_tree/05_tree/OG0000001
```

#### 大批量可降低支持计算

```bash
iqtree2 \
  -s gene_tree/04_trimmed/OG0000001.trimmed.fa \
  -m MFP \
  -B 1000 \
  -T 4 \
  --prefix gene_tree/05_tree/OG0000001
```

#### 输出

```text
gene_tree/05_tree/OG0000001.treefile
gene_tree/05_tree/OG0000001.iqtree
gene_tree/05_tree/OG0000001.log
gene_tree/05_tree/OG0000001.contree
gene_tree/05_tree/OG0000001.splits.nex
```

#### 输出后处理成下一步输入

`*.treefile` 是最终基因树，进入树重命名、root、可视化、基因复制解释和家族演化分析。

#### 检查项

```text
1. `.treefile` 必须存在且非空。
2. `.iqtree` 中记录最佳模型和支持值设置。
3. tree tips 数量应等于 trimmed alignment 序列数。
4. ultrafast bootstrap / SH-aLRT 支持值是否写入节点。
```

---

### 8.10.14 RAxML 构建基因树，可选兼容历史流程

#### 单个家族

```bash
raxmlHPC-PTHREADS-SSE3 \
  -T 4 \
  -f a \
  -# 100 \
  -m PROTCATGTR \
  -p 12345 \
  -x 12345 \
  -n OG0000001.PROTCATGTR \
  -s gene_tree/04_trimmed/OG0000001.trimmed.phy
```

如果需要将 FASTA 转 PHYLIP：

```bash
seqmagick convert \
  gene_tree/04_trimmed/OG0000001.trimmed.fa \
  gene_tree/04_trimmed/OG0000001.trimmed.phy
```

#### 输出

```text
RAxML_bestTree.OG0000001.PROTCATGTR
RAxML_bootstrap.OG0000001.PROTCATGTR
RAxML_bipartitions.OG0000001.PROTCATGTR
RAxML_info.OG0000001.PROTCATGTR
```

#### 输出后处理成下一步输入

`RAxML_bipartitions.*` 通常作为带 bootstrap 支持的最终树文件。

#### 检查项

```text
1. 小家族树不一定需要 500 bootstrap，可按项目要求设置 100/500。
2. PHYLIP 名称长度和重复 ID 可能导致失败，需提前检查。
3. 如果要与历史方法一致，可统一用 PROTCATGTR。
```

---

### 8.10.15 基因树批量运行与失败记录

#### 批量 IQ-TREE 模板

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

#### 汇总成功树列表

```bash
find gene_tree/05_tree \
  -name "*.treefile" \
  | sort \
  > gene_tree/gene_tree.list
```

#### 输出

```text
gene_tree/gene_tree.list
gene_tree/06_failed/failed.tsv
```

#### 输出后处理成下一步输入

`gene_tree.list` 用于批量可视化、复制事件分析或与 orthogroup 功能注释合并；`failed.tsv` 用于记录哪些家族没有树以及原因。

---

### 8.10.16 tree tip 重命名、root 和可视化准备

#### 目的

把树上的 transcript_id 转换成更可读但仍可追溯的名称，例如 `Arabidopsis_thaliana|Ath.t000001|gene_symbol`。如果没有 gene symbol，则保留 `species|transcript_id`。

#### 生成 tip 注释表

```bash
python make_tree_tip_annotation.py \
  --functional-annotation Arabidopsis_thaliana.functional_annotation.tsv \
  --id-map species_gene_id_map.tsv \
  --out gene_tree/tree_tip_annotation.tsv
```

推荐字段：

```text
tip_id
species
transcript_id
gene_id
symbol
Pfam_ids
KEGG_ko
SwissProt_description
orthogroup
```

#### 重命名树 tip

```bash
python rename_tree_tips.py \
  --tree gene_tree/05_tree/OG0000001.treefile \
  --tip-annotation gene_tree/tree_tip_annotation.tsv \
  --out gene_tree/07_renamed_tree/OG0000001.renamed.tree
```

#### rooting handoff，可选

`root_tree.py` 只复制 tree 并写出 rooting note，不执行真实 Newick reroot；需要真正定根时使用 ETE、Newick utilities、FigTree 或其它经过验证的树工具。

如果有明确 outgroup，可先生成 handoff 文件：

```bash
python root_tree.py \
  --tree gene_tree/07_renamed_tree/OG0000001.renamed.tree \
  --outgroup Arabidopsis_suecica \
  --out gene_tree/08_rooting_handoff/OG0000001.rooting_handoff.tree
```

如果没有明确 outgroup，保留 unrooted tree，并在图注说明。

#### 输出后处理成下一步输入

```text
renamed tree / externally rooted tree → iTOL / ggtree / FigTree 绘图
tree_tip_annotation.tsv → 给树叶标注功能、物种、分支颜色
```

#### 检查项

```text
1. 重命名前后 tip 数量一致。
2. 真实 reroot 只在有明确 outgroup 时用外部树工具进行；`root_tree.py` 仅生成 handoff。
3. 任何被删除的 tip 都必须有记录。
```

---

### 8.10.17 基因树结果汇总

#### 目的

将每个家族的成员数、物种分布、alignment 长度、模型、树文件、失败原因和功能注释汇总成表。

#### 命令模板

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

#### 推荐字段

```text
orthogroup
family_size
species_count
species_with_copies
alignment_length
trimmed_alignment_length
best_model
bootstrap_type
tree_file
rooted_tree_file
main_function
Pfam_ids
KEGG_ko
status
failed_reason
```

#### 输出后处理成下一步输入

```text
gene_tree_summary.tsv → 扩张家族解释、候选基因树筛选、图表清单
gene_tree/*.treefile → 单基因家族图
tree_tip_annotation.tsv → 树图标注
```

#### 检查项

```text
1. 每个 target orthogroup 都应有 success 或 failed 记录。
2. family_size 与 Orthogroups.tsv 成员数一致。
3. tree tips 与 alignment sequences 一致。
4. 绘图用树和原始树都要保留。
```

---

### 8.10.18 基因树与下游分析衔接

| 基因树输出 | 处理方式 | 下游用途 |
|---|---|---|
| `OG*.treefile` | 保留原始 ML tree | 基因家族拓扑解释 |
| `OG*.renamed.tree` | tip 加物种和功能标签 | 出图和人工检查 |
| `OG*.rooted.tree` | 有 outgroup 时由外部树工具定根 | 复制/丢失方向解释 |
| `tree_tip_annotation.tsv` | 连接功能注释和 tip | ggtree/iTOL 颜色与标签 |
| `gene_tree_summary.tsv` | 汇总树质量和功能 | 决定哪些树进入正文/补图 |
| `failed.tsv` | 记录失败原因 | 方法补充和结果审计 |

### 最低交付要求

```text
1. 每个目标 orthogroup 的 family FASTA。
2. 每个目标 orthogroup 的 raw alignment。
3. 每个目标 orthogroup 的 trimmed alignment。
4. 每个成功家族的 treefile。
5. 每个家族的成员/物种/功能汇总。
6. 失败家族列表和失败原因。
7. 用于绘图的 renamed/rooted tree 和 tip annotation。
```

---

## 8.11 CAFE 扩张收缩

历史目录未确认完整可复用 CAFE 命令，因此建议重新写配置。

### OrthoFinder count matrix 转换

```bash
python prepare_cafe_input.py \
  --orthofinder-count Orthogroups.GeneCount.tsv \
  --species-tree species_tree.nwk \
  --out cafe_input.tsv
```

### 过滤极端家族

```bash
python filter_cafe_families.py \
  --input cafe_input.tsv \
  --max-copy 100 \
  --min-species 2 \
  --remove-all-zero \
  --out cafe_input.filtered.tsv \
  --removed cafe_input.removed.tsv
```

### CAFE5

```bash
cafe5 \
  -i cafe_input.filtered.tsv \
  -t ultrametric_tree.nwk \
  -o cafe_result \
  -k 3 \
  -p 0.05
```

旧版 CAFE 配置：

```text
load -i cafe_input.filtered.tsv -t 10 -l cafe.log
tree (((Arabidopsis_thaliana:1,Arabidopsis_lyrata:1):1,Arabidopsis_halleri:2):1,Arabidopsis_suecica:3);
lambda -s
report cafe_report
```

运行：

```bash
cafe cafe.config
```

检查项：

```text
1. tree 中物种名与 count matrix 表头完全一致。
2. 是否需要 ultrametric tree。
3. 是否有时间校准信息。
4. 扩张 / 收缩显著性阈值是否记录。
```

---

# Part IX. 共线性、dotplot 与 Circos

## 9.1 genome-level dotplot：minimap2 + dotPlotly

### minimap2

```bash
minimap2 \
  -x asm20 \
  -t 20 \
  Arabidopsis_thaliana.genome.fa \
  Arabidopsis_lyrata.genome.fa \
  > Arabidopsis_thaliana_vs_Arabidopsis_lyrata.paf
```

近缘比较可测试：

```bash
minimap2 \
  -x asm5 \
  -t 20 \
  Arabidopsis_thaliana.genome.fa \
  Arabidopsis_lyrata.genome.fa \
  > Arabidopsis_thaliana_vs_Arabidopsis_lyrata.asm5.paf
```

中等差异：

```bash
minimap2 \
  -x asm10 \
  -t 20 \
  Arabidopsis_thaliana.genome.fa \
  Arabidopsis_lyrata.genome.fa \
  > Arabidopsis_thaliana_vs_Arabidopsis_lyrata.asm10.paf
```

### dotPlotly

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

检查项：

```text
1. PAF 是否非空。
2. 过碎时调整 asm5 / asm10 / asm20。
3. 图中是否存在明显倒位、易位或错拼信号。
```

---

## 9.2 BLASTP / DIAMOND 相似性搜索

### BLASTP

```bash
makeblastdb \
  -in Arabidopsis_lyrata.protein.fa \
  -dbtype prot \
  -out Arabidopsis_lyrata.protein.db
```

```bash
blastp \
  -query Arabidopsis_thaliana.protein.fa \
  -db Arabidopsis_lyrata.protein.db \
  -out Arabidopsis_thaliana_vs_Arabidopsis_lyrata.blastp.tsv \
  -evalue 1e-5 \
  -outfmt 6 \
  -num_alignments 20 \
  -num_threads 50
```

### DIAMOND

```bash
diamond makedb \
  --in Arabidopsis_lyrata.protein.fa \
  --db Arabidopsis_lyrata.protein
```

```bash
diamond blastp \
  --query Arabidopsis_thaliana.protein.fa \
  --db Arabidopsis_lyrata.protein \
  --out Arabidopsis_thaliana_vs_Arabidopsis_lyrata.diamond.tsv \
  --threads 20 \
  --evalue 1e-5 \
  --max-target-seqs 20 \
  --outfmt 6 \
  --sensitive
```

---

## 9.3 WGDI dotplot

### GFF 转 WGDI 坐标

若 GFF 第三列为 `mRNA`：

```bash
awk '$3=="mRNA" {print $1"\t"$4"\t"$5"\t"$9}' Arabidopsis_thaliana.annotation.gff3 > Arabidopsis_thaliana.wgdi.gff
```

若 GFF 第三列为 `gene`：

```bash
awk '$3=="gene" {print $1"\t"$4"\t"$5"\t"$9}' Arabidopsis_thaliana.annotation.gff3 > Arabidopsis_thaliana.wgdi.gff
```

### WGDI 配置

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

### 运行

```bash
wgdi \
  -d Arabidopsis_thaliana_vs_Arabidopsis_lyrata.conf
```

检查项：

```text
1. protein ID、GFF ID、BLAST ID 是否一致。
2. feature 类型是 gene、mRNA 还是 CDS。
3. lens 文件中染色体顺序是否正确。
```

---

## 9.4 MCScanX

### 准备 BLAST

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

### 准备 GFF

```bash
awk '$3=="gene" {split($9,a,";"); print $1"\t"a[1]"\t"$4"\t"$5}' Arabidopsis_all.annotation.gff3 > Arabidopsis_all.gff
```

### 运行

```bash
MCScanX Arabidopsis_all
```

检查项：

```text
1. Arabidopsis_all.blast 和 Arabidopsis_all.gff 前缀必须一致。
2. GFF 第二列 gene ID 要与 BLAST 中蛋白 ID 可对应。
3. .collinearity 文件是否非空。
```

---

## 9.5 JCVI 可选流程

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

```bash
python3 -m jcvi.graphics.karyotype \
  seqids \
  layout
```

---

## 9.6 Circos

### 配置骨架

建议保留历史 Circos 模板结构，但所有数据文件需重新生成。

```text
circos.conf
histogram.conf
link.conf
colors.conf
etc/ideogram.conf
etc/ticks.conf
etc/image.conf
etc/housekeeping.conf
data/genome_karyotype.txt
data/block_link.txt
```

### karyotype

```bash
samtools faidx Arabidopsis_thaliana.genome.fa
```

```bash
awk '{print "chr - "$1" "$1" 0 "$2" Arabidopsis_thaliana"}' Arabidopsis_thaliana.genome.fa.fai > genome_karyotype.txt
```

### GC track

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

### gene density

```bash
awk '$3=="gene" {print $1"\t"$4-1"\t"$5}' Arabidopsis_thaliana.annotation.gff3 > Arabidopsis_thaliana.gene.bed
```

```bash
bedtools coverage \
  -a Arabidopsis_thaliana.windows.bed \
  -b Arabidopsis_thaliana.gene.bed \
  > Arabidopsis_thaliana.gene_density.raw.tsv
```

### repeat density

```bash
bedtools coverage \
  -a Arabidopsis_thaliana.windows.bed \
  -b Arabidopsis_thaliana.repeat.gff \
  > Arabidopsis_thaliana.repeat_density.raw.tsv
```

### short intron density

```bash
python extract_introns.py \
  --gff Arabidopsis_thaliana.annotation.gff3 \
  --out Arabidopsis_thaliana.intron.bed
```

```bash
awk '($3-$2)>=40 && ($3-$2)<=65' Arabidopsis_thaliana.intron.bed > Arabidopsis_thaliana.short_intron_40_65bp.bed
```

```bash
bedtools coverage \
  -a Arabidopsis_thaliana.windows.bed \
  -b Arabidopsis_thaliana.short_intron_40_65bp.bed \
  > Arabidopsis_thaliana.short_intron_density.raw.tsv
```

### synteny links

```bash
python anchors_to_circos_links.py \
  --anchors Arabidopsis_thaliana_vs_Arabidopsis_lyrata.anchors \
  --gff Arabidopsis_gene_coordinate.tsv \
  --out block_link.txt
```

### 渲染

```bash
circos \
  -conf circos.conf
```

检查项：

```text
1. 所有 track 坐标不得超过染色体长度。
2. karyotype 中的 chr ID 必须与 track 文件一致。
3. links 两端 ID 必须存在于 karyotype。
4. 历史模板中的旧颜色、旧分组、旧路径必须全部替换。
```

---

# Part X. Domain / Pfam 统计

## 10.1 Pfam count matrix

### 目的

从 InterProScan 结果中提取 Pfam 命中，构建物种 × Pfam 矩阵。

### 输入格式

历史 `.iprscan.xls` 通常包含类似字段：

```text
Query_id
Subject_id
Subject_DB
Query_start
Query_end
E_value
Subject_annotation
```

### 统计规则

```text
1. 读取 InterProScan 表格。
2. 保留 Subject_DB == Pfam 的记录。
3. 使用 Subject_id 作为 Pfam accession。
4. 按 species × Pfam accession 计数。
5. 输出 Excel，包括 pfam_count、input_status、pfam_description。
```

### Python 模板

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

检查项：

```text
1. Excel 是否可打开。
2. 矩阵列是否为预期物种。
3. 缺失文件只记录，不应静默跳过。
4. 统计的是 Pfam hit count，不等同于基因家族拷贝数。
```

---

# Part XI. 异常染色体 / 特殊区域证据整合

## 11.1 证据指标

```text
chromosome_or_scaffold
length
GC_content
gene_density
repeat_density
intron_density
short_intron_40_65bp_density
AT_rich_intron_ratio
synteny_block_count
anchor_gene_count
synteny_coverage
unknown_gene_ratio
domain_feature
HGT_candidate_count
expression_summary
special_chromosome_flag
missing_data_note
```

## 11.2 原则

```text
1. 不能只凭一个指标判定特殊染色体或异常区域。
2. 缺失的表达、HGT、TE、GEVE 数据应标记为 missing，而不是解释为 absence。
3. 所有证据应能追溯到具体统计表或图。
4. Circos、dotplot、domain 和注释表之间的 chromosome ID 必须一致。
```

---

# Part XII. 历史脚本复用原则

## 12.1 可以复用的内容

```text
1. 软件选择。
2. 关键参数。
3. 输入输出逻辑。
4. 文件格式转换思路。
5. 统计指标定义。
6. 绘图配置结构。
```

## 12.2 不应直接复用的内容

```text
1. 绝对路径。
2. 真实物种名。
3. 项目名。
4. 旧软件安装路径。
5. 写死的染色体 ID。
6. 写死的物种数量。
7. 写死的文件名列表。
8. 旧项目特有颜色和分组。
9. 未确认行为的自定义脚本。
```

## 12.3 最小交付清单

```text
1. SOP 主文。
2. 软件清单。
3. Command reference.
4. 输入文件检查表。
5. 输出结果检查表。
6. 每一步关键参数记录。
7. 每一步质控结果记录。
```
