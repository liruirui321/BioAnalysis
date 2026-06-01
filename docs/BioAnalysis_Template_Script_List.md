# BioAnalysis Script Reference

This document is the script reference for the BioAnalysis genome workflow. It lists maintained helper scripts under `../scripts/`, reference-derived scripts, deprecated historical scripts, and external software entry points.

Use this document as a repository reference:

```text
Script -> Source/status -> Inputs -> Outputs -> Next workflow step
```

Status labels match [`../scripts/SCRIPT_SOURCES.md`](../scripts/SCRIPT_SOURCES.md):

- `Implemented and CLI verified`
- `Implemented; limited placeholder behavior`
- `Reference-derived; cleaned wrapper`
- `Reference-derived; review before use`
- `Deprecated historical reference`
- `External tool; not included`

Example naming convention: command examples use Arabidopsis-style sample names to demonstrate expected file naming patterns.

---

## 1. 总览

| 脚本 / 命令 | 类型 | 当前状态 | 所属流程 |
|---|---|---|---|
| `gff_cds_pep.py` | BioAnalysis helper | Implemented and CLI verified | GFF/CDS/PEP 整理 |
| `assembly_stats.py` | BioAnalysis helper | Implemented and CLI verified | 组装统计 |
| `parse_interproscan_tsv.py` | BioAnalysis helper | Implemented and CLI verified | InterProScan 解析 |
| `parse_kofam_detail.py` | BioAnalysis helper | Implemented and CLI verified | KofamScan 解析 |
| `merge_function_annotations.py` | BioAnalysis helper | Implemented and CLI verified | 功能注释合并 |
| `prefix_fasta_ids.py` | BioAnalysis helper | Implemented and CLI verified | 基因树输入准备 |
| `extract_orthogroup_members.py` | BioAnalysis helper | Implemented and CLI verified | 基因树 family 提取 |
| `clean_pep_for_tree.py` | BioAnalysis helper | Implemented and CLI verified | 基因树序列清理 |
| `select_genes_by_function.py` | BioAnalysis helper | Implemented and CLI verified | 功能驱动基因树 |
| `select_blast_hits.py` | BioAnalysis helper | Implemented and CLI verified | 外群同源筛选 |
| `build_function_tree_tip_table.py` | BioAnalysis helper | Implemented and CLI verified | 功能驱动基因树注释 |
| `make_tree_tip_annotation.py` | BioAnalysis helper | Implemented and CLI verified | 基因树 tip 注释 |
| `rename_tree_tips.py` | BioAnalysis helper | Implemented and CLI verified | 树 tip 重命名 |
| `root_tree.py` | BioAnalysis helper | Implemented; limited placeholder behavior | rooting handoff |
| `summarize_gene_trees.py` | BioAnalysis helper | Implemented and CLI verified | 基因树结果汇总 |
| `concat_alignments.py` | BioAnalysis helper | Implemented and CLI verified | supermatrix 串联 |
| `prepare_cafe_input.py` | BioAnalysis helper | Implemented and CLI verified | CAFE 输入准备 |
| `filter_cafe_families.py` | BioAnalysis helper | Implemented and CLI verified | CAFE family 过滤 |
| `extract_introns.py` | BioAnalysis helper | Implemented and CLI verified | intron track |
| `anchors_to_circos_links.py` | BioAnalysis helper | Implemented and CLI verified | Circos links |
| `LTR_Finder.sh` | Reference-derived wrapper | Reference-derived; cleaned wrapper | LTR_FINDER_parallel |
| `LTR_harvest.sh` | Reference-derived wrapper | Reference-derived; cleaned wrapper | LTRharvest |
| `work.sh` | Reference-derived wrapper | Reference-derived; cleaned wrapper | LTR_retriever |
| `repeatmodeler.sh` | Reference-derived wrapper | Reference-derived; cleaned wrapper | RepeatModeler |
| `trf.sh` | Reference-derived wrapper | Reference-derived; cleaned wrapper | TRF |
| `rmout2gff.sh` | Reference-derived script | Reference-derived; review before use | RepeatMasker 转 GFF3 |
| `repeat_stat.sh` | Reference-derived script | Reference-derived; review before use | Repeat 分类统计 |
| `stat.sh` | Historical script | Deprecated historical reference | Repeat 分类统计 |
| `repeat_masked_to_lower_case.pl` | Reference-derived script | Reference-derived; review before use | masked genome 处理，可选 |
| `tree/*.pl`, `tree/rename_tree*.py` | Historical scripts | Reference-derived; review before use or deprecated | 历史树处理 |
| `visualization/circos/*.pl` | Reference-derived scripts | Reference-derived; review before use | Circos track |
| `kegg/*.pl` | Reference-derived scripts | Reference-derived; review before use | KEGG/pathway |
| `braker.pl`, `interproscan.sh`, `emapper.py`, `compleasm.py`, `spades.py`, `AMAS.py`, `best_k.sh`, `merqury.sh`, `digest_genome.py`, `pafCoordsDotPlotly.R` | External tool | External tool; not included | 对应软件流程 |

