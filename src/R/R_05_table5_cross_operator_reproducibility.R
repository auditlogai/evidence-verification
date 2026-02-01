# R_05_table5_cross_operator_reproducibility.R
# Sentinel QMSv5 — Stage IV
# Ontology §5: Cross-Operator Reproducibility (deterministic)
#
# Input:
#   <run_dir>/derived/hvtA_arm_level.csv
# Output:
#   <run_dir>/tables/Table5_cross_operator_reproducibility.csv
#   <run_dir>/tables/Table5_cross_operator_disagreements.csv

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(stringr)
  library(tidyr)
})

assert_or_stop <- function(ok, msg) {
  if (!isTRUE(ok)) stop(msg, call. = FALSE)
}

cohen_kappa_binary <- function(op1, op2) {
  # op1/op2 are integer vectors of 0/1, same length
  a <- sum(op1 == 1 & op2 == 1)
  b <- sum(op1 == 1 & op2 == 0)
  c <- sum(op1 == 0 & op2 == 1)
  d <- sum(op1 == 0 & op2 == 0)
  n <- a + b + c + d
  if (n == 0) return(NA_real_)
  po <- (a + d) / n
  p1 <- ((a + b) / n) * ((a + c) / n)
  p0 <- ((c + d) / n) * ((b + d) / n)
  pe <- p1 + p0
  if (abs(1 - pe) < 1e-12) return(1)
  (po - pe) / (1 - pe)
}

write_table5_cross_operator <- function(run_dir) {
  run_dir <- normalizePath(run_dir, mustWork = TRUE)
  in_path <- file.path(run_dir, "derived", "hvtA_arm_level.csv")
  out_dir <- file.path(run_dir, "tables")
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

  df <- read_csv(in_path, show_col_types = FALSE)

  req <- c("node_id","group","arm","operator","arm_correct")
  miss <- setdiff(req, names(df))
  assert_or_stop(length(miss) == 0, paste0("QC FAIL: missing columns in hvtA_arm_level.csv: ", paste(miss, collapse=", ")))

  df <- df %>%
    mutate(
      arm_correct = as.integer(arm_correct),
      operator = as.character(operator),
      node_id = as.character(node_id),
      group = as.character(group),
      arm = as.character(arm)
    )

  # Per-node operator count (blinded only is already enforced upstream in your frozen run)
  op_counts <- df %>%
    group_by(node_id) %>%
    summarise(
      blinded_operator_count = n_distinct(operator),
      .groups = "drop"
    )

  # Per-arm agreement indicator (only meaningful when >=2 ops exist for that arm)
  per_arm <- df %>%
    group_by(node_id, group, arm) %>%
    summarise(
      n_ops = n(),
      all_same = as.integer(n_distinct(arm_correct) == 1),
      .groups = "drop"
    )

  # Agreement rate:
  # - If node has >=2 operators, compute mean(all_same) over arms with n_ops>=2
  # - If node has 1 operator, agreement rate defined as 1.0 (trivially) with note
  agreement <- per_arm %>%
    group_by(node_id) %>%
    summarise(
      n_arms = n(),
      n_arms_twoops = sum(n_ops >= 2),
      agreement_rate = ifelse(n_arms_twoops >= 1, mean(all_same[n_ops >= 2]), 1.0),
      .groups = "drop"
    )

  # Cohen's kappa (only when >=2 ops per arm and >=1 such arm exists)
  # We compute kappa per node using pivot_wider over operator index per arm.
  kappa <- df %>%
    group_by(node_id, group, arm) %>%
    filter(n() >= 2) %>%
    arrange(operator) %>%
    mutate(rater_idx = row_number()) %>%
    # If more than 2 operators exist (future), restrict to first two in sorted order
    filter(rater_idx <= 2) %>%
    select(node_id, group, arm, rater_idx, arm_correct) %>%
    pivot_wider(names_from = rater_idx, values_from = arm_correct) %>%
    group_by(node_id) %>%
    summarise(
      cohen_kappa = cohen_kappa_binary(`1`, `2`),
      .groups = "drop"
    )

  # Disagreement enumeration (if any)
  disagreements <- per_arm %>%
    filter(n_ops >= 2, all_same == 0) %>%
    arrange(node_id, group, arm)

  # Assemble final table
  out <- op_counts %>%
    left_join(agreement, by="node_id") %>%
    left_join(kappa, by="node_id") %>%
    mutate(
      cohen_kappa = ifelse(is.na(cohen_kappa) & blinded_operator_count < 2, NA_real_, cohen_kappa),
      disagreement_type = ifelse(nrow(disagreements) == 0, "none", "PASS/FAIL mismatch"),
      note = case_when(
        blinded_operator_count >= 2 ~ "κ computed on arms with ≥2 blinded operators; agreement expected 100%.",
        blinded_operator_count == 1 ~ "Single blinded operator after architect exclusion; κ not applicable."
      )
    ) %>%
    select(
      node_id,
      blinded_operator_count,
      agreement_rate,
      cohen_kappa,
      disagreement_type,
      n_arms,
      n_arms_twoops,
      note
    ) %>%
    arrange(node_id)

  out_path <- file.path(out_dir, "Table5_cross_operator_reproducibility.csv")
  write_csv(out, out_path)
  message("Wrote: ", out_path)

  dis_path <- file.path(out_dir, "Table5_cross_operator_disagreements.csv")
  write_csv(disagreements, dis_path)
  message("Wrote: ", dis_path)

  invisible(list(table=out, disagreements=disagreements))
}