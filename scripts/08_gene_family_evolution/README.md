# Stage 08 gene-family evolution with Count and CAFE

Use this directory after OrthoFinder gene-count tables and a species tree are available.

## Recommended order

1. Prepare Count input from OrthoFinder counts.
2. Run Count externally or parse existing Count output.
3. Summarize family gain/loss by family and node.
4. Prepare CAFE input and filter problematic families.
5. Integrate target-family evidence with gain/loss summaries.

## Main workflow

```bash
bash run_gene_family_evolution_workflow.sh \
  --gene-count Orthogroups.GeneCount.tsv \
  --species-tree species_tree.nwk \
  --outdir family_evolution_work \
  --prefix tree_species \
  --count-output Count_results.tsv
```

## Individual helpers

```bash
python3 prepare_count_input.py --help
python3 parse_count_gain_loss.py --help
python3 summarize_family_gain_loss.py --help
python3 prepare_cafe_input.py --help
python3 filter_cafe_families.py --help
python3 integrate_target_family_evolution.py --help
```

## QC checks

- Tree tips match count-matrix columns exactly.
- Removed or rejected families have recorded reasons.
- Count output format is validated before parsing.
- CAFE assumptions and ultrametric tree source are documented.
- Target-family genes map to orthogroups before integration.
