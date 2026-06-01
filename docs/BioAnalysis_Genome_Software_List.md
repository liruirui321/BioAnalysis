# BioAnalysis Genome Workflow Software Reference

This document lists the software, databases, workflow scripts, key parameters and runtime notes used by the BioAnalysis genome workflow.

---

## 1. 组装相关软件

| 软件 | 用途 | 典型参数 / 命令要点 | 注意事项 |
|---|---|---|---|
| hifiasm | HiFi / ONT 长读长组装；可结合 Hi-C 做 phased assembly | `-o` 输出前缀；`-t` 线程；`--ont` ONT reads；`--h1/--h2` Hi-C reads；`--n-hap` haplotype 数量 | GFA 需转换为 FASTA；需检查 primary/hap 输出类型 |
| NextDenovo | ONT / PacBio 长读长纠错与组装 | `nextDenovo run.cfg`；配置中设 `genome_size`、`read_type`、`parallel_jobs`、`minimap2_options_raw` | run.cfg 中 genome size 和 read type 必须准确 |
| SPAdes | 小基因组、细胞器、局部组装或混合组装 | `-1/-2` 双端 reads；`--nanopore` 长读长；`-k 21,45,65,85`；`--max_threads` | 不建议默认替代主核基因组组装 |
| Canu | 长读长组装或纠错 | `genomeSize=`；`-nanopore` 或 `-pacbio`；`maxThreads=`；`useGrid=false` | 对 genomeSize 敏感；运行时间较长 |

---

## 2. polish、去冗余与挂载

| 软件 | 用途 | 典型参数 / 命令要点 | 注意事项 |
|---|---|---|---|
| minimap2 | reads-to-assembly、assembly self-alignment、genome alignment | `-x map-pb`、`-x map-ont`、`-x asm5`、`-x asm10`、`-x asm20`、`-t` | preset 必须与数据类型匹配 |
| purge_dups | 去除 haplotig / 冗余 contig | `pbcstat`、`calcuts`、`split_fa`、`purge_dups -2 -T cutoffs -c PB.base.cov`、`get_seqs -e` | 去冗余结果需结合 BUSCO duplicated 和组装总长判断 |
| NextPolish | 组装 polish | `nextPolish config.cfg`；配置 `sgs_fofn`、`lgs_fofn`、`rerun`、`genome` | 每轮 polish 后应记录 BUSCO/Merqury 变化 |
| HiC-Pro | Hi-C reads 处理 | `digest_genome.py -r ^GATC`；`bowtie2-build`；`HiC-Pro -i -o -c` | 酶切位点必须与实验一致 |
| bowtie2 | Hi-C reads 比对索引 | `bowtie2-build genome.fa prefix` | 与 HiC-Pro 配置一致 |
| chromap | 快速 Hi-C 比对 | `--preset hic`；`-x` index；`-r` genome；`-1/-2` reads；`-t` | 输出 pairs/BAM 后需检查比对率 |
| HapHiC | Hi-C scaffolding / haplotype-aware 挂载 | `HapHiC pipeline assembly.fa hic.bam prefix --threads` | 需检查 heatmap 和染色体数 |

---

## 3. 组装质量评估软件

