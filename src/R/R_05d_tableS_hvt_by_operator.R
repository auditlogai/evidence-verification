# R_05d_tableS_hvt_by_operator.R (v2)
# Supplementary: Human Verification Time (HVT) by Operator
#
# Deterministic derivation from derived/hvtA_primary_rows.csv (candidate-level)
# Correctly constructs PASS-like vs FAIL-like workload strata using blinding key mapping:
#   - PASS-like: candidate_label == expected_match_candidate
#   - FAIL-like: candidate_label == expected_mismatch_candidate
#
# IMPORTANT:
#   HVT duration is recorded at the arm-level. The primary_rows dataset contains two rows per arm (QMSv5_01/QMSv5_02),
#   so for "All arms" summaries we deduplicate to one row per (node_id, group, arm, operator).
#
# Outputs:
#   - TableS_HVT_by_operator_all.csv
#   - TableS_HVT_by_operator_passlike.csv
#   - TableS_HVT_by_operator_faillike.csv
#   - TableS_HVT_by_operator_tests.csv

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(stringr)
  library(tibble)
})

write_tbl <- function(df, path) {
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
  write_csv(df, path)
  message("Wrote: ", path)
}

assert_or_stop <- function(ok, msg) {
  if (!isTRUE(ok)) stop(msg, call. = FALSE)
}

summarize_tbl <- function(dat) {
  # dat expected to have one row per arm×operator for a given workload
  dat %>%
    group_by(operator) %>%
    summarise(
      n_arms = n(),
      mean_sec   = ifelse(all(!is.finite(hv_duration_seconds)), NA_real_, mean(hv_duration_seconds, na.rm = TRUE)),
      sd_sec     = ifelse(sum(is.finite(hv_duration_seconds)) < 2, NA_real_, sd(hv_duration_seconds, na.rm = TRUE)),
      median_sec = ifelse(all(!is.finite(hv_duration_seconds)), NA_real_, median(hv_duration_seconds, na.rm = TRUE)),
      iqr_sec    = ifelse(all(!is.finite(hv_duration_seconds)), NA_real_, IQR(hv_duration_seconds, na.rm = TRUE)),
      min_sec    = ifelse(all(!is.finite(hv_duration_seconds)), NA_real_, min(hv_duration_seconds, na.rm = TRUE)),
      max_sec    = ifelse(all(!is.finite(hv_duration_seconds)), NA_real_, max(hv_duration_seconds, na.rm = TRUE)),
      .groups = "drop"
    ) %>%
    arrange(operator)
}

