# BioAnalysis Run Checklist

Use this checklist as the execution gate for a genome project. Every stage should produce traceable outputs before the next stage begins.

Examples use anonymized placeholders such as `Arabidopsis_thaliana`, `Arabidopsis_lyrata`, and `Arabidopsis_halleri`.

```text
Input -> Command/script -> Expected output -> QC pass criteria -> Next input
```

## Stage checklist

| Stage | Input | Command/script | Expected output | QC pass criteria | Stop conditions |
|---|---|---|---|---|---|
| 01 Preprocessing and contamination screening | Raw reads or assembly FASTA, local NT resources when available | `scripts/01_preprocessing/01_nt_decontaminate_contigs.sh`, file inventory checks | File manifest, length/N50 reports, optional NT-filtered FASTA | Inputs exist, IDs are unique, contamination decisions are documented | Missing input files, undocumented database versions, or ambiguous sample IDs |
| 02 Assembly and assembly QC | Reads or filtered assembly FASTA | hifiasm/NextDenovo/SPAdes/Canu, `scripts/02_assembly/assembly_stats.py` | Assembly FASTA, assembly stats, logs | FASTA is non-empty, sequence IDs are unique, total length is plausible | Empty assembly, duplicate IDs, unresolved assembler failure |
| 03 Repeat annotation | Uppercase genome FASTA and repeat tools | `scripts/03_repeat/*.sh`, RepeatMasker, `repeat_stat.sh` | Repeat libraries, RepeatMasker `.out`, repeat GFF3, repeat summary | LTR and RepeatModeler outputs are non-empty when expected; repeat coordinates are valid | Missing `.scn`, missing library, unmerged RepeatMasker outputs |
| 04 GFF/CDS/PEP extraction | Genome FASTA, gene annotation GFF/GTF, manifest | `scripts/04_gff/gff_cds_pep.py` | Clean GFF, CDS, protein FASTA, CDS check tables | IDs match genome/GFF, no retained internal-stop CDS unless justified | Missing seqids, widespread CDS errors, ID convention conflicts |
| 05 Genome features and introns | GFF3, genome FASTA, optional Introner-elements tools | `scripts/05_genome_features/extract_introns.py`, `run_introner_elements.sh` | Intron BED, unique intron BED, short intron BED, AT-rich summaries, introner candidate outputs | BED coordinates are 0-based half-open; unique loci are used for density; external tool paths are documented outside the repo | Coordinate-system conflict, missing genome FASTA for AT metrics, unverified introner outputs |
| 06 Functional annotation and term summaries | Protein FASTA, clean GFF, CDS QC, database outputs, optional term maps | InterProScan, eggNOG, KofamScan, DIAMOND/BLASTP, `scripts/06_annotation/*.py` | Parsed annotation tables, `functional_annotation.tsv`, GO/KEGG/Pfam/domain summaries, optional enrichment tables | Query IDs match protein FASTA; missing annotations are recorded as `NA`; term maps and foreground/background IDs are documented | ID mismatch, missing database output, empty merged table, undocumented term-map source |
| 07 Gene families, orthogroups, and phylogeny helpers | Protein FASTA per species, species list, selected genes/families | OrthoFinder, MAFFT, trimAl, IQ-TREE/RAxML, `scripts/07_gene_family/*.py` | Prefixed FASTA files, OrthoFinder orthogroups, family summaries, selected member lists, alignments, trees, tip annotations | Species names match across FASTA, count matrix, and trees; orthogroup member IDs are traceable; failed families are logged | Species-name mismatch, empty orthogroups, empty alignments, untracked failed trees |
| 08 Gene-family evolution with Count and CAFE | OrthoFinder gene-count table, family summary, species tree | Count, CAFE/CAFE5, `scripts/08_gene_family_evolution/*.py` | Count input, parsed gain/loss table, family/node gain-loss summaries, CAFE input, filtered families, removed-family table, CAFE results | Tree tips match count-matrix columns; rejected or removed families have reasons; ultrametric-tree and model assumptions are documented | Tree/count mismatch, unsupported Count output format, undocumented ultrametric tree, missing removed-family reasons |
| 09 Synteny and Circos links | Genome FASTA, GFF3, protein FASTA, anchor/block files | minimap2, WGDI/MCScanX/JCVI, `scripts/09_synteny/anchors_to_circos_links.py` | Dotplots, synteny blocks, Circos links | Chromosome IDs match; link coordinates are in bounds | Out-of-bound coordinates, missing chromosome IDs |
| 10 HGT screening and validation handoff | Query FASTA, NR BLAST/DIAMOND hits or taxon-group NR databases, blast2hgt taxonomy database, GFF, intron/synteny evidence | `scripts/10_hgt/run_hgt_blast2hgt_workflow.sh` plus Stage 10 helper scripts | Blast2hgt lineage table, HGT candidate scores, context table, validation ID lists | Candidate calls distinguish `candidate`, `rejected`, `unknown`, `missing`, and `not_tested`; blast2hgt database provenance is documented; no remote data access is hidden | Missing taxonomy mapping, insufficient donor signal, missing blast2hgt database setup, candidate on suspicious contaminant scaffold |
| 11 Visualization and final deliverables | QC summaries and analysis tables | Circos, plotting tools, project-specific merge scripts | Figures, evidence tables, reproducible methods notes | Every final claim maps back to a command and file | Untraceable figure/table values, missing provenance |

## Continuous extension checklist

When adding another workflow:

1. Add scripts under the appropriate numbered stage.
2. Add command examples.
3. Add SOP/checklist entries.
4. Add script provenance and status.
5. Keep examples anonymized.
6. Keep repository text in English.
7. Run `make check-all` before commit.
