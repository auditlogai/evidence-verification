# R_05c_table_item_level_enumeration_performance.R
# Sentinel QMSv5 Stage IV — Item-level enumeration performance (Evidence + Membership)
#
# Purpose:
#   Derive per-item TP/TN/FP/FN at:
#     (1) Evidence layer (file-level tamper enumeration)
#     (2) Membership layer (ESF-level tamper enumeration)
#   using already-generated branch tables (Table2A/Table2B).
#
# Inputs (from <run_dir>/tables):
#   - Table2A_STAGEIV_EVIDENCE_branch.csv
#   - Table2A_STAGEIIIA_EVIDENCE_branch.csv
#   - Table2B_STAGEIV_MEMBERSHIP_branch.csv
#   - Table2B_STAGEIIIA_MEMBERSHIP_branch.csv
#
# Outputs (to <run_dir>/tables):
#   - TableS_item_level_enumeration_performance.csv
#   - TableS_item_level_enumeration_branch_details.csv

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(stringr)
})

assert_or_stop <- function(ok, msg) {
  if (!isTRUE(ok)) stop(msg, call. = FALSE)
}

read_req <- function(path, req_cols) {
  df <- read_csv(path, show_col_types = FALSE)
  miss <- setdiff(req_cols, names(df))
  assert_or_stop(length(miss) == 0,
                 paste0("QC FAIL: missing columns in ", basename(path), ": ", paste(miss, collapse=", ")))
  df
}

# Compute item-level confusion components from expected/observed tamper counts and total universe size
# TP = min(expected_tamper, observed_tamper)
# FN = max(0, expected - observed)
# FP = max(0, observed - expected)
# TN = total_items - TP - FN - FP
conf_from_counts <- function(total_items, expected_tamper, observed_tamper) {
  total_items <- as.numeric(total_items)
  expected_tamper <- as.numeric(expected_tamper)
  observed_tamper <- as.numeric(observed_tamper)

  tp <- pmin(expected_tamper, observed_tamper)
  fn <- pmax(0, expected_tamper - observed_tamper)
  fp <- pmax(0, observed_tamper - expected_tamper)
  tn <- total_items - tp - fn - fp

  # Fail-closed sanity
  assert_or_stop(all(is.finite(tp) & tp >= 0), "QC FAIL: TP invalid")
  assert_or_stop(all(is.finite(fn) & fn >= 0), "QC FAIL: FN invalid")
  assert_or_stop(all(is.finite(fp) & fp >= 0), "QC FAIL: FP invalid")
  assert_or_stop(all(is.finite(tn) & tn >= 0), "QC FAIL: TN invalid (check total_items definition)")

  list(tp=tp, fn=fn, fp=fp, tn=tn)
}

