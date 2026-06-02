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
	@test -f scripts/02_assembly/assembly_stats.py
	@test -f scripts/02_genome_survey/run_genome_survey_workflow.sh
	@test -f scripts/02_genome_survey/run_ploidyngs_workflow.sh
	@test -f scripts/02_assembly/run_hifiasm_assembly.sh
	@test -f scripts/02_assembly/run_nextdenovo_assembly.sh
	@test -f scripts/02_assembly/run_spades_assembly.sh
	@test -f scripts/02_assembly/run_flye_assembly.sh
	@test -f scripts/02_assembly/run_canu_assembly.sh
	@test -f scripts/02_assembly/run_verkko_assembly.sh
	@test -f scripts/02_assembly/run_yahs_scaffolding.sh
	@test -f scripts/02_assembly/run_haphic_scaffolding.sh
	@test -f scripts/02_assembly/run_busco_qc_workflow.sh
	@test -f scripts/02_assembly/run_lai_qc_workflow.sh
	@test -f scripts/02_assembly/run_merqury_qv_workflow.sh
	@test -f scripts/02_assembly/summarize_busco_results.py
	@test -f scripts/02_assembly/summarize_lai_results.py
	@test -f scripts/02_assembly/summarize_merqury_qv.py
	@test -f scripts/03_repeat/run_repeat_annotation_workflow.sh
	@test -f scripts/03_repeat/run_te_eve_postprocessing_workflow.sh
	@test -f scripts/03_repeat/parse_tesorter_domains.py
	@test -f scripts/03_repeat/summarize_tesorter_regions.py
	@test -f scripts/03_repeat/summarize_te_divergence.py
	@test -f scripts/03_repeat/standardize_eve_geve_regions.py
	@test -f scripts/04_gff/gff_cds_pep.py
	@test -f scripts/04_gff/run_gff_structure_workflow.sh
	@test -f scripts/04_gff/summarize_gff_structure.py
	@test -f scripts/04_gff/prepare_gff_structure_plot_handoff.py
	@test -f scripts/04_gff/plot_gff_structure.R
	@test -f scripts/05_genome_features/run_genome_features_workflow.sh
	@test -f scripts/05_genome_features/run_region_context_workflow.sh
	@test -f scripts/05_genome_features/extract_introns.py
	@test -f scripts/05_genome_features/compare_region_feature_enrichment.py
	@test -f scripts/05_genome_features/summarize_bismark_cx_regions.py
	@test -f scripts/05_genome_features/run_introner_elements.sh
	@test -f scripts/06_annotation/summarize_go_terms.py
	@test -f scripts/06_annotation/summarize_kegg_pathways.py
	@test -f scripts/06_annotation/summarize_pfam_domains.py
	@test -f scripts/06_annotation/summarize_domain_architecture.py
	@test -f scripts/06_annotation/summarize_eggnog_categories.py
	@test -f scripts/06_annotation/enrich_annotation_terms.py
	@test -f scripts/06_annotation/prepare_go_semantic_handoff.py
	@test -f scripts/06_annotation/run_functional_annotation_workflow.sh
	@test -f scripts/06_annotation/run_go_enrichment_plot_handoff.sh
	@test -f scripts/07_gene_family/run_gene_family_workflow.sh
	@test -f scripts/07_gene_family/run_target_family_workflow.sh
	@test -f scripts/07_gene_family/merge_target_family_evidence.py
	@test -f scripts/07_gene_family/build_target_family_inputs.py
	@test -f scripts/07_gene_family/summarize_gene_set_expression.py
	@test -f scripts/07_gene_family/summarize_orthofinder_gene_families.py
	@test -f scripts/08_gene_family_evolution/run_gene_family_evolution_workflow.sh
	@test -f scripts/08_gene_family_evolution/prepare_count_input.py
	@test -f scripts/08_gene_family_evolution/parse_count_gain_loss.py
	@test -f scripts/08_gene_family_evolution/summarize_family_gain_loss.py
	@test -f scripts/08_gene_family_evolution/integrate_target_family_evolution.py
	@test -f scripts/09_synteny/run_synteny_context_workflow.sh
	@test -f scripts/09_synteny/summarize_mcscan_jcvi_synteny.py
	@test -f scripts/09_synteny/build_synteny_heatmap_matrix.py
	@test -f scripts/09_synteny/compare_region_synteny.py
	@test -f scripts/09_synteny/anchors_to_circos_links.py
	@test -f scripts/10_hgt/run_hgt_blast2hgt_workflow.sh
	@test -f scripts/10_hgt/run_hgt_family_integration_workflow.sh
	@test -f scripts/10_hgt/00_run_blast2hgt_handoff.sh
	@test -f scripts/10_hgt/filter_blast2hgt_candidates.py
	@test -f scripts/10_hgt/refine_hgt_donor_taxonomy.py
	@test -f scripts/10_hgt/integrate_hgt_family_evolution.py
	@test -f scripts/10_hgt/01_classify_hgt_hits.py
	@test -f scripts/10_hgt/02_score_hgt_candidates.py
	@test -f scripts/10_hgt/03_add_hgt_context.py
	@test -f scripts/10_hgt/04_prepare_hgt_validation.py
	@test -f scripts/11_visualization/run_visualization_handoff_workflow.sh
	@test -f scripts/11_visualization/build_gene_set_matrix.py
	@test -f scripts/11_visualization/prepare_family_visualization_matrices.py

