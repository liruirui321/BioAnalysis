# BioAnalysis Genome Workflow Documentation

BioAnalysis is a genome analysis workflow documentation and script toolkit. It distills reusable genome-analysis methods into executable, traceable modules covering assembly, quality assessment, repeat annotation, gene annotation, functional annotation, gene family analysis, phylogenomics, gene-tree construction, synteny, Circos visualization and domain statistics.

The documents in this directory are written as repository documentation, not as a project note. They describe how to run the workflow, what each script expects, what each step produces, and how outputs become inputs for the next step.

---

## Documentation map

| Document | Purpose |
|---|---|
| [`BioAnalysis_Run_Checklist.md`](BioAnalysis_Run_Checklist.md) | Execution gate checklist for running a project from inputs to final deliverables. |
| [`BioAnalysis_Genome_Workflow_SOP.md`](BioAnalysis_Genome_Workflow_SOP.md) | End-to-end method workflow. Use this as the main methods/SOP document. |
| [`BioAnalysis_Genome_Command_Templates.md`](BioAnalysis_Genome_Command_Templates.md) | Command-line examples for each workflow stage. |
| [`BioAnalysis_Genome_Software_List.md`](BioAnalysis_Genome_Software_List.md) | Software, external dependencies, databases, and key parameters. |
| [`BioAnalysis_Template_Script_List.md`](BioAnalysis_Template_Script_List.md) | Script reference: source status, inputs, outputs, and handoff targets. |
| [`../scripts/README.md`](../scripts/README.md) | Script directory layout and implementation notes. |
| [`../scripts/SCRIPT_SOURCES.md`](../scripts/SCRIPT_SOURCES.md) | Provenance of copied reference scripts and BioAnalysis glue scripts. |

---

## Repository-style workflow overview

```text
raw reads / existing genome resources
  -> assembly and polishing
  -> assembly QC
  -> repeat annotation
  -> gene structure annotation
  -> GFF/CDS/PEP extraction and QC
  -> functional annotation
  -> orthogroup inference
  -> species tree and gene trees
  -> expansion/contraction analysis
  -> synteny and Circos visualization
  -> domain statistics and evidence tables
```

The key design rule is that every step must declare:

```text
Input -> Command/script -> Output -> QC -> Next input
```

---

## Script source policy

Scripts are split into two categories:

1. **Reference-derived scripts** copied from the user-provided reference path and kept with source notes.
2. **BioAnalysis glue scripts** written to connect workflow outputs to downstream inputs.

Third-party software entry points are not reimplemented. Examples: `BRAKER`, `InterProScan`, `eggNOG-mapper`, `OrthoFinder`, `MAFFT`, `RAxML`, `IQ-TREE`, `RepeatMasker`, `Merqury`, `Circos`.

See [`../scripts/SCRIPT_SOURCES.md`](../scripts/SCRIPT_SOURCES.md) for exact provenance.

---

## Minimal run philosophy

A complete project should produce at least:

```text
assembly statistics
BUSCO/compleasm report
Merqury/QV report when reads are available
repeat library and RepeatMasker annotation
clean GFF/CDS/PEP files
CDS quality check table
functional_annotation.tsv
Orthogroups.tsv and GeneCount.tsv
species tree
selected gene trees
synteny blocks / anchors
Circos tracks
Pfam/domain matrix
```

---

## Anonymized examples

All examples use Arabidopsis-style placeholder names such as:

```text
Arabidopsis_thaliana
Arabidopsis_lyrata
Arabidopsis_halleri
Arabidopsis_suecica
```

These are placeholders only. Replace them with project-specific sample IDs when executing a real analysis.

---

## Current scope notes

- KEGG enrichment scripts exist under `scripts/kegg/` and were copied from the provided reference script path.
- No GO enrichment script was found in the provided reference script path during the current scan; therefore GO enrichment is not documented as an implemented reference script.
- Several Circos helper scripts require Perl/BioPerl modules in the runtime environment.