derive_operator_tables <- function(run_dir) {

  run_dir <- normalizePath(run_dir, mustWork = TRUE)

  primary_path <- file.path(run_dir, "derived", "hvtA_primary_rows.csv")
  assert_or_stop(file.exists(primary_path),
                 paste0("QC FAIL: missing derived file: ", primary_path))

  dfp <- read_csv(primary_path, show_col_types = FALSE)

  # Required columns (schema-robust)
  req <- c("node_id","group","arm","operator",
           "candidate_label","expected_match_candidate","expected_mismatch_candidate",
           "hv_duration_seconds")
  miss <- setdiff(req, names(dfp))
  assert_or_stop(length(miss) == 0,
                 paste0("QC FAIL: missing required columns in hvtA_primary_rows.csv: ", paste(miss, collapse=", ")))

  # Normalise operator names lightly (optional; keep deterministic)
  dfp <- dfp %>%
    mutate(
      operator = str_squish(operator),
      candidate_label = as.character(candidate_label),
      expected_match_candidate = as.character(expected_match_candidate),
      expected_mismatch_candidate = as.character(expected_mismatch_candidate)
    )

  # Workload strata derived deterministically from blinding mapping
  dfp <- dfp %>%
    mutate(
      workload = case_when(
        candidate_label == expected_match_candidate ~ "PASS-like",
        candidate_label == expected_mismatch_candidate ~ "FAIL-like",
        TRUE ~ NA_character_
      )
    )

  assert_or_stop(!any(is.na(dfp$workload)),
                 "QC FAIL: workload could not be derived for some rows (candidate_label not equal to expected match/mismatch).")

  # Arm key for dedupe
  dfp <- dfp %>%
    mutate(arm_key = paste(node_id, group, arm, operator, sep = " | "))

  # For each arm_key, we should have exactly 2 candidate rows (QMSv5_01, QMSv5_02)
  chk <- dfp %>% count(arm_key, name = "n_rows") %>% pull(n_rows)
  assert_or_stop(all(chk == 2),
                 "QC FAIL: expected exactly 2 candidate rows per arm_key in hvtA_primary_rows.csv")

  # PASS-like arm dataset: one row per arm_key using the PASS-like row
  df_pass <- dfp %>%
    filter(workload == "PASS-like") %>%
    select(arm_key, operator, hv_duration_seconds)

  # FAIL-like arm dataset: one row per arm_key using the FAIL-like row
  df_fail <- dfp %>%
    filter(workload == "FAIL-like") %>%
    select(arm_key, operator, hv_duration_seconds)

  # "All arms" should NOT double-count; use one row per arm_key.
  # Deterministic approach: use FAIL-like row as representative (identical hv_duration_seconds for the arm)
  df_all <- df_fail

  # Summaries
  tbl_all  <- summarize_tbl(df_all)
  tbl_pass <- summarize_tbl(df_pass)
  tbl_fail <- summarize_tbl(df_fail)

  write_tbl(tbl_all,  file.path(run_dir, "tables", "TableS_HVT_by_operator_all.csv"))
  write_tbl(tbl_pass, file.path(run_dir, "tables", "TableS_HVT_by_operator_passlike.csv"))
  write_tbl(tbl_fail, file.path(run_dir, "tables", "TableS_HVT_by_operator_faillike.csv"))

  # Exploratory tests (non-parametric; small n)
  # Only run if >1 operator present in that subset
  test_rows <- list()

  if (n_distinct(df_all$operator) > 1) {
    k <- kruskal.test(hv_duration_seconds ~ operator, data = df_all)
    test_rows[[length(test_rows) + 1]] <- tibble(
      comparison = "All arms (one row per arm×operator)",
      test = "Kruskal–Wallis",
      statistic = unname(k$statistic),
      df = unname(k$parameter),
      p_value = k$p.value,
      note = "Exploratory; unadjusted; arm-level HVT episode."
    )
  }

  if (n_distinct(df_pass$operator) > 1) {
    k <- kruskal.test(hv_duration_seconds ~ operator, data = df_pass)
    test_rows[[length(test_rows) + 1]] <- tibble(
      comparison = "PASS-like only (expected MATCH)",
      test = "Kruskal–Wallis",
      statistic = unname(k$statistic),
      df = unname(k$parameter),
      p_value = k$p.value,
      note = "Exploratory; unadjusted; PASS-like strata."
    )
  }

  if (n_distinct(df_fail$operator) > 1) {
    k <- kruskal.test(hv_duration_seconds ~ operator, data = df_fail)
    test_rows[[length(test_rows) + 1]] <- tibble(
      comparison = "FAIL-like only (expected MISMATCH)",
      test = "Kruskal–Wallis",
      statistic = unname(k$statistic),
      df = unname(k$parameter),
      p_value = k$p.value,
      note = "Exploratory; unadjusted; FAIL-like strata."
    )
  }

  test_tbl <- if (length(test_rows) == 0) tibble(
    comparison = character(0), test = character(0),
    statistic = numeric(0), df = numeric(0), p_value = numeric(0), note = character(0)
  ) else bind_rows(test_rows)

  write_tbl(test_tbl, file.path(run_dir, "tables", "TableS_HVT_by_operator_tests.csv"))

  invisible(list(all = tbl_all, pass = tbl_pass, fail = tbl_fail, tests = test_tbl))
}