---

## 2. 重复注释相关脚本

## 2.1 `LTR_Finder.sh`

| 项目 | 内容 |
|---|---|
| 类型 | Reference-derived wrapper |
| 当前状态 | Reference-derived; cleaned wrapper |
| 用途 | 运行 `LTR_FINDER_parallel` 识别 LTR 候选 |
| 输入 | `--genome genome.fa`，必须为大写序列 |
| 输出 | 通常为 `genome.fa.finder.combine.scn` |
| 下一步 | 与 `genome.fa.harvest.scn` 合并后进入 `LTR_retriever` |
| 关键参数 | `--threads 30 --size 1000000 --time 300` |
| 注意事项 | 从 `PATH` 调用 `LTR_FINDER_parallel`；运行前确认 genome 序列已用 `seqkit seq -u` 转成大写 |

```bash
bash scripts/repeat/LTR_Finder.sh \
  --genome genome.fa \
  --threads 30
```

## 2.2 `LTR_harvest.sh`

| 项目 | 内容 |
|---|---|
| 类型 | Reference-derived wrapper |
| 当前状态 | Reference-derived; cleaned wrapper |
| 用途 | 使用 GenomeTools `gt suffixerator` 和 `gt ltrharvest` 识别 LTR 候选 |
| 输入 | `--genome genome.fa` |
| 输出 | `genome.fa.harvest.scn` |
| 下一步 | 与 `genome.fa.finder.combine.scn` 合并进入 `LTR_retriever` |
| 关键参数 | `--index-prefix genome.fa --out genome.fa.harvest.scn` |
| 注意事项 | 从 `PATH` 调用 `gt`；index 名与 genome/output 前缀保持一致 |

```bash
bash scripts/repeat/LTR_harvest.sh \
  --genome genome.fa \
  --index-prefix genome.fa \
  --out genome.fa.harvest.scn
```

## 2.3 `work.sh`

| 项目 | 内容 |
|---|---|
| 类型 | Reference-derived wrapper |
| 当前状态 | Reference-derived; cleaned wrapper |
| 用途 | 合并 LTR_FINDER 和 LTRharvest 结果，并运行 `LTR_retriever` |
| 输入 | `--genome genome.fa`、`--harvest genome.fa.harvest.scn`、`--finder genome.fa.finder.combine.scn` |
| 输出 | `genome.fa.rawLTR.scn`、`genome.fa.LTRlib.fa`、`genome.fa.pass.list`、`genome.fa.out` |
| 下一步 | `genome.fa.LTRlib.fa` 进入 RepeatMasker library；`pass.list` 和 `.out` 进入 LAI |
| 关键参数 | `--threads 12 --raw-ltr genome.fa.rawLTR.scn` |
| 注意事项 | 保留旧文件名用于兼容；功能上是 LTR_retriever wrapper；必须等 LTR_FINDER 和 LTRharvest 都完成后再运行 |

```bash
bash scripts/repeat/work.sh \
  --genome genome.fa \
  --harvest genome.fa.harvest.scn \
  --finder genome.fa.finder.combine.scn \
  --threads 12
```

## 2.4 `repeatmodeler.sh`