| 软件 | 用途 | 典型参数 / 命令要点 | 注意事项 |
|---|---|---|---|
| seqkit | FASTA/FASTQ 统计、序列格式处理 | `seqkit stats`；`seqkit seq -w 0`；`seqkit grep` | 常用于快速统计和去换行 |
| BUSCO | 基因组 / 蛋白完整性评估 | `-i` 输入；`-l embryophyta_odb10`；`-m geno/prot`；`--offline`；`-c` | lineage 要与类群匹配；duplicated 需谨慎解释 |
| compleasm | BUSCO lineage 完整性快速评估 | `compleasm.py run -a genome.fa -l lineage -o out -L lineage_dir -t`；`protein -p protein.fa` | 可与 BUSCO 互相验证 |
| meryl | k-mer database 构建 | `meryl count k=21 threads=20 output xxx.meryl reads/genome` | k 值应根据基因组大小和测序深度选择 |
| Merqury | k-mer 组装质量评估 | `merqury.sh reads.meryl assembly.fa prefix` | 输出 QV、completeness、spectra-cn |
| LTR_FINDER_parallel | LTR 候选识别 | `-seq genome.fa -threads 12 -harvest_out -size 1000000 -time 300` | LAI 前置步骤之一 |
| GenomeTools / LTRharvest | LTR 候选识别 | `gt suffixerator`；`gt ltrharvest -similar 85 -vic 10 -seed 20` | 可与 LTR_FINDER 结果合并 |
| LTR_retriever | 整理高置信 LTR | `-genome genome.fa -inharvest raw_ltr.scn -threads 12` | 输出 pass.list 和 LTR library |
| LAI | LTR Assembly Index 评估 | `LAI -genome genome.fa -intact genome.fa.pass.list -all genome.fa.out -t 20` | 不能单独运行；依赖 LTR_retriever 和 RepeatMasker 输出 |

---

## 4. 重复序列注释软件

| 软件 | 用途 | 典型参数 / 命令要点 | 注意事项 |
|---|---|---|---|
| seqkit | 重复注释前检查和转换 genome 序列大小写 | `seqkit seq -s genome.fa` 检查序列；`seqkit seq -u genome.fa > genome.upper.fa` 转大写 | FASTA ID 大小写不用处理；所有重复注释步骤使用同一份大写 genome |
| LTR_FINDER_parallel | LTR 候选识别 | `-seq genome.fa -threads 30 -harvest_out -size 1000000 -time 300` | 可与 RepeatModeler 并行；输出 `genome.fa.finder.combine.scn` |
| GenomeTools / LTRharvest | LTR 候选识别 | `gt suffixerator -db genome.fa -indexname genome.fa -tis -suf -lcp -des -ssp -sds -dna`；`gt ltrharvest -minlenltr 100 -maxlenltr 7000 -mintsd 4 -maxtsd 6 -motif TGCA -motifmis 1 -similar 85 -vic 10 -seed 20 -seqids yes` | 与 LTR_FINDER_parallel 结果合并后进入 LTR_retriever |
| LTR_retriever | 整合 LTR_FINDER 和 LTRharvest 候选，生成 LTR library | `cat genome.fa.harvest.scn genome.fa.finder.combine.scn > genome.fa.rawLTR.scn`；`LTR_retriever -genome genome.fa -inharvest genome.fa.rawLTR.scn -threads 12` | 需等 LTR_FINDER_parallel 和 LTRharvest 均完成；输出 `genome.fa.LTRlib.fa`、`pass.list`、`.out` |
| BuildDatabase | RepeatModeler 建库 | `BuildDatabase -name mydb genome.fa` | RepeatModeler 前置步骤 |
| RepeatModeler | de novo repeat library 构建 | `RepeatModeler -database mydb -threads 20` | 可与 LTR 流程并行；输出 known/unknown 或 classified repeat families |
| RepeatMasker | 全基因组重复序列注释和 mask | `RepeatMasker -lib known.library -pa 30 genome.fa -dir known`；`RepeatMasker -lib unknown.library -pa 30 genome.fa -dir unknown` | 需等 LTR_retriever 和 RepeatModeler 结果都完成后再运行；known/unknown 建议分开注释并合并 `.out` |
| rmout2gff.sh | RepeatMasker `.out` 转 GFF3 | `bash rmout2gff.sh repeatmasker.all.out > repeatmasker.all.gff3` | 供 Circos、窗口统计和浏览器展示使用 |
| bedtools | 窗口统计 repeat/gene/intron density 和分类非冗余覆盖 | `makewindows`、`coverage`、`merge`、`nuc` | 注意坐标体系和窗口大小 |
| samtools faidx | 生成 genome FASTA index | `samtools faidx genome.fa` | Circos、窗口统计常用 |
| TRF / trf2gff | tandem repeat 可选补充注释 | `trf genome.fa 2 5 7 80 10 50 2000 -d -h`；`trf2gff` | 可作为 tandem/simple repeat 补充，不替代 RepeatMasker |

