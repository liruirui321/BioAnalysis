#!/usr/bin/env Rscript

usage <- function() {
  cat("Usage: plot_gff_structure.R --metrics metrics.tsv --distributions distributions.tsv --out-prefix PREFIX\n")
  cat("\nCreate base-R PDF plots for GFF structure summaries.\n")
}

args <- commandArgs(trailingOnly = TRUE)
if (any(args %in% c("-h", "--help"))) {
  usage()
  quit(status = 0)
}

get_arg <- function(name, required = TRUE) {
  idx <- which(args == name)
  if (length(idx) == 0) {
    if (required) {
      stop(paste("Missing", name), call. = FALSE)
    }
    return(NA)
  }
  if (idx[1] == length(args)) {
    stop(paste("Missing value for", name), call. = FALSE)
  }
  args[idx[1] + 1]
}

metrics_file <- get_arg("--metrics")
distributions_file <- get_arg("--distributions")
out_prefix <- get_arg("--out-prefix")

metrics <- read.delim(metrics_file, stringsAsFactors = FALSE, check.names = FALSE)
distributions <- read.delim(distributions_file, stringsAsFactors = FALSE, check.names = FALSE)
metrics$value_numeric <- suppressWarnings(as.numeric(metrics$value))

gene_metrics <- metrics[metrics$metric %in% c("genes", "transcripts", "exons", "cds_features", "introns"), ]
if (nrow(gene_metrics) > 0) {
  pdf(paste0(out_prefix, ".feature_counts.pdf"), width = 9, height = 5)
  y_max <- max(gene_metrics$value_numeric, na.rm = TRUE)
  if (!is.finite(y_max)) y_max <- 1
  barplot(
    height = gene_metrics$value_numeric,
    names.arg = paste(gene_metrics$species, gene_metrics$metric, sep = "\n"),
    las = 2,
    cex.names = 0.7,
    ylim = c(0, y_max * 1.15),
    ylab = "Count",
    main = "GFF feature counts"
  )
  dev.off()
}

plot_categories <- c("gene_length", "transcript_length", "intron_length", "exons_per_transcript", "isoforms_per_gene")
for (category in plot_categories) {
  subset <- distributions[distributions$category == category, ]
  if (nrow(subset) == 0) next
  value_col <- if (all(is.na(suppressWarnings(as.numeric(subset$length))))) "count" else "length"
  values <- suppressWarnings(as.numeric(subset[[value_col]]))
  keep <- is.finite(values)
  if (!any(keep)) next
  subset <- subset[keep, ]
  values <- values[keep]
  pdf(paste0(out_prefix, ".", category, ".pdf"), width = 8, height = 5)
  boxplot(values ~ subset$species, las = 2, ylab = value_col, main = category)
  dev.off()
}