| 项目 | 内容 |
|---|---|
| 类型 | Reference-derived wrapper |
| 当前状态 | Reference-derived; cleaned wrapper |
| 用途 | 运行 BuildDatabase 和 RepeatModeler 构建 de novo repeat library |
| 输入 | `--genome genome.fa` |
| 输出 | `mydb-known.families.fa`、`mydb-unknown.families.fa` 或 `consensi.fa.classified` |
| 下一步 | 与 LTR library 合并成 RepeatMasker library |
| 关键参数 | `--database mydb --threads 20` |
| 注意事项 | 从 `PATH` 调用 `BuildDatabase` 和 `RepeatModeler`；可与 LTR_FINDER/LTRharvest 并行运行 |

```bash
bash scripts/repeat/repeatmodeler.sh \
  --genome genome.fa \
  --database mydb \
  --threads 20
```

## 2.5 `trf.sh`

| 项目 | 内容 |
|---|---|
| 类型 | Reference-derived wrapper |
| 当前状态 | Reference-derived; cleaned wrapper |
| 用途 | 运行 TRF 并可选转换为 GFF3 |
| 输入 | `--genome genome.fa` |
| 输出 | TRF `.dat`、可选 `*.gff3` |
| 下一步 | repeat track 或补充 repeat 注释 |
| 关键参数 | `--trf-args "2 5 7 80 10 50 2000" --gff Arabidopsis_thaliana.trf.gff3` |
| 注意事项 | 从 `PATH` 调用 `trf` 和 `trf2gff`；不同 TRF 版本的 `.dat` 命名需检查 |

## 2.6 `rmout2gff.sh`

| 项目 | 内容 |
|---|---|
| 类型 | Reference-derived script |
| 当前状态 | Reference-derived; review before use |
| 用途 | 将 RepeatMasker `.out` 转换成 GFF3 |
| 输入 | `Arabidopsis_thaliana.repeatmasker.all.out` |
| 输出 | `Arabidopsis_thaliana.repeatmasker.all.gff3` |
| 下一步 | repeat density、Circos repeat track、特殊染色体证据表 |
| 注意事项 | 脚本会按 LINE/SINE/DNA/LTR/RC/Low_complexity/Satellite/Simple_repeat/Unknown 加颜色标签；需抽查当前 RepeatMasker 输出格式 |

## 2.7 `repeat_stat.sh`

| 项目 | 内容 |
|---|---|
| 类型 | Reference-derived script |
| 当前状态 | Reference-derived; review before use |
| 用途 | 统计 RepeatMasker `.out` 中各 repeat 类别的非冗余覆盖长度和比例 |
| 输入 | RepeatMasker `.out`、genome size |
| 输出 | `repeat.summary.txt` 或 TSV |
| 下一步 | 组装/注释质量表、Circos 解释、特殊染色体证据 |
| 依赖 | `awk`、`sort`、`bedtools merge` |
| 注意事项 | 必须 merge 区间后统计，避免重复命中导致比例虚高；优先使用该脚本，不再使用历史 `stat.sh` |

---

# 3. GFF/CDS/PEP 整理脚本

## 3.1 `gff_cds_pep.py`

| 项目 | 内容 |
|---|---|
| 类型 | BioAnalysis helper |
| 当前状态 | Implemented and CLI verified |
| 用途 | 从 genome FASTA + GFF/GFF3 生成 clean GFF、CDS、PEP 和 CDS check 表 |
| 输入 | `manifest.tsv`，含 `species_id`、`species_name`、`genome_fasta`、`annotation_gff`、`keep_ids` |
| 输出 | `summary.tsv`、`*.hic.gff`、`*.hic.cds`、`*.hic.pep`、`*.raw.cds.check`、`*.cds.check` |
| 下一步 | `*.pep` 进入功能注释、OrthoFinder、gene tree；`*.gff` 进入共线性/Circos；`*.cds` 进入 CDS-based 分析 |
| 参数 | `--manifest`、`--outdir`、`--keep-bad-cds`、`--transcript-regex` |
| 注意事项 | 默认过滤 `phase_ok=0` 或 `internal_stop>0` 的 CDS；如果大量失败，优先检查 genome/GFF 是否匹配 |

