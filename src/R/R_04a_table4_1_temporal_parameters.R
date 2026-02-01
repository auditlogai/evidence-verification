# R_04a_table4_1_temporal_parameters.R
# Sentinel QMSv5 — Stage IV
# Ontology §4.1 Temporal Parameters table generator (CSV output)
#
# Inputs:
#   - hvtA_primary_rows.csv from a frozen run directory
# Output:
#   - Table4_1_temporal_parameters.csv in <run_dir>/tables/

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(stringr)
})

assert_or_stop <- function(ok, msg) {
  if (!isTRUE(ok)) stop(msg, call. = FALSE)
}

make_temporal_table <- function(run_dir) {
  run_dir <- normalizePath(run_dir, mustWork = TRUE)
  in_path <- file.path(run_dir, "derived", "hvtA_primary_rows.csv")
  out_dir <- file.path(run_dir, "tables")
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

  df <- read_csv(in_path, show_col_types = FALSE)

  # Required columns (fail-closed)
  req <- c("node_id","group","arm","operator","candidate_label",
           "expected_match_candidate","expected_mismatch_candidate",
           "hv_start_utc","hv_end_utc","hv_duration_seconds",
           "n_corpus","tamper_k_effective")
  miss <- setdiff(req, names(df))
  assert_or_stop(length(miss) == 0, paste0("QC FAIL: missing columns in hvtA_primary_rows.csv: ", paste(miss, collapse=", ")))

  df <- df %>%
    mutate(
      hv_duration_seconds = as.numeric(hv_duration_seconds),
      n_corpus = as.numeric(n_corpus),
      tamper_k_effective = as.numeric(tamper_k_effective),
      stage = ifelse(str_detect(group, "^IIIA_"), "Stage_IIIA", "Stage_IV"),
      expected_relation = ifelse(candidate_label == expected_match_candidate, "MATCH", "MISMATCH")
    )

  # Table grain: node × group × arm × operator × candidate (branch-explicit)
  out <- df %>%
    select(
      stage,
      node_id,
      group,
      arm,
      operator,
      candidate_label,
      expected_relation,
      hv_start_utc,
      hv_end_utc,
      hv_duration_seconds,
      n_corpus,
      tamper_k_effective
    ) %>%
    arrange(stage, node_id, group, arm, operator, candidate_label)

  out_path <- file.path(out_dir, "Table4_1_temporal_parameters.csv")
  write_csv(out, out_path)
  message("Wrote: ", out_path)

  invisible(out_path)
}