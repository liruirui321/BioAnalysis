.PHONY: help check-python check-shell check-perl check-doc-links check-hardcoded-paths check-cli-docs check-english check-numbered-layout check-script-help check-all

help:
	@printf '%s\n' 'BioAnalysis validation targets:'
	@printf '%s\n' '  make check-python          Compile Python helper scripts'
	@printf '%s\n' '  make check-shell           Syntax-check shell scripts'
	@printf '%s\n' '  make check-perl            Syntax-check key Perl scripts when dependencies are available'
	@printf '%s\n' '  make check-doc-links       Verify repository files referenced by docs exist'
	@printf '%s\n' '  make check-hardcoded-paths Detect private paths/usernames in reusable files'
	@printf '%s\n' '  make check-cli-docs        Detect stale documented CLI flags'
	@printf '%s\n' '  make check-english         Detect CJK text in maintained repository files'
	@printf '%s\n' '  make check-numbered-layout Verify numbered script directories exist'
	@printf '%s\n' '  make check-script-help     Smoke-test key script --help commands'
	@printf '%s\n' '  make check-all             Run all checks'

check-python:
	python3 -m py_compile $$(find scripts -type f -name "*.py" ! -path "*/__pycache__/*")

check-shell:
	find scripts -type f -name "*.sh" -exec bash -n {} \;

check-perl:
	@perl -c scripts/06_annotation/kegg/pathfind.pl
	@perl -c scripts/06_annotation/kegg/pathfind.v2.pl
	@perl -c scripts/06_annotation/kegg/getKO.pl

check-doc-links:
	@test -f config/project.example.env
	@test -f docs/BioAnalysis_Run_Checklist.md
	@test -f docs/BioAnalysis_Genome_Workflow_SOP.md
	@test -f docs/BioAnalysis_Genome_Command_Templates.md
	@test -f docs/BioAnalysis_Genome_Software_List.md
	@test -f docs/BioAnalysis_Template_Script_List.md
	@test -f scripts/README.md
	@test -f scripts/SCRIPT_SOURCES.md
	@test -f scripts/01_preprocessing/01_nt_decontaminate_contigs.sh
	@test -f scripts/05_genome_features/extract_introns.py
	@test -f scripts/05_genome_features/run_introner_elements.sh
	@test -f scripts/10_hgt/01_classify_hgt_hits.py
	@test -f scripts/10_hgt/02_score_hgt_candidates.py
	@test -f scripts/10_hgt/03_add_hgt_context.py
	@test -f scripts/10_hgt/04_prepare_hgt_validation.py

check-hardcoded-paths:
	@! grep -R -n -E '/media/desk1[0-9]/|/Files/|/opt/software|/home/|liuruoyu|chenxiayi|Cyanoptyche' README.md docs scripts config --exclude='SCRIPT_SOURCES.md'

check-cli-docs:
	@! grep -R -n -E -- '--input_dir|--species_list|--out_fasta|--out_phylip|--max_copy|--min_species|--orthofinder_count|--species_tree' docs scripts

check-english:
	@! grep -R -n -P '[\x{4e00}-\x{9fff}]' README.md Makefile config docs scripts/README.md scripts/SCRIPT_SOURCES.md scripts/01_preprocessing scripts/02_assembly scripts/03_repeat scripts/04_gff scripts/05_genome_features scripts/06_annotation scripts/07_phylogeny scripts/08_cafe scripts/09_synteny scripts/10_hgt --exclude-dir='__pycache__' --exclude='*.pl'

check-numbered-layout:
	@test -d scripts/common
	@test -d scripts/01_preprocessing
	@test -d scripts/02_assembly
	@test -d scripts/03_repeat
	@test -d scripts/04_gff
	@test -d scripts/05_genome_features
	@test -d scripts/06_annotation
	@test -d scripts/07_phylogeny
	@test -d scripts/08_cafe
	@test -d scripts/09_synteny
	@test -d scripts/10_hgt
	@test -d scripts/11_visualization
	@! test -d scripts/assembly
	@! test -d scripts/repeat
	@! test -d scripts/gff
	@! test -d scripts/annotation
	@! test -d scripts/genome_features
	@! test -d scripts/phylogeny
	@! test -d scripts/cafe
	@! test -d scripts/synteny
	@! test -d scripts/kegg
	@! test -d scripts/tree
	@! test -d scripts/visualization

check-script-help:
	@bash scripts/01_preprocessing/01_nt_decontaminate_contigs.sh --help >/dev/null
	@python3 scripts/02_assembly/assembly_stats.py --help >/dev/null
	@bash scripts/03_repeat/LTR_Finder.sh --help >/dev/null
	@bash scripts/03_repeat/LTR_harvest.sh --help >/dev/null
	@python3 scripts/05_genome_features/extract_introns.py --help >/dev/null
	@bash scripts/05_genome_features/run_introner_elements.sh --help >/dev/null
	@python3 scripts/10_hgt/01_classify_hgt_hits.py --help >/dev/null
	@python3 scripts/10_hgt/02_score_hgt_candidates.py --help >/dev/null
	@python3 scripts/10_hgt/03_add_hgt_context.py --help >/dev/null
	@python3 scripts/10_hgt/04_prepare_hgt_validation.py --help >/dev/null

check-all: check-python check-shell check-perl check-doc-links check-hardcoded-paths check-cli-docs check-english check-numbered-layout check-script-help
