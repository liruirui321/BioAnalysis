# Stage 10 HGT screening and full-method event summaries

Use this directory after protein FASTA, NR/DIAMOND hits, taxonomy resources, orthogroups, and family-evolution inputs are available.

## Recommended order

1. Run taxon-group NR DIAMOND searches if `.nr.out` files do not already exist.
2. Run blast2hgt handoff and candidate filtering for each species.
3. Build comparable Condition1/Condition2 matrices across all species.
4. Convert HGT candidates into `gene--source` IDs and optional HGT-only protein FASTA.
5. Cluster HGT-only proteins externally with OrthoFinder when using Method 2.
6. Summarize M1 or M2 HGT-family gain/expansion events.
7. Prepare plot-ready HGT donor and node-event handoff tables.
8. Add genome context and validation handoffs for priority single-species candidates.

## Step 1: NR taxonlist DIAMOND searches

```bash
bash run_hgt_nr_taxonlist_workflow.sh \
  --query Arabidopsis_thaliana.protein.primary.fa \
  --diamond-db refs/nr/nr_diamond \
  --taxonlist Plant=33090 \
  --taxonlist bacteria=2 \
  --taxonlist fungi=4751 \
  --taxonlist Metazoa=33208 \
  --taxonlist virus=10239 \
  --taxonlist archaea=2157 \
  --outdir nr_by_taxon \
  --prefix Arabidopsis_thaliana \
  --threads 10
```

## Step 2: single-species blast2hgt candidate screen

```bash
bash run_hgt_blast2hgt_workflow.sh \
  --query Arabidopsis_thaliana.protein.primary.fa \
  --blast2hgt-dir refs/blast2hgt \
  --blast-glob 'nr_by_taxon/Arabidopsis_thaliana_*.nr.out' \
  --outdir hgt_work \
  --self-group Brassicaceae=3700 \
  --define Viridiplantae=33090 \
  --define fungi=4751 \
  --define archaea=2157 \
  --define bacteria=2 \
  --define Metazoa=33208 \
  --define virus=10239 \
  --donor-groups bacteria,fungi,Metazoa,virus,archaea,other \
  --gff Arabidopsis_thaliana.annotation.primary.gff3 \
  --functional-annotation Arabidopsis_thaliana.functional_annotation.tsv
```

## Step 3: full-species Condition1/Condition2 matrices

Prepare a manifest like:

```text
species\trp_tsv\tsource
Arabidopsis_thaliana\thgt_work/Arabidopsis_thaliana.rp.tsv\tcurrent_nr_blast2hgt
Arabidopsis_lyrata\tNA\tpending_no_hgt_input
```

Then run:

```bash
python3 build_hgt_condition_matrices.py \
  --species-manifest hgt_species_rp_manifest.tsv \
  --outdir hgt_conditions \
  --donor-groups bacteria,fungi,Metazoa,virus,archaea,other
```

Condition definitions:

- Condition1: `alien_index > 0` and `AI_taxon` is in the external donor whitelist.
- Condition2: Condition1 plus `AI_taxon == h_taxon`.

## Step 4: HGT orthogroup inputs

```bash
python3 prepare_hgt_orthogroup_inputs.py \
  --candidates hgt_conditions/Condition2_HGT_candidates.tsv \
  --protein Arabidopsis_thaliana.protein.primary.fa \
  --outdir hgt_orthogroup_inputs \
  --prefix tree_species.Condition2
```

Use the generated HGT-only protein FASTA with external OrthoFinder to produce `Orthogroups.HGT.txt` and `Orthogroups.HGT.GeneCount.result.txt`.

## Step 5: HGT-family event summaries

Preferred Method 2 family-centric summary:

```bash
python3 summarize_hgt_family_events.py \
  --method m2 \
  --count-hgt Orthogroups.HGT.GeneCount.result.txt \
  --count-all Orthogroups.all.GeneCount.result.txt \
  --node-list node.list \
  --txt-hgt Orthogroups.HGT.txt \
  --txt-all Orthogroups.all.txt \
  --outdir hgt_family_events_m2
```

Method 1 gene-centric summary:

```bash
python3 summarize_hgt_family_events.py \
  --method m1 \
  --count-all Orthogroups.all.GeneCount.result.txt \
  --node-list node.list \
  --txt-hgt Orthogroups.HGT.txt \
  --txt-all Orthogroups.all.txt \
  --outdir hgt_family_events_m1 \
  --min-hgt-ratio 0.3
```

Node HGT counts are family gain/expansion events, not sums of species-level HGT genes.

## Step 6: visualization handoff

```bash
python3 prepare_hgt_visualization_handoff.py \
  --condition-matrix hgt_conditions/Condition2_Matching_taxon_counts_matrix.tsv \
  --event-summary hgt_family_events_m2/M2_Summary_Evolution.tsv \
  --source-breakdown hgt_family_events_m2/M2_HGT_Source_Breakdown.tsv \
  --outdir hgt_visualization \
  --prefix tree_species.Condition2.M2
```

## Optional full-method wrapper

```bash
bash run_hgt_full_method_workflow.sh --help
```

Use this wrapper to chain the public handoff steps when all required inputs are ready. It does not run external OrthoFinder for HGT-only clustering; run that between HGT gene-source preparation and M2 event summaries.

## QC checks

- blast2hgt taxonomy databases and `--define` groups are documented.
- Donor whitelist and excluded internal groups are recorded.
- Species with missing `.rp.tsv` inputs remain in matrices with zero counts.
- HGT-only and ALL orthogroup IDs are traceable back to gene IDs.
- Node/species parent lists match count matrix columns.
- Candidate HGT calls remain candidates until phylogenetic/context review.
