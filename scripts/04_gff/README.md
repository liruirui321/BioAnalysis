# Stage 04 GFF/CDS/PEP extraction and gene-structure statistics

Use this directory after gene prediction or after receiving an annotation GFF/GTF from another source. Gene prediction itself lives in `../04_gene_prediction/`.

## Recommended order

1. Run `gff_cds_pep.py` to clean annotation IDs and extract CDS/protein FASTA.
2. Review CDS QC tables for stop codons, frame issues, duplicate IDs, and Parent links.
3. Run gene-structure summaries for the main species and optional comparison species.
4. Prepare plot-ready tables and optional PDFs.
5. Pass clean protein/CDS/GFF outputs to Stage 06 annotation and Stage 07 gene family workflows.

## Clean GFF/CDS/PEP extraction

```bash
python3 gff_cds_pep.py \
  --genome Arabidopsis_thaliana.genome.fa \
  --gff Arabidopsis_thaliana.annotation.gff3 \
  --out-prefix Arabidopsis_thaliana.primary \
  --manifest Arabidopsis_thaliana.gff_cds_pep_manifest.tsv
```

## Structure workflow

```bash
bash run_gff_structure_workflow.sh \
  --gff Arabidopsis_thaliana.primary.gff3 \
  --genome Arabidopsis_thaliana.genome.fa \
  --outdir gff_structure \
  --prefix Arabidopsis_thaliana \
  --comparison-gff Arabidopsis_lyrata.primary.gff3 \
  --comparison-label Arabidopsis_lyrata
```

## Individual helpers

```bash
python3 summarize_gff_structure.py --help
python3 compare_gff_structure.py --help
python3 prepare_gff_structure_plot_handoff.py --help
Rscript plot_gff_structure.R --help
```

## QC checks

- Genome FASTA IDs match GFF seqids.
- Feature IDs are unique.
- Parent links are valid.
- CDS coordinates are in bounds.
- Internal stop codons and frame issues are reviewed before functional annotation.
- Comparison species labels are consistent across tables and plots.