---

# 4. 功能注释解析与合并脚本

## 4.1 `parse_interproscan_tsv.py`

| 项目 | 内容 |
|---|---|
| 类型 | BioAnalysis helper |
| 当前状态 | Implemented and CLI verified |
| 用途 | 将 InterProScan 原始 TSV 转为项目统一 `.iprscan.xls` 格式 |
| 输入 | `Arabidopsis_thaliana.interproscan.tsv` |
| 输出 | `Arabidopsis_thaliana.iprscan.xls` |
| 推荐字段 | `Query_id`、`Subject_id`、`Subject_DB`、`Query_start`、`Query_end`、`E_value`、`Subject_annotation` |
| 下一步 | Pfam/domain 统计、功能注释合并 |

## 4.2 `parse_kofam_detail.py`

| 项目 | 内容 |
|---|---|
| 类型 | BioAnalysis helper |
| 当前状态 | Implemented and CLI verified |
| 用途 | 解析 KofamScan `detail` 输出，提取通过阈值的 KO |
| 输入 | `kofam.detail.txt` |
| 输出 | `kofam.tsv` |
| 下一步 | 功能注释总表 |
| 注意事项 | 保留 score、threshold 和 KO ID；默认只保留通过阈值的记录 |

## 4.3 `merge_function_annotations.py`

| 项目 | 内容 |
|---|---|
| 类型 | BioAnalysis helper |
| 当前状态 | Implemented and CLI verified |
| 用途 | 合并 GFF 坐标、CDS check、InterPro/Pfam、eggNOG、Kofam、SwissProt/NR 注释 |
| 输入 | `annotation.primary.gff3`、`cds.check`、`iprscan.xls`、`eggnog.annotations.tsv`、`kofam.tsv`、`swissprot.besthit.tsv` |
| 输出 | `functional_annotation.tsv` |
| 下一步 | domain 统计、基因树筛选、扩张收缩解释、特殊染色体证据表 |
| 注意事项 | 未注释基因保留行，字段填 NA，不要删除；合并前检查 protein/transcript IDs 是否一致 |

---

# 5. 基因树相关 workflow helper script

| 脚本 | 当前状态 | 关键输入 | 关键输出 | 注意事项 |
|---|---|---|---|---|
| `select_genes_by_function.py` | Implemented and CLI verified | `functional_annotation.tsv` | `target_function.ids` | 可按 Pfam、KO、keyword、candidate list 筛选 |
| `select_blast_hits.py` | Implemented and CLI verified | BLAST/DIAMOND TSV | `outgroup_target_gene.ids` | 记录 top hit 数量和筛选规则 |
| `build_function_tree_tip_table.py` | Implemented and CLI verified | target IDs、outgroup IDs、marker FASTA、functional annotation | `target_function.tip_annotation.tsv` | 用于 tree tip 重命名和绘图分组 |
| `prefix_fasta_ids.py` | Implemented and CLI verified | `--input`、`--prefix`、`--out`、`--map` | prefixed FASTA、ID map | `--map` 必填，后续 OrthoFinder/gene tree 需要保留 |
| `extract_orthogroup_members.py` | Implemented and CLI verified | `Orthogroups.tsv`、target list、ID map | 每个 orthogroup 一个 `.ids` 文件 | 输出进入 family FASTA 提取 |
| `clean_pep_for_tree.py` | Implemented and CLI verified | family peptide FASTA | clean peptide FASTA | 内部 stop codon 应回查 CDS，不建议简单替换 |
| `make_tree_tip_annotation.py` | Implemented and CLI verified | functional annotation、ID map | `tree_tip_annotation.tsv` | 用于 ggtree/iTOL 绘图 |
| `rename_tree_tips.py` | Implemented and CLI verified | treefile、tip annotation | renamed tree | 重命名前后 tip 数必须一致 |
| `root_tree.py` | Implemented; limited placeholder behavior | tree、outgroup ID/file | copied tree + rooting note | 不执行真实 Newick reroot；需要外部树工具完成定根 |
| `summarize_gene_trees.py` | Implemented and CLI verified | Orthogroups、tree list、alignment dir、IQ-TREE dir、failed.tsv | `gene_tree_summary.tsv` | 每个 target family 都应有 success 或 failed 记录 |