check-hardcoded-paths:
	@! grep -R -n -E '/media/desk1[0-9]/|/Files/|/opt/software|/home/|liuruoyu|chenxiayi|Cyanoptyche' README.md docs scripts config --exclude='SCRIPT_SOURCES.md'

check-cli-docs:
	@! grep -R -n -E -- '--input_dir|--species_list|--out_fasta|--out_phylip|--max_copy|--min_species|--orthofinder_count|--species_tree' docs scripts

check-english:
	@! grep -R -n -P '[\x{4e00}-\x{9fff}]' README.md Makefile config docs scripts/README.md scripts/SCRIPT_SOURCES.md scripts/01_preprocessing scripts/02_assembly scripts/03_repeat scripts/04_gff scripts/05_genome_features scripts/06_annotation scripts/07_gene_family scripts/08_gene_family_evolution scripts/09_synteny scripts/10_hgt scripts/11_visualization --exclude-dir='__pycache__' --exclude='*.pl'

check-numbered-layout:
	@test -d scripts/common
	@test -d scripts/01_preprocessing
	@test -d scripts/02_genome_survey
	@test -d scripts/02_assembly
	@test -d scripts/03_repeat
	@test -d scripts/04_gff
	@test -d scripts/05_genome_features
	@test -d scripts/06_annotation
	@test -d scripts/07_gene_family
	@test -d scripts/08_gene_family_evolution
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
	@bash scripts/02_genome_survey/run_genome_survey_workflow.sh --help >/dev/null
	@bash scripts/02_genome_survey/run_ploidyngs_workflow.sh --help >/dev/null
	@bash scripts/02_assembly/run_hifiasm_assembly.sh --help >/dev/null
	@bash scripts/02_assembly/run_nextdenovo_assembly.sh --help >/dev/null
	@bash scripts/02_assembly/run_spades_assembly.sh --help >/dev/null
	@bash scripts/02_assembly/run_flye_assembly.sh --help >/dev/null
	@bash scripts/02_assembly/run_canu_assembly.sh --help >/dev/null
	@bash scripts/02_assembly/run_verkko_assembly.sh --help >/dev/null
	@bash scripts/02_assembly/run_yahs_scaffolding.sh --help >/dev/null
	@bash scripts/02_assembly/run_haphic_scaffolding.sh --help >/dev/null
	@bash scripts/02_assembly/run_busco_qc_workflow.sh --help >/dev/null
	@bash scripts/02_assembly/run_lai_qc_workflow.sh --help >/dev/null
	@bash scripts/02_assembly/run_merqury_qv_workflow.sh --help >/dev/null
	@python3 scripts/02_assembly/summarize_busco_results.py --help >/dev/null
	@python3 scripts/02_assembly/summarize_lai_results.py --help >/dev/null
	@python3 scripts/02_assembly/summarize_merqury_qv.py --help >/dev/null
	@bash scripts/03_repeat/LTR_Finder.sh --help >/dev/null
	@bash scripts/03_repeat/LTR_harvest.sh --help >/dev/null
	@bash scripts/03_repeat/run_repeat_annotation_workflow.sh --help >/dev/null
	@bash scripts/03_repeat/run_te_eve_postprocessing_workflow.sh --help >/dev/null
	@python3 scripts/03_repeat/parse_tesorter_domains.py --help >/dev/null
	@python3 scripts/03_repeat/summarize_tesorter_regions.py --help >/dev/null
	@python3 scripts/03_repeat/summarize_te_divergence.py --help >/dev/null
	@python3 scripts/03_repeat/standardize_eve_geve_regions.py --help >/dev/null
	@python3 scripts/04_gff/gff_cds_pep.py --help >/dev/null
	@bash scripts/04_gff/run_gff_structure_workflow.sh --help >/dev/null
	@python3 scripts/04_gff/summarize_gff_structure.py --help >/dev/null
	@python3 scripts/04_gff/prepare_gff_structure_plot_handoff.py --help >/dev/null
	@Rscript scripts/04_gff/plot_gff_structure.R --help >/dev/null
	@bash scripts/05_genome_features/run_genome_features_workflow.sh --help >/dev/null
	@bash scripts/05_genome_features/run_region_context_workflow.sh --help >/dev/null
	@python3 scripts/05_genome_features/extract_introns.py --help >/dev/null
	@python3 scripts/05_genome_features/compare_region_feature_enrichment.py --help >/dev/null
	@python3 scripts/05_genome_features/summarize_bismark_cx_regions.py --help >/dev/null
	@bash scripts/05_genome_features/run_introner_elements.sh --help >/dev/null
	@python3 scripts/06_annotation/parse_interproscan_tsv.py --help >/dev/null
	@python3 scripts/06_annotation/parse_kofam_detail.py --help >/dev/null
	@python3 scripts/06_annotation/merge_function_annotations.py --help >/dev/null
	@python3 scripts/06_annotation/summarize_go_terms.py --help >/dev/null
	@python3 scripts/06_annotation/summarize_kegg_pathways.py --help >/dev/null
	@python3 scripts/06_annotation/summarize_pfam_domains.py --help >/dev/null
	@python3 scripts/06_annotation/summarize_domain_architecture.py --help >/dev/null
	@python3 scripts/06_annotation/summarize_eggnog_categories.py --help >/dev/null
	@python3 scripts/06_annotation/enrich_annotation_terms.py --help >/dev/null
	@python3 scripts/06_annotation/prepare_go_semantic_handoff.py --help >/dev/null
	@bash scripts/06_annotation/run_functional_annotation_workflow.sh --help >/dev/null
	@bash scripts/06_annotation/run_go_enrichment_plot_handoff.sh --help >/dev/null
	@bash scripts/07_gene_family/run_gene_family_workflow.sh --help >/dev/null
	@bash scripts/07_gene_family/run_target_family_workflow.sh --help >/dev/null
	@python3 scripts/07_gene_family/merge_target_family_evidence.py --help >/dev/null
	@python3 scripts/07_gene_family/build_target_family_inputs.py --help >/dev/null
	@python3 scripts/07_gene_family/summarize_gene_set_expression.py --help >/dev/null
	@python3 scripts/07_gene_family/prefix_fasta_ids.py --help >/dev/null
	@python3 scripts/07_gene_family/summarize_orthofinder_gene_families.py --help >/dev/null
	@python3 scripts/07_gene_family/extract_orthogroup_members.py --help >/dev/null
	@python3 scripts/07_gene_family/concat_alignments.py --help >/dev/null
	@bash scripts/08_gene_family_evolution/run_gene_family_evolution_workflow.sh --help >/dev/null
	@python3 scripts/08_gene_family_evolution/prepare_count_input.py --help >/dev/null
	@python3 scripts/08_gene_family_evolution/parse_count_gain_loss.py --help >/dev/null
	@python3 scripts/08_gene_family_evolution/summarize_family_gain_loss.py --help >/dev/null
	@python3 scripts/08_gene_family_evolution/integrate_target_family_evolution.py --help >/dev/null
	@python3 scripts/08_gene_family_evolution/prepare_cafe_input.py --help >/dev/null
	@python3 scripts/08_gene_family_evolution/filter_cafe_families.py --help >/dev/null
	@bash scripts/09_synteny/run_synteny_context_workflow.sh --help >/dev/null
	@python3 scripts/09_synteny/summarize_mcscan_jcvi_synteny.py --help >/dev/null
	@python3 scripts/09_synteny/build_synteny_heatmap_matrix.py --help >/dev/null
	@python3 scripts/09_synteny/compare_region_synteny.py --help >/dev/null
	@python3 scripts/09_synteny/anchors_to_circos_links.py --help >/dev/null
	@bash scripts/10_hgt/run_hgt_blast2hgt_workflow.sh --help >/dev/null
	@bash scripts/10_hgt/run_hgt_family_integration_workflow.sh --help >/dev/null
	@bash scripts/10_hgt/00_run_blast2hgt_handoff.sh --help >/dev/null
	@python3 scripts/10_hgt/filter_blast2hgt_candidates.py --help >/dev/null
	@python3 scripts/10_hgt/refine_hgt_donor_taxonomy.py --help >/dev/null
	@python3 scripts/10_hgt/integrate_hgt_family_evolution.py --help >/dev/null
	@python3 scripts/10_hgt/01_classify_hgt_hits.py --help >/dev/null
	@python3 scripts/10_hgt/02_score_hgt_candidates.py --help >/dev/null
	@python3 scripts/10_hgt/03_add_hgt_context.py --help >/dev/null
	@python3 scripts/10_hgt/04_prepare_hgt_validation.py --help >/dev/null
	@bash scripts/11_visualization/run_visualization_handoff_workflow.sh --help >/dev/null
	@python3 scripts/11_visualization/build_gene_set_matrix.py --help >/dev/null
	@python3 scripts/11_visualization/prepare_family_visualization_matrices.py --help >/dev/null

check-all: check-python check-shell check-perl check-doc-links check-hardcoded-paths check-cli-docs check-english check-numbered-layout check-script-help