write_item_level_enumeration_tables <- function(run_dir) {
  run_dir <- normalizePath(run_dir, mustWork = TRUE)
  tables_dir <- file.path(run_dir, "tables")
  assert_or_stop(dir.exists(tables_dir), paste0("QC FAIL: tables/ not found in run_dir: ", run_dir))

  # ---- Evidence layer inputs ----
  ev_req <- c("stage","expected_relation","n_corpus",
              "expected_missing","expected_extras","expected_swap_k",
              "observed_missing","observed_extras","observed_swap_k")
  ev_iv_path   <- file.path(tables_dir, "Table2A_STAGEIV_EVIDENCE_branch.csv")
  ev_iiia_path <- file.path(tables_dir, "Table2A_STAGEIIIA_EVIDENCE_branch.csv")

  ev_iv   <- read_req(ev_iv_path, ev_req)
  ev_iiia <- read_req(ev_iiia_path, ev_req)

  ev_all <- bind_rows(ev_iv, ev_iiia) %>%
    mutate(
      layer = "EVIDENCE_FILE",
      n_corpus = as.numeric(n_corpus),
      expected_tamper = as.numeric(expected_missing) + as.numeric(expected_extras) + as.numeric(expected_swap_k),
      observed_tamper = as.numeric(observed_missing) + as.numeric(observed_extras) + as.numeric(observed_swap_k),

      # total file universe size for that comparison:
      # use reference size (n_corpus) plus additions (observed_extras) as union approximation
      total_items = as.numeric(n_corpus) + as.numeric(observed_extras)
    )

  ev_conf <- conf_from_counts(ev_all$total_items, ev_all$expected_tamper, ev_all$observed_tamper)
  ev_all <- ev_all %>%
    mutate(TP_item = ev_conf$tp, FN_item = ev_conf$fn, FP_item = ev_conf$fp, TN_item = ev_conf$tn)

  # ---- Membership layer inputs ----
  mem_req <- c("stage","expected_relation","esf_n_corpus",
               "expected_esf_mismatch","esf_mismatch_used",
               "baseline_only_count","audit_only_count")
  mem_iv_path   <- file.path(tables_dir, "Table2B_STAGEIV_MEMBERSHIP_branch.csv")
  mem_iiia_path <- file.path(tables_dir, "Table2B_STAGEIIIA_MEMBERSHIP_branch.csv")

  mem_iv   <- read_req(mem_iv_path, mem_req)
  mem_iiia <- read_req(mem_iiia_path, mem_req)

  mem_all <- bind_rows(mem_iv, mem_iiia) %>%
    mutate(
      layer = "MEMBERSHIP_ESF",
      esf_n_corpus = as.numeric(esf_n_corpus),
      expected_tamper = as.numeric(expected_esf_mismatch),
      observed_tamper = as.numeric(esf_mismatch_used),

      # ESF universe size:
      # union size = |A| + |B\A| = baseline_esf_rows + audit_only_count
      total_items = as.numeric(esf_n_corpus) + as.numeric(audit_only_count)
    )

  mem_conf <- conf_from_counts(mem_all$total_items, mem_all$expected_tamper, mem_all$observed_tamper)
  mem_all <- mem_all %>%
    mutate(TP_item = mem_conf$tp, FN_item = mem_conf$fn, FP_item = mem_conf$fp, TN_item = mem_conf$tn)

  # ---- Detail table (for auditability) ----
  detail <- bind_rows(
    ev_all %>%
      transmute(stage, layer,
                expected_relation,
                total_items,
                expected_tamper, observed_tamper,
                TP_item, FN_item, FP_item, TN_item),
    mem_all %>%
      transmute(stage, layer,
                expected_relation,
                total_items,
                expected_tamper, observed_tamper,
                TP_item, FN_item, FP_item, TN_item)
  ) %>%
    arrange(layer, stage, expected_relation)

  out_detail <- file.path(tables_dir, "TableS_item_level_enumeration_branch_details.csv")
  write_csv(detail, out_detail)
  message("Wrote: ", out_detail)

  # ---- Summary table (stage × layer) ----
  summary <- detail %>%
    group_by(stage, layer) %>%
    summarise(
      total_items = sum(total_items, na.rm = TRUE),

      TP = sum(TP_item, na.rm = TRUE),
      FN = sum(FN_item, na.rm = TRUE),
      TN = sum(TN_item, na.rm = TRUE),
      FP = sum(FP_item, na.rm = TRUE),

      sensitivity = TP / (TP + FN),
      specificity = TN / (TN + FP),
      false_positive_rate = FP / (FP + TN),
      false_negative_rate = FN / (FN + TP),
      .groups = "drop"
    ) %>%
    arrange(layer, stage)

  # pooled rows
  pooled <- summary %>%
    group_by(layer) %>%
    summarise(
      stage = "Pooled",
      total_items = sum(total_items, na.rm = TRUE),
      TP = sum(TP, na.rm = TRUE),
      FN = sum(FN, na.rm = TRUE),
      TN = sum(TN, na.rm = TRUE),
      FP = sum(FP, na.rm = TRUE),
      sensitivity = TP / (TP + FN),
      specificity = TN / (TN + FP),
      false_positive_rate = FP / (FP + TN),
      false_negative_rate = FN / (FN + TP),
      .groups = "drop"
    ) %>%
    select(stage, layer, everything())

  summary_out <- bind_rows(summary, pooled)

  # Fail-closed: must preserve zero FP/FN expectation
  # (If any non-zero appears, this is a real signal to investigate.)
  assert_or_stop(all(summary_out$FP == 0), "QC FAIL: item-level FP detected (should be 0)")
  assert_or_stop(all(summary_out$FN == 0), "QC FAIL: item-level FN detected (should be 0)")

  out_sum <- file.path(tables_dir, "TableS_item_level_enumeration_performance.csv")
  write_csv(summary_out, out_sum)
  message("Wrote: ", out_sum)

  invisible(list(summary=summary_out, detail=detail))
}