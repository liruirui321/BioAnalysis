# BioAnalysis

BioAnalysis is an English-first genome-analysis workflow and helper-script toolkit. It turns common genome project tasks into reusable SOPs, command templates, validation checks, portable local scripts, and stage-level workflow drivers.

The repository is designed for continuous extension. New workflows can be added as numbered script stages, documented in the SOP and command templates, and validated with `make check-all`.

All examples use anonymized Arabidopsis-style placeholders such as `Arabidopsis_thaliana`, `Arabidopsis_lyrata`, and `Arabidopsis_halleri`. Replace them with project-specific IDs only in private run directories, not in reusable repository files.

## Repository layout

```text
bioAnalysis/
  README.md
  Makefile
  config/
    project.example.env
  docs/
    README.md
    BioAnalysis_Run_Checklist.md
    BioAnalysis_Genome_Workflow_SOP.md
    BioAnalysis_Genome_Command_Templates.md
    BioAnalysis_Genome_Software_List.md
    BioAnalysis_Template_Script_List.md
  scripts/
    README.md
    SCRIPT_SOURCES.md
    common/
    01_preprocessing/
    02_assembly/
    03_repeat/
    04_gff/
    05_genome_features/
    06_annotation/
    07_gene_family/
    08_gene_family_evolution/
    09_synteny/
    10_hgt/
    11_visualization/
```

## Start here

Read the repository in this order:

1. [`docs/README.md`](docs/README.md) — documentation map and repository conventions.
2. [`config/project.example.env`](config/project.example.env) — anonymized project variable template.
3. [`docs/BioAnalysis_Run_Checklist.md`](docs/BioAnalysis_Run_Checklist.md) — execution gate checklist.
4. [`docs/BioAnalysis_Genome_Workflow_SOP.md`](docs/BioAnalysis_Genome_Workflow_SOP.md) — end-to-end workflow SOP.
5. [`docs/BioAnalysis_Genome_Command_Templates.md`](docs/BioAnalysis_Genome_Command_Templates.md) — command examples.
6. [`docs/BioAnalysis_Genome_Software_List.md`](docs/BioAnalysis_Genome_Software_List.md) — external tools and dependencies.
7. [`docs/BioAnalysis_Template_Script_List.md`](docs/BioAnalysis_Template_Script_List.md) — script reference.
8. [`scripts/SCRIPT_SOURCES.md`](scripts/SCRIPT_SOURCES.md) — script provenance and status.

## Workflow stages

```text
01 preprocessing and contamination screening
02 assembly statistics and QC helpers
03 repeat annotation, TE post-processing, and EVE/GEVE region handoffs
04 GFF/CDS/PEP extraction
05 genome features, introns, region context, and methylation workflows
06 functional annotation, COG/NOG summaries, and GO handoffs
07 gene families, target-family discovery, expression evidence, and phylogeny helpers
08 gene-family evolution with Count, CAFE, and target-family integration
09 synteny context, MCScan/JCVI summaries, heatmaps, and Circos links
10 HGT candidate screening and validation handoff
11 visualization matrices and handoff helpers
```

## Extension policy

When adding a new workflow:

1. Add scripts under the next numbered stage or the most relevant existing stage.
2. Keep examples anonymized with Arabidopsis-style names.
3. Do not commit real project paths, real sample names, private database locations, or user-specific installation paths.
4. Add command templates and SOP/checklist entries.
5. Add script provenance and status to `scripts/SCRIPT_SOURCES.md`.
6. Add validation checks when the workflow has CLI scripts.
7. Keep all repository-facing text in English.
8. Run `make check-all` before committing.

## Minimal checks

```bash
make check-all
```

Individual checks are available:

```bash
make check-python
make check-shell
make check-perl
make check-doc-links
make check-hardcoded-paths
make check-cli-docs
make check-english
make check-numbered-layout
```

Third-party tools are not vendored. Install them separately and document versions in project-specific run notes.