未稳定确认但可按项目需要补充：

```text
EDTA
RepeatScout
Tandem Repeat Finder 的更多参数模式
```

---

## 5. 基因结构注释与 GFF/CDS/PEP 整理软件

| 软件 | 用途 | 典型参数 / 命令要点 | 注意事项 |
|---|---|---|---|
| BRAKER3 | 整合蛋白和 RNA-seq 证据预测基因 | `--genome`、`--prot_seq`、`--rnaseq_sets_ids`、`--rnaseq_sets_dirs`、`--species`、`--gff3`、`--threads`、`--busco_lineage` | `--species` 不应复用旧项目名称；AUGUSTUS_CONFIG_PATH 需可写；输出后必须做 GFF/CDS/PEP 质检整理 |
| AUGUSTUS | ab initio 基因预测 | 通常由 BRAKER 调用 | species model 需明确 |
| GeneMark | ab initio / self-training | 通常由 BRAKER 调用 | 依赖 license 和环境配置 |
| gff_cds_pep.py | 从 genome FASTA + GFF/GFF3 生成 clean GFF、CDS、PEP、CDS check 表和可选 chromosome 子集 | `python3 gff_cds_pep.py --manifest manifest.tsv --outdir gff_cds_pep_outputs`；可选 `--keep-bad-cds`、`--transcript-regex` | 推荐作为注释后整理主流程；默认过滤非 3 倍数 CDS 和含 internal stop 的 CDS；输出进入功能注释、OrthoFinder、JCVI、GENESPACE、Circos |
| gffread | 从 GFF3 快速提取 CDS / protein | `gffread annotation.gff3 -g genome.fa -x cds.fa -y protein.fa` | 适合作为快速对照，不替代主转录本选择和 CDS 质检 |
| gtf2gff.pl | GTF/GFF 转换 | `gtf2gff.pl --gff3 input.gtf > output.gff3` | 转换后需检查 ID 层级 |
| BUSCO / compleasm protein mode | 评估整理后的 protein.primary.fa 完整性 | `busco -m prot`；`compleasm.py protein -p protein.primary.fa` | 用于判断基因注释质量 |

未稳定确认但可按项目需要补充：

```text
MAKER
EVidenceModeler
PASA
```

---

## 6. 功能注释软件

| 软件 | 用途 | 典型参数 / 命令要点 | 注意事项 |
|---|---|---|---|
| InterProScan | domain、Pfam、InterPro、GO 注释 | `-i protein.primary.fa -o interproscan.tsv -f tsv -goterms -dp -cpu 10 -T temp_dir` | 输出后需解析为统一 `.iprscan.xls`；Pfam 记录进入 domain 统计 |
| parse_interproscan_tsv.py | 将 InterProScan TSV 整理为项目统一表 | `--input interproscan.tsv --out iprscan.xls` | 推荐字段包括 Query_id、Subject_id、Subject_DB、Query_start、Query_end、E_value、Subject_annotation |
| eggNOG-mapper | orthology-based 功能注释 | `emapper.py -i protein.primary.fa -o prefix -d euk --cpu 30 --dbmem` | 输出 annotations 需去除 `##` 注释行后再合并 |
| KofamScan | KEGG KO 注释 | `exec_annotation -f detail -o kofam.detail.txt protein.primary.fa` | 保留 score 和 threshold；只把通过阈值的 KO 纳入最终解释 |
| DIAMOND | 快速蛋白数据库比对 | `diamond blastp --db db.dmnd --query protein.primary.fa --evalue 1e-5 --max-target-seqs 5 --max-hsps 1 --outfmt 6 ... --ultra-sensitive` | SwissProt 用于高置信描述；NR 可选且体量大 |
| BLASTP | 蛋白数据库比对 | `blastp -query protein.primary.fa -db db -evalue 1e-5 -outfmt 6 -max_target_seqs 7 -num_threads 20` | 适合旧流程兼容或小规模比对 |
| merge_function_annotations.py | 合并 GFF 位置信息、CDS check、InterPro/Pfam、eggNOG、Kofam、SwissProt/NR | `--gff --cds-check --iprscan --eggnog --kofam --swissprot --out functional_annotation.tsv` | 生成后续 domain、扩张收缩解释、特殊染色体证据表的核心输入 |
| pandas / Python | 功能注释解析与表格合并 | `read_csv`、`merge`、`groupby`、`ExcelWriter` | 所有未注释基因应保留行并填 NA |

