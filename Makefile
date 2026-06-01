.PHONY: help check-python check-shell check-perl check-doc-links check-hardcoded-paths check-cli-docs check-all

help:
	@printf '%s\n' 'BioAnalysis validation targets:'
	@printf '%s\n' '  make check-python          Compile Python helper scripts'
	@printf '%s\n' '  make check-shell           Syntax-check shell scripts'
	@printf '%s\n' '  make check-perl            Syntax-check key Perl scripts when dependencies are available'
	@printf '%s\n' '  make check-doc-links       Verify repository files referenced by docs exist'
	@printf '%s\n' '  make check-hardcoded-paths Detect historical local paths/usernames in reusable files'
	@printf '%s\n' '  make check-cli-docs        Detect stale documented CLI flags'
	@printf '%s\n' '  make check-all             Run all checks'

check-python:
	python3 -m py_compile $$(find scripts -type f -name "*.py")

check-shell:
	find scripts -type f -name "*.sh" -exec bash -n {} \;

check-perl:
	@perl -c scripts/kegg/pathfind.pl
	@perl -c scripts/kegg/pathfind.v2.pl
	@perl -c scripts/kegg/getKO.pl

check-doc-links:
	@test -f config/project.example.env
	@test -f docs/BioAnalysis_Run_Checklist.md
	@test -f docs/BioAnalysis_Genome_Workflow_SOP.md
	@test -f docs/BioAnalysis_Genome_Command_Templates.md
	@test -f docs/BioAnalysis_Genome_Software_List.md
	@test -f docs/BioAnalysis_Template_Script_List.md
	@test -f scripts/SCRIPT_SOURCES.md
	@test -f scripts/README.md

check-hardcoded-paths:
	@! grep -R -n -E '/media/desk1[0-9]/|/home/|liuruoyu|chenxiayi|Cyanoptyche' README.md docs scripts config --exclude='SCRIPT_SOURCES.md'

check-cli-docs:
	@! grep -R -n -E -- '--input_dir|--species_list|--out_fasta|--out_phylip|--max_copy|--min_species|--orthofinder_count|--species_tree' docs

check-all: check-python check-shell check-perl check-doc-links check-hardcoded-paths check-cli-docs
