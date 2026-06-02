# Stage 02 assembly, scaffolding, statistics, and assembly QC

Use this directory after Stage 01 read filtering and Stage 02 genome survey. Genome survey and ploidy scripts live in `../02_genome_survey/`.

## Recommended order

1. Choose one assembler wrapper based on read type.
2. Run assembly statistics on the resulting FASTA.
3. Optionally run Hi-C scaffolding from an existing assembly.
4. Run coverage/GC-depth QC with WGS, HiFi, or ONT reads.
5. Run BUSCO, LAI, and Merqury as independent assessment workflows.
6. Pass the selected assembly/scaffold FASTA to Stage 03 repeat annotation and Stage 04 gene prediction.

## Assembly wrappers

```bash
bash run_hifiasm_assembly.sh --help
bash run_nextdenovo_assembly.sh --help
bash run_spades_assembly.sh --help
bash run_flye_assembly.sh --help
bash run_canu_assembly.sh --help
bash run_verkko_assembly.sh --help
```

Run one assembly method at a time. Do not combine methods in a single driver unless the project explicitly defines that comparison.

## Scaffolding wrappers

```bash
bash run_yahs_scaffolding.sh --help
bash run_haphic_scaffolding.sh --help
```

Scaffolding consumes an existing assembly FASTA and Hi-C reads. Keep scaffolding logs and AGP/FASTA outputs.

## Coverage and GC-depth QC

```bash
bash run_pandepth_coverage_workflow.sh \
  --genome Arabidopsis_thaliana.genome.fa \
  --wgs-r1 Arabidopsis_thaliana.WGS_R1.clean.fq.gz \
  --wgs-r2 Arabidopsis_thaliana.WGS_R2.clean.fq.gz \
  --outdir pandepth_qc \
  --output-name Arabidopsis_thaliana

bash run_gc_depth_workflow.sh \
  --genome Arabidopsis_thaliana.genome.fa \
  --hifi Arabidopsis_thaliana.hifi.fa.gz \
  --outdir gc_depth_qc \
  --output-name Arabidopsis_thaliana \
  --gc-depth-script gc_depth_analysis.py
```

## Assessment workflows

```bash
bash run_busco_qc_workflow.sh --help
bash run_lai_qc_workflow.sh --help
bash run_merqury_qv_workflow.sh --help
```

Keep BUSCO, LAI, and Merqury independent. They answer different QC questions and should not be merged into one opaque script.

## Utility scripts

```bash
python3 assembly_stats.py --help
python3 summarize_busco_results.py --help
python3 summarize_lai_results.py --help
python3 summarize_merqury_qv.py --help
```

## QC checks

- Assembly FASTA is non-empty and sequence IDs are unique.
- Assembly length, N50/L50, and GC are plausible for the species.
- Hi-C pairing definitions are documented when scaffolding is used.
- Coverage and GC-depth plots are reviewed for abnormal windows.
- BUSCO lineage, LAI parameters, Merqury k-mer/read inputs, and tool versions are recorded.
