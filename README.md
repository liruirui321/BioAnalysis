# BioAnalysis

BioAnalysis is a genome-analysis workflow and script toolkit for turning genome project resources into reproducible methods, command templates, and executable helper scripts.

The repository focuses on method-level reproducibility for genome projects, including:

- genome assembly and polishing handoff documentation
- assembly quality assessment
- repeat annotation
- gene structure annotation
- GFF/CDS/PEP extraction and QC
- functional annotation
- KEGG pathway analysis using reference scripts
- orthogroup inference
- species tree and gene tree construction
- expansion/contraction analysis
- synteny and Circos visualization
- Pfam/domain statistics

All example species names in documentation are placeholders based on Arabidopsis-style names. Replace them with project-specific sample IDs when running analyses.

---

## Repository layout

```text
bioAnalysis/
  README.md
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
    assembly/
    annotation/
    cafe/
    genome_features/
    gff/
    kegg/
    phylogeny/
    repeat/
    synteny/
    tree/
    visualization/
```

---

## Start here

Read the documentation in this order:

1. [`docs/README.md`](docs/README.md) — documentation map and workflow philosophy.
2. [`config/project.example.env`](config/project.example.env) — anonymized project variable template.
3. [`docs/BioAnalysis_Run_Checklist.md`](docs/BioAnalysis_Run_Checklist.md) — execution gate checklist.
4. [`docs/BioAnalysis_Genome_Workflow_SOP.md`](docs/BioAnalysis_Genome_Workflow_SOP.md) — end-to-end methods workflow.
5. [`docs/BioAnalysis_Genome_Command_Templates.md`](docs/BioAnalysis_Genome_Command_Templates.md) — command templates.
6. [`docs/BioAnalysis_Genome_Software_List.md`](docs/BioAnalysis_Genome_Software_List.md) — external tools and dependencies.
7. [`docs/BioAnalysis_Template_Script_List.md`](docs/BioAnalysis_Template_Script_List.md) — script reference.
8. [`scripts/SCRIPT_SOURCES.md`](scripts/SCRIPT_SOURCES.md) — script provenance.

---

## Script policy

This repository contains two kinds of scripts:

1. **Copied reference scripts** from the user-provided reference script path.
2. **BioAnalysis glue scripts** that connect workflow outputs to downstream inputs.

Third-party tools are not reimplemented. Install them separately and make sure they are available in your runtime environment.

Examples of external tools:

```text
hifiasm
NextDenovo
SPAdes
Canu
purge_dups
NextPolish
HiC-Pro
HapHiC
BUSCO
compleasm
Merqury
LTR_FINDER_parallel
GenomeTools / LTRharvest
LTR_retriever
RepeatModeler
RepeatMasker
BRAKER3
InterProScan
eggNOG-mapper
KofamScan
DIAMOND
OrthoFinder
MAFFT
trimAl
RAxML
IQ-TREE
MrBayes
CAFE
WGDI
MCScanX
JCVI
Circos
```

---

## Important notes

- KEGG/pathway scripts are included under `scripts/kegg/` from the reference script path.
- No GO enrichment script was found in the provided reference script path during the current scan; GO enrichment is not included as a copied reference script.
- Some Circos helper scripts require Perl/BioPerl modules such as `Bio::Seq`.
- Reference scripts may still contain assumptions from their original environment; check `scripts/SCRIPT_SOURCES.md` before using them directly.

---

## Minimal checks

```bash
python3 -m py_compile $(find scripts -type f -name "*.py")
bash -n scripts/repeat/repeat_stat.sh
perl -c scripts/kegg/pathfind.pl
```

Some copied Perl scripts may require additional Perl modules for full syntax/runtime checks.
