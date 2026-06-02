# Stage 06 functional annotation and enrichment

Use this directory after clean protein FASTA and annotation GFF/CDS outputs are available from Stage 04.

## Recommended order

1. Run or collect database annotations: InterProScan, eggNOG, KofamScan, DIAMOND/BLASTP, SwissProt/NR/KOG if available.
2. Use `run_kofam_annotation_workflow.sh` when KofamScan detail output is not already available.
3. Parse and merge annotation tables with `run_functional_annotation_workflow.sh`.
4. Summarize GO, KEGG, Pfam, domains, COG/NOG categories.
5. Run enrichment from the maintained Python helper or optional local EnrichPipeline.
6. Prepare GO semantic plot handoff tables when needed.

## KofamScan KEGG annotation

```bash
bash run_kofam_annotation_workflow.sh \
  --protein Arabidopsis_thaliana.protein.primary.fa \
  --outdir kofam_annotation \
  --prefix Arabidopsis_thaliana \
  --exec-option "--profile refs/kofam/profiles" \
  --exec-option "--ko-list refs/kofam/ko_list" \
  --evalue 1e-5
```

## Functional annotation merge

```bash
bash run_functional_annotation_workflow.sh \
  --gff Arabidopsis_thaliana.annotation.primary.gff3 \
  --outdir annotation_work \
  --prefix Arabidopsis_thaliana \
  --interproscan Arabidopsis_thaliana.interproscan.tsv \
  --kofam-detail kofam_annotation/Arabidopsis_thaliana.kofam.detail.txt \
  --eggnog Arabidopsis_thaliana.eggnog.tsv \
  --ko-map refs/ko_to_pathway.tsv \
  --pathway-names refs/pathway_names.tsv
```

## Local EnrichPipeline enrichment

Use this only with an external local EnrichPipeline directory. Do not commit `EnrichPipeline.tar.gz`, extracted EnrichPipeline files, or bundled database resources.

```bash
bash run_enrichpipeline_enrichment_workflow.sh \
  --enrichpipeline-dir refs/EnrichPipeline \
  --class GO \
  --wego Arabidopsis_thaliana.gene.wego \
  --metago refs/EnrichPipeline/enrichment/data/MetaGO_20140308.RData \
  --supply gained_family_genes.ids \
  --outdir enrichpipeline_go_gain \
  --prefix Arabidopsis_thaliana.gain \
  --p-adjust-method fdr \
  --test-method FisherChiSquare

bash run_enrichpipeline_enrichment_workflow.sh \
  --enrichpipeline-dir refs/EnrichPipeline \
  --class KEGG \
  --map-gene Arabidopsis_thaliana.KEGG.map.gene.txt \
  --supply expanded_family_genes.ids \
  --supply2 contracted_family_genes.ids \
  --outdir enrichpipeline_kegg_exp_con \
  --prefix Arabidopsis_thaliana.expansion_contraction
```

## Individual parsers and summarizers

```bash
python3 parse_interproscan_tsv.py --help
python3 parse_kofam_detail.py --help
python3 merge_function_annotations.py --help
python3 summarize_go_terms.py --help
python3 summarize_kegg_pathways.py --help
python3 summarize_pfam_domains.py --help
python3 summarize_domain_architecture.py --help
python3 summarize_eggnog_categories.py --help
python3 enrich_annotation_terms.py --help
python3 prepare_go_semantic_handoff.py --help
bash run_go_enrichment_plot_handoff.sh --help
```

## QC checks

- Query IDs match protein FASTA and GFF-derived gene IDs.
- Database versions and paths are recorded outside the repository.
- Missing annotations are encoded as `NA`.
- Foreground and background gene sets use the same ID namespace.
- EnrichPipeline archives and bundled databases are kept out of git.
