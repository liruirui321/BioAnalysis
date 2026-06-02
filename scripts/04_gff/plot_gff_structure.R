#!/usr/bin/env Rscript

usage <- function() {
  cat("Usage: plot_gff_structure.R --reference-distribution reference_distribution.tsv --out-prefix PREFIX [options]\n")
  cat("\nCreate reference-style GFF structure distribution PDFs.\n")
  cat("Outputs:\n")
  cat("  PREFIX.gene_length_distribution.pdf  mRNA/CDS/exon/intron percentage distributions\n")
  cat("  PREFIX.exon_number.pdf               exon-number percentage distribution\n")
  cat("\nOptions:\n")
  cat("  --metrics FILE              Accepted for workflow compatibility\n")
  cat("  --distributions FILE        Accepted for workflow compatibility\n")
  cat("  --mRNA-X INT                Override mRNA x-axis max\n")
  cat("  --cds-X INT                 Override CDS x-axis max\n")
  cat("  --exon-length-X INT         Override exon length x-axis max\n")
  cat("  --exon-number-X INT         Override exon number x-axis max\n")
  cat("  --intron-X INT              Override intron x-axis max\n")
}

args <- commandArgs(trailingOnly = TRUE)
if (any(args %in% c("-h", "--help"))) {
  usage()
  quit(status = 0)
}

get_arg <- function(name, required = FALSE, default = NA) {
  idx <- which(args == name)
  if (length(idx) == 0) {
    if (required) stop(paste("Missing", name), call. = FALSE)
    return(default)
  }
  if (idx[1] == length(args)) stop(paste("Missing value for", name), call. = FALSE)
  args[idx[1] + 1]
}

reference_file <- get_arg("--reference-distribution", required = TRUE)
out_prefix <- get_arg("--out-prefix", required = TRUE)
overrides <- list(
  mRNA_length = suppressWarnings(as.numeric(get_arg("--mRNA-X"))),
  CDS_length = suppressWarnings(as.numeric(get_arg("--cds-X"))),
  exon_length = suppressWarnings(as.numeric(get_arg("--exon-length-X"))),
  exon_number = suppressWarnings(as.numeric(get_arg("--exon-number-X"))),
  intron_length = suppressWarnings(as.numeric(get_arg("--intron-X")))
)

dist <- read.delim(reference_file, stringsAsFactors = FALSE, check.names = FALSE)
dist$bin_start <- as.numeric(dist$bin_start)
dist$percent <- as.numeric(dist$percent)
dist$bin_size <- as.numeric(dist$bin_size)
species <- unique(dist$species)
colors <- c("red2", "blue3", "green3", "black", "orange2", "pink2", "gray40", "purple4", "cyan4", "brown3")

nice_axis <- function(values, category, min_x, order_x) {
  values <- values[is.finite(values)]
  if (length(values) == 0) values <- 0
  max_y <- max(values, na.rm = TRUE)
  max_y <- floor(max_y * 1.1) + 1
  if (max_y <= 6) {
    y_by <- 1
  } else if (max_y <= 9) {
    max_y <- 9
    y_by <- 3
  } else {
    y_by <- floor(max_y / 4) + 1
    max_y <- y_by * 4
  }
  x_values <- dist$bin_start[dist$category == category & dist$percent > 0]
  if (length(x_values) == 0) x_values <- 0
  max_x <- max(x_values, na.rm = TRUE)
  override <- overrides[[category]]
  if (is.finite(override)) max_x <- override
  if (order_x == 1) {
    x_max <- max(min_x, ceiling(max_x / 4) * 4)
    x_by <- max(1, floor(x_max / 4))
  } else {
    x_max <- max(min_x, (floor(max_x * 5 / order_x) + 1) * order_x)
    x_by <- order_x
    n <- x_max / order_x
    while (n > 5) {
      if (n %% 5 == 0) {
        x_by <- n / 5 * order_x
        x_max <- x_by * 5
        break
      } else if (n %% 4 == 0) {
        x_by <- n / 4 * order_x
        x_max <- x_by * 4
        break
      } else if (n %% 3 == 0) {
        x_by <- n / 3 * order_x
        x_max <- x_by * 3
        break
      }
      n <- n + 1
    }
  }
  list(y_max = max_y, y_by = y_by, x_max = x_max, x_by = x_by)
}

plot_distribution <- function(category, title, xlab, ylab, min_x, order_x, lwd = 1.2, cex_lab = 1.4, cex_axis = 1.3, legend_cex = 1.2) {
  subset <- dist[dist$category == category, ]
  axis_values <- nice_axis(subset$percent, category, min_x, order_x)
  first_species <- species[1]
  first <- subset[subset$species == first_species, ]
  plot(first$bin_start, first$percent,
       type = "l", col = colors[1], lwd = lwd,
       xlab = xlab, ylab = ylab, xaxt = "n", yaxt = "n",
       cex.lab = cex_lab, font.lab = 2, cex.main = cex_lab, main = title,
       xlim = c(0, axis_values$x_max), ylim = c(0, axis_values$y_max))
  axis(side = 1, seq(0, axis_values$x_max, by = axis_values$x_by), cex.axis = cex_axis, font = 2, lwd = 1.5)
  axis(side = 2, seq(0, axis_values$y_max, by = axis_values$y_by), las = 1, cex.axis = cex_axis, font = 2, lwd = 1.5)
  if (length(species) > 1) {
    for (i in seq_along(species)[-1]) {
      current <- subset[subset$species == species[i], ]
      lines(current$bin_start, current$percent, col = colors[((i - 1) %% length(colors)) + 1], lwd = lwd)
    }
  }
  legend("topright", legend = species, bty = "n", col = colors[seq_along(species)], lty = rep(1, length(species)), inset = 0.03, cex = legend_cex, lwd = lwd)
}

pdf(file = paste0(out_prefix, ".gene_length_distribution.pdf"), width = 8, height = 6)
layout(matrix(1:4, 2, 2, byrow = TRUE))
par(mar = c(4, 4, 2, 1.7), lwd = 1.5)
par(mgp = c(1.7, 0.4, 0), tck = 0.03, xaxs = "i", yaxs = "i")
plot_distribution("mRNA_length", "Distribution of mRNA length", "Gene length (bp) (window=50bp)", "Percent of genes(%)", 5000, 1000)
plot_distribution("CDS_length", "Distribution of CDS length", "CDS length (bp) (window=50bp)", "Percent of genes(%)", 5000, 1000)
plot_distribution("exon_length", "Distribution of exon length", "Exon length (bp)(window=10bp)", "Percent of exons(%)", 500, 100)
plot_distribution("intron_length", "Distribution of intron length", "Intron length (bp)(window=10bp)", "Percent of introns(%)", 500, 100)
dev.off()

pdf(file = paste0(out_prefix, ".exon_number.pdf"), width = 8, height = 6)
par(mar = c(5, 5.2, 3, 1.4), lwd = 2.8)
par(mgp = c(2.5, 0.7, 0), tck = 0.03, xaxs = "i", yaxs = "i")
plot_distribution("exon_number", "Distribution of exon number", "Exon number", "Percent of genes(%)", 20, 1, lwd = 2.2, cex_lab = 2, cex_axis = 2, legend_cex = 2)
dev.off()