---

# 6. 系统发育 / CAFE / 共线性处理脚本

## 6.1 `concat_alignments.py`

| 项目 | 内容 |
|---|---|
| 类型 | BioAnalysis helper |
| 当前状态 | Implemented and CLI verified |
| 用途 | 串联多个 trimmed alignment，生成 supermatrix、partition 和 occupancy 表 |
| 输入 | `--input-dir`、`--species-list`、可选 `--suffix` |
| 输出 | `--out-fasta`、`--out-partition`、`--out-stats` |
| 下一步 | RAxML/IQ-TREE/MrBayes 物种树 |
| 注意事项 | 当前脚本不输出 PHYLIP；需要 PHYLIP 时使用 AMAS 或其它转换工具 |

## 6.2 `prepare_cafe_input.py`

| 项目 | 内容 |
|---|---|
| 类型 | BioAnalysis helper |
| 当前状态 | Implemented and CLI verified |
| 用途 | 将 OrthoFinder `Orthogroups.GeneCount.tsv` 转换为 CAFE 输入 |
| 输入 | `--orthofinder-count`、`--species-tree` |
| 输出 | `--out cafe_input.tsv` |
| 下一步 | family 过滤、CAFE |
| 注意事项 | 会检查 species tree tips 是否存在于 count matrix 中 |

## 6.3 `filter_cafe_families.py`

| 项目 | 内容 |
|---|---|
| 类型 | BioAnalysis helper |
| 当前状态 | Implemented and CLI verified |
| 用途 | 过滤 CAFE 不适合的家族，如极端 copy number、全零、物种覆盖过少 |
| 输入 | `--input cafe_input.tsv` |
| 输出 | `--out cafe_input.filtered.tsv`、`--removed cafe_input.removed.tsv` |
| 下一步 | CAFE / CAFE5 |
| 注意事项 | `--removed` 必填，用于记录被过滤家族和原因 |

## 6.4 `extract_introns.py`

| 项目 | 内容 |
|---|---|
| 类型 | BioAnalysis helper |
| 当前状态 | Implemented and CLI verified |
| 用途 | 从 GFF3 exon/CDS 坐标推断 intron 区间 |
| 输入 | `annotation.primary.gff3` |
| 输出 | `intron.bed`、`short_intron_40_65bp.bed` |
| 下一步 | Circos intron density、特殊染色体证据 |

## 6.5 `anchors_to_circos_links.py`

| 项目 | 内容 |
|---|---|
| 类型 | BioAnalysis helper |
| 当前状态 | Implemented and CLI verified |
| 用途 | 将 WGDI/MCScanX/JCVI anchors 或 blocks 转换为 Circos link 格式 |
| 输入 | anchors/block 文件、reference/query gene BED coordinate table |
| 输出 | `block_link.txt` |
| 下一步 | Circos links |
| 注意事项 | 优先使用该脚本而不是依赖文件名前缀的 legacy `simple2links.py` |

---

# 7. 现成软件入口，不需要项目内实现

这些是软件自带命令或第三方工具入口，通常不需要自己实现：

```text
braker.pl
interproscan.sh
emapper.py
compleasm.py
spades.py
AMAS.py
best_k.sh
merqury.sh
digest_genome.py
pafCoordsDotPlotly.R
nextcorrect.py
```

注意：虽然这些不需要实现，但需要在项目中记录软件版本、数据库版本和实际运行参数。

---

# 8. 执行前检查原则

```text
1. 任何 workflow helper script 在 SOP 中出现前，应确认是否已有实现。
2. 如果没有实现，文档中必须标为模板或 planned，不能写成已可用脚本。
3. 如果使用历史脚本，必须去除真实路径、真实物种名和旧项目硬编码。
4. 每个脚本必须明确输入、输出和下一步输入。
5. 每个脚本输出必须有最少一个检查项，例如文件非空、ID 可对应、行数合理。
6. 脚本状态应同步维护在本文件和 ../scripts/SCRIPT_SOURCES.md。
```
