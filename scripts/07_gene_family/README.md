# Stage 07 gene families, target-family discovery, expression evidence, and phylogeny helpers

Use this directory after clean protein FASTA and functional annotation tables are available.

## Recommended order

1. Optionally prefix FASTA IDs for multi-species consistency.
2. Run OrthoFinder or import existing OrthoFinder results.
3. Summarize orthogroups and extract members of selected families.
4. Merge target-family evidence from annotation, seed genes, and BLAST/DIAMOND hits.
5. Build peptide/tree inputs for selected gene families.
6. Summarize expression evidence when a TPM/count matrix is available.
7. Prepare alignments, trees, and tip annotation handoffs.

## Main gene-family workflow

```bash
bash run_gene_family_workflow.sh \
  --protein-dir protein_dir \
  --orthogroups Orthogroups.tsv \
  --gene-count Orthogroups.GeneCount.tsv \
  --species-list species.list \
  --outdir gene_family_work \
  --run-orthofinder \
  --orthofinder orthofinder \
  --threads 24
```

If OrthoFinder has already run, omit `--run-orthofinder` and provide the resulting `Orthogroups.tsv` and count table.

## Target-family workflow

```bash
bash run_target_family_workflow.sh \
  --annotation annotation_work/Arabidopsis_thaliana.functional_annotation.tsv \
  --rules refs/target_family_rules.tsv \
  --outdir target_family_work \
  --prefix Arabidopsis_thaliana \
  --protein Arabidopsis_thaliana.protein.primary.fa \
  --expression Arabidopsis_thaliana.tpm.tsv
```

## Common helper groups

- ID and FASTA handling: `prefix_fasta_ids.py`, `clean_pep_for_tree.py`.
- OrthoFinder summaries: `summarize_orthofinder_gene_families.py`, `extract_orthogroup_members.py`.
- Target-family evidence: `merge_target_family_evidence.py`, `build_target_family_inputs.py`, `select_genes_by_function.py`, `select_blast_hits.py`.
- Expression evidence: `summarize_gene_set_expression.py`.
- Tree handoffs: `concat_alignments.py`, `build_function_tree_tip_table.py`, `make_tree_tip_annotation.py`, `rename_tree_tips.py`, `summarize_gene_trees.py`.

## QC checks

- Species names match across FASTA files, species lists, orthogroups, count matrices, and trees.
- Gene IDs are traceable through prefix maps and orthogroups.
- Target-family rule provenance is recorded.
- Failed alignments or trees are logged instead of silently dropped.
