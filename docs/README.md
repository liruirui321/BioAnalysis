# BioAnalysis Documentation

This directory contains English documentation for the BioAnalysis genome workflow toolkit. The documents are repository documentation, not a project diary.

## Documentation map

| Document | Purpose |
|---|---|
| [`BioAnalysis_Run_Checklist.md`](BioAnalysis_Run_Checklist.md) | Stage-by-stage execution checklist and stop conditions. |
| [`BioAnalysis_Genome_Workflow_SOP.md`](BioAnalysis_Genome_Workflow_SOP.md) | End-to-end SOP for genome analysis workflows. |
| [`BioAnalysis_Genome_Command_Templates.md`](BioAnalysis_Genome_Command_Templates.md) | Copy-editable command templates using anonymized example IDs. |
| [`BioAnalysis_Genome_Software_List.md`](BioAnalysis_Genome_Software_List.md) | External tools, dependencies, and database notes. |
| [`BioAnalysis_Template_Script_List.md`](BioAnalysis_Template_Script_List.md) | Script inventory organized by numbered workflow stage. |
| [`../scripts/README.md`](../scripts/README.md) | Script directory layout and extension rules. |
| [`../scripts/SCRIPT_SOURCES.md`](../scripts/SCRIPT_SOURCES.md) | Script provenance, implementation status, and review notes. |

## Workflow principle

Each workflow module should state:

```text
Input -> Command/script -> Expected output -> QC -> Next input
```

## Anonymization rule

Use placeholders such as:

```text
Arabidopsis_thaliana
Arabidopsis_lyrata
Arabidopsis_halleri
Arabidopsis_suecica
```

Do not commit real species names, sample IDs, user names, private mount paths, or database paths into reusable documentation.

## Continuous updates

The repository is intended to grow. Add new workflow modules by placing scripts in a numbered stage directory, documenting command templates, adding SOP/checklist entries, and running `make check-all` before commit.
