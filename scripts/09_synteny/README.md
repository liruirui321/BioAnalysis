# Stage 09 synteny context, heatmaps, and Circos links

Use this directory after GFF/protein/gene BED files and synteny outputs are available.

## Recommended order

1. Generate synteny anchors or blocks with external MCScanX/JCVI/WGDI/minimap2 workflows.
2. Normalize anchor/simple/table outputs with the Stage 09 workflow.
3. Build pairwise synteny heatmap matrices.
4. Compare target and background region synteny support when needed.
5. Convert anchors/blocks to Circos links for visualization.

## Main workflow

```bash
bash run_synteny_context_workflow.sh \
  --input Arabidopsis_thaliana.Arabidopsis_lyrata.anchors \
  --format anchor \
  --outdir synteny_context \
  --pair-label Arabidopsis_thaliana.Arabidopsis_lyrata \
  --gene-bed Arabidopsis_thaliana.gene.bed \
  --target-bed Arabidopsis_thaliana.eve_geve_regions.bed \
  --background-bed Arabidopsis_thaliana.callable_windows.bed
```

## Individual helpers

```bash
python3 summarize_mcscan_jcvi_synteny.py --help
python3 build_synteny_heatmap_matrix.py --help
python3 compare_region_synteny.py --help
python3 anchors_to_circos_links.py --help
```

## QC checks

- Chromosome IDs match among FASTA, GFF, BED, and synteny files.
- Coordinates are in bounds and use a documented coordinate system.
- Target and background regions are comparable.
- Input synteny format is recorded.
- Circos link files are generated only after BED coordinate maps are validated.