---

## 7. 基因家族与系统发育软件

| 软件 | 用途 | 典型参数 / 命令要点 | 注意事项 |
|---|---|---|---|
| OrthoFinder | orthogroup 推断 | `orthofinder -f protein_dir -t 32 -a 32`；大规模可用 `-t 60 -a 60`；续跑 `-b WorkingDirectory` | protein 文件名即 species ID；续跑前核对目录 |
| MAFFT | 单拷贝基因多序列比对 | `--maxiterate 1000 --localpair --thread 2 --anysymbol` | 蛋白序列中异常字符用 `--anysymbol` 兼容 |
| trimAl | 比对修剪 | `-automated1` 或 `-gt 0.5` | 可替代未确认行为的历史 trim 脚本 |
| AMAS | alignment 串联与分区 | `AMAS.py concat -i *.fa -f fasta -d aa -t supermatrix.fa -p partition.txt -u phylip` | 输出 partition 和 PHYLIP 供建树 |
| RAxML | 最大似然建树 | `-T 60 -f a -# 500 -m PROTCATGTR -p 12345 -x 12345 -n name -s supermatrix.phy` | 历史主方法；500 bootstrap |
| IQ-TREE | 模型测试、物种树和基因树 ML 建树 | 物种树：`iqtree2 -s supermatrix.fa -m MFP -bb 2000 -T 20`；基因树：`iqtree2 -s OG.trimmed.fa -m MFP -bb 1000 -alrt 1000 --prefix OG` | 基因树推荐用 IQ-TREE 批量跑；保留 `.treefile`、`.iqtree`、`.log` |
| MrBayes | 贝叶斯系统发育 | NEXUS 中设置 `lset rates=gamma`、`prset aamodelpr=mixed`、`mcmc ngen=...` | 需记录收敛指标 |
| select_genes_by_function.py | 根据功能注释筛选目标功能基因 | `--annotation --pfam`、`--ko` 或 `--keyword`；输出目标 gene/transcript ID list | 用于功能注释驱动的基因树入口 |
| select_blast_hits.py | 从目标基因对外群蛋白库比对结果中筛外群同源基因 | `--blast --mode top_per_query --top --out` | 外群数量不宜过多；需保留筛选规则 |
| build_function_tree_tip_table.py | 为功能驱动基因树构建 tip 注释表 | `--target-ids --outgroup-ids --marker-fasta --functional-annotation --out` | 标记 target、outgroup、marker/MAKER 来源，用于树图上色和解释 |
| prefix_fasta_ids.py | 为多物种 protein primary FASTA 添加物种前缀 | `--input --prefix --sep --out --map` | 避免基因树 tip ID 在不同物种间冲突；必须保留 ID map |
| extract_orthogroup_members.py | 从 Orthogroups.tsv 提取目标 orthogroup 成员 | `--orthogroups --target-list --id-map --outdir` | 输出每个 orthogroup 的 gene ID list |
| clean_pep_for_tree.py | 清理基因树输入蛋白序列 | `--remove-terminal-stop` | 内部 stop 应回查 CDS，不建议简单替换 |
| rename_tree_tips.py | 根据注释表重命名 gene tree tips | `--tree --tip-annotation --out` | 重命名前后 tip 数必须一致 |
| summarize_gene_trees.py | 汇总基因树质量、模型、树文件、功能注释 | `--orthogroups --gene-tree-list --alignment-dir --iqtree-dir --failed --out` | 每个目标 family 都应有 success 或 failed 记录 |
| CAFE / CAFE5 | 基因家族扩张收缩 | `cafe5 -i cafe_input.filtered.tsv -t ultrametric_tree.nwk -o cafe_result -k 3 -p 0.05` | 需 ultrametric tree；物种名必须与 count matrix 一致 |

