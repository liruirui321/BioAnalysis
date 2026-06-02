# Stage 04 gene prediction and RNA evidence alignment

Use this directory after repeat masking or soft-masking and before downstream GFF/CDS/PEP cleanup in `../04_gff/`.

## Recommended order

1. Filter RNA-seq reads in Stage 01.
2. Align RNA-seq reads to the masked genome with HISAT2.
3. Run BRAKER3 with the soft-masked genome, protein evidence, and RNA BAM evidence.
4. Review BRAKER logs and handoff GFF3/GTF/CDS/protein files.
5. Pass the selected annotation GFF and genome FASTA to Stage 04 GFF cleanup.

## RNA evidence alignment

```bash
bash run_hisat2_rnaseq_alignment_workflow.sh \
  --masked-genome Arabidopsis_thaliana.genome.softmasked.fa \
  --pe1 Arabidopsis_thaliana.flower_R1.clean.fq.gz \
  --pe2 Arabidopsis_thaliana.flower_R2.clean.fq.gz \
  --outdir rnaseq_alignment \
  --output-name Arabidopsis_thaliana \
  --threads 16 \
  --dta
```

Expected outputs include sorted BAM, BAM index, HISAT2 build/alignment logs, runtime log, and manifest.

## BRAKER3 annotation

```bash
bash run_braker3_annotation_workflow.sh \
  --genome Arabidopsis_thaliana.genome.softmasked.fa \
  --proteins Arabidopsis_thaliana.related_species.proteins.fa \
  --rnaseq-bam rnaseq_alignment/Arabidopsis_thaliana.rnaseq.sorted.bam \
  --species Arabidopsis_thaliana \
  --outdir braker3_annotation \
  --prefix Arabidopsis_thaliana \
  --rounds 20 \
  --threads 20 \
  --add-utr \
  --augustus-config-source refs/augustus_config
```

Tool and database paths such as AUGUSTUS config, GeneMark, ProtHint, TSEBRA, and DIAMOND must be passed at runtime. Do not commit local tool paths.

## QC checks

- Masked genome FASTA is non-empty and matches RNA BAM reference names.
- RNA BAM and index are non-empty.
- Protein evidence source is documented.
- AUGUSTUS config is writable in the work directory.
- BRAKER GFF3 is reviewed before Stage 04 GFF/CDS/PEP extraction.
