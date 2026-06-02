# Stage 11 visualization matrices and final handoff tables

Use this directory after analysis stages have produced validated gene sets, expression summaries, evolution tables, HGT tables, and synteny/context outputs.

## Recommended order

1. Collect final gene sets and evidence tables from earlier stages.
2. Build gene-set membership matrices for UpSet/Venn-style plots.
3. Prepare family visualization matrices from expression, target-family evolution, and HGT-family tables.
4. Convert synteny anchors to Circos links in Stage 09 when needed.
5. Run external plotting tools outside the repository.

## Main workflow

```bash
bash run_visualization_handoff_workflow.sh \
  --outdir visualization_handoff \
  --prefix Arabidopsis_thaliana.summary \
  --gene-set HGT=hgt_candidate_genes.ids \
  --gene-set target_family=target_family_genes.ids \
  --gene-set gained=gained_family_genes.ids \
  --expression-summary target_family_expression_summary.tsv \
  --target-evolution target_family_evolution.tsv \
  --hgt-family hgt_family_evolution.tsv
```

## Individual helpers

```bash
python3 build_gene_set_matrix.py --help
python3 prepare_family_visualization_matrices.py --help
```

Legacy Circos helpers are stored under `circos/` for reference. Prefer Stage 09 `anchors_to_circos_links.py` for synteny links.

## QC checks

- Every plotted value maps to a source TSV and manifest row.
- Gene-set files use the same ID namespace.
- Missing data are represented explicitly as `NA` or zero, not silently omitted.
- External plotting tool versions and scripts are recorded in project notes.
