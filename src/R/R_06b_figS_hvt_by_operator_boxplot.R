# R_06b_figS_hvt_by_operator_boxplot.R
# Supplementary figure: HVT-A duration by operator and workload

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(readr)
})

plot_hvt_by_operator <- function(run_dir) {

  arm_path <- file.path(run_dir, "derived", "hvtA_arm_level.csv")
  stopifnot(file.exists(arm_path))

  df <- read_csv(arm_path, show_col_types = FALSE) %>%
    mutate(
      workload =
        ifelse(tamper_k_effective > 0, "FAIL-like", "PASS-like")
    )

  p <- ggplot(df, aes(x = operator, y = hv_duration_seconds)) +
    geom_boxplot(outlier.shape = 16) +
    facet_wrap(~ workload, scales = "free_y") +
    labs(
      x = "Operator",
      y = "HVT-A duration (seconds)"
    ) +
    theme_bw() +
    theme(axis.text.x = element_text(angle = 30, hjust = 1))

  out_path <- file.path(run_dir, "plots", "FigS_HVT_by_operator_boxplot.pdf")
  ggsave(out_path, plot = p, width = 8, height = 5)

  message("Saved: ", out_path)
  invisible(out_path)
}