---

## 8. 共线性、WGD 与宏观基因组结构软件

| 软件 | 用途 | 典型参数 / 命令要点 | 注意事项 |
|---|---|---|---|
| minimap2 | genome-level dotplot | `-x asm20`；近缘可试 `asm5`；中等差异可试 `asm10` | preset 影响 dotplot 密度 |
| dotPlotly | PAF dotplot 可视化 | `Rscript pafCoordsDotPlotly.R -i input.paf -o prefix -s -t -m 5000 -q 5000 -l` | 用于宏观共线性 / 结构变异展示 |
| BLASTP | protein-level synteny 前置比对 | `-evalue 1e-5 -outfmt 6 -num_alignments 20 -num_threads 50` | WGDI / MCScanX 常用输入 |
| DIAMOND | protein-level synteny 前置比对替代 | `--evalue 1e-5 --max-target-seqs 20 --outfmt 6 --sensitive` | 比 BLASTP 快 |
| WGDI | dotplot、共线性、WGD 相关分析 | 配置文件中设 `blast`、`gff1`、`gff2`、`lens1`、`lens2`、`score=100`、`evalue=1e-5`、`repeat_number=5` | GFF feature 类型和 ID 匹配最关键 |
| MCScanX | collinearity block 检测 | 需要同前缀 `.blast` 和 `.gff`，运行 `MCScanX prefix` | gene ID 与 protein ID 需对应 |
| JCVI | ortholog、anchors、karyotype 绘图 | `jcvi.compara.catalog ortholog`；`jcvi.compara.synteny screen --minspan=30 --simple` | 可作为 MCScanX/WGDI 补充 |
| Circos | 染色体级多轨道可视化 | `circos -conf circos.conf` | 旧模板只能复用结构，所有 track 需重建 |
| bedtools | GC/gene/repeat/intron 窗口统计 | `makewindows`、`nuc`、`coverage` | Circos track 常用 |

---

## 9. Domain / Pfam 统计相关软件

| 软件 / 库 | 用途 | 典型参数 / 命令要点 | 注意事项 |
|---|---|---|---|
| InterProScan | 生成 Pfam / InterPro 结果 | `-f tsv -goterms -dp` | Pfam 统计的输入来源 |
| Python pandas | 统计 Pfam count matrix 和导出 Excel | `read_csv(sep='\t')`、`groupby`、`ExcelWriter` | 统计的是 Pfam hit count，不等价于基因数 |
| openpyxl / xlsxwriter | Excel 写出 | 由 pandas 调用 | 确保环境安装 |

---

## 10. 推荐版本记录表

实际执行项目时建议另建版本表：

| 软件 | 版本 | 数据库版本 | 运行日期 | 备注 |
|---|---|---|---|---|
| hifiasm |  |  |  |  |
| NextDenovo |  |  |  |  |
| purge_dups |  |  |  |  |
| BUSCO |  | embryophyta_odb10 |  |  |
| compleasm |  | embryophyta_odb10 |  |  |
| Merqury |  |  |  |  |
| LTR_retriever |  |  |  |  |
| RepeatMasker |  | repeat library |  |  |
| BRAKER3 |  |  |  |  |
| InterProScan |  | Pfam / InterPro |  |  |
| eggNOG-mapper |  | eggNOG |  |  |
| OrthoFinder |  |  |  |  |
| MAFFT |  |  |  |  |
| RAxML |  |  |  |  |
| IQ-TREE |  |  |  |  |
| CAFE |  |  |  |  |
| WGDI |  |  |  |  |
| MCScanX |  |  |  |  |
| Circos |  |  |  |  |
