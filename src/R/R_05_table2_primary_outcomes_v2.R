# R_05_table2_primary_outcomes_v2.R (v2.2 FIXED)
# Branch-explicit Table 2 with correct expected values per branch:
# MATCH branch expects 0 tamper and 0 ESF mismatches.
# MISMATCH branch expects the key-defined tamper and ESF mismatches.

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(stringr)
})

assert_or_stop <- function(ok, msg) { if (!isTRUE(ok)) stop(msg, call. = FALSE) }

write_tbl <- function(df, path) {
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
  write_csv(df, path)
  message("Wrote: ", path)
}

stage_of <- function(group) ifelse(str_detect(group, "^IIIA_"), "Stage_IIIA", "Stage_IV")

is_inverted_arm <- function(group, arm) {
  g <- toupper(group); a <- toupper(arm)
  if (g == "IIIB_PARITY" && str_detect(a, "_TAMPER")) return(TRUE)
  if (str_detect(g, "^IIIA_TAMPER_DETECTION$")) return(TRUE)
  FALSE
}

expected_stageiv_keys <- function(arm) {
  a <- toupper(arm)
  if (str_detect(a, "MULTI")) return(list(k_hash = 20L, esf_mismatch = 17L))
  if (str_detect(a, "AUDITLOGAI")) return(list(k_hash = 17L, esf_mismatch = 13L))
  stop(paste0("Unknown Stage IV arm for expected keys: ", arm), call. = FALSE)
}

expected_stageiiia_keys <- function() {
  list(expected_missing = 25L, expected_extras = 25L, expected_swap_k = 4L, expected_esf_mismatch = 26L)
}

expected_missing_extras_stageiv <- function(inverted, k_hash) {
  if (!inverted) return(list(missing = k_hash, extras = 0L))
  list(missing = 0L, extras = k_hash)
}

observed_esf_pass <- function(esf_equiv_result) {
  ifelse(esf_equiv_result == "ESF SET EQUIVALENT", 1L,
         ifelse(esf_equiv_result == "ESF SET NOT EQUIVALENT", 0L, NA_integer_))
}

observed_esf_mismatch_used <- function(inverted, baseline_only_count, audit_only_count) {
  bo <- suppressWarnings(as.integer(baseline_only_count)); bo[is.na(bo)] <- 0L
  ao <- suppressWarnings(as.integer(audit_only_count));   ao[is.na(ao)] <- 0L
  ifelse(inverted, ao, bo)
}

expected_relation <- function(candidate_label, expected_match_candidate) {
  ifelse(candidate_label == expected_match_candidate, "MATCH", "MISMATCH")
}

# ---- Metrics helper ----
build_branch_metrics <- function(df_branch, obs_pass_col, exp_pass_col, n_col, k_col, esf_n_col, esf_k_col) {
  dfb <- df_branch %>%
    mutate(
      expected_relation2 = ifelse(!!exp_pass_col == 1L, "MATCH", "MISMATCH"),
      correct = as.integer(!!obs_pass_col == !!exp_pass_col),
      TP = as.integer(expected_relation2=="MISMATCH" & correct==1L),
      FN = as.integer(expected_relation2=="MISMATCH" & correct==0L),
      TN = as.integer(expected_relation2=="MATCH" & correct==1L),
      FP = as.integer(expected_relation2=="MATCH" & correct==0L)
    )

  dfb %>%
    summarise(
      n_checkpoints = n(),
      n_match = sum(expected_relation2=="MATCH"),
      n_mismatch = sum(expected_relation2=="MISMATCH"),
      TP = sum(TP), FN = sum(FN), TN = sum(TN), FP = sum(FP),
      sensitivity = TP / (TP + FN),
      specificity = TN / (TN + FP),
      false_positive_rate = FP / (FP + TN),
      false_negative_rate = FN / (FN + TP),
      n_corpus_sum_match = sum((!!n_col)[expected_relation2=="MATCH"], na.rm=TRUE),
      n_corpus_sum_mismatch = sum((!!n_col)[expected_relation2=="MISMATCH"], na.rm=TRUE),
      k_sum_mismatch = sum((!!k_col)[expected_relation2=="MISMATCH"], na.rm=TRUE),
      esf_n_sum_match = sum((!!esf_n_col)[expected_relation2=="MATCH"], na.rm=TRUE),
      esf_n_sum_mismatch = sum((!!esf_n_col)[expected_relation2=="MISMATCH"], na.rm=TRUE),
      esf_k_sum_mismatch = sum((!!esf_k_col)[expected_relation2=="MISMATCH"], na.rm=TRUE)
    )
}

write_table2_outputs_v2 <- function(df_primary_rows, tables_dir) {
  dir.create(tables_dir, showWarnings=FALSE, recursive=TRUE)

  req <- c("node_id","group","arm","operator","candidate_label",
           "expected_match_candidate","expected_mismatch_candidate",
           "pass_fail","n_corpus","missing_count_summary","extras_count_summary",
           "swap_k","tamper_k_effective",
           "esf_equiv_result","baseline_esf_rows","audit_esf_rows","baseline_only_count","audit_only_count")
  miss <- setdiff(req, names(df_primary_rows))
  assert_or_stop(length(miss)==0, paste0("QC FAIL: missing cols: ", paste(miss, collapse=", ")))

  df <- df_primary_rows %>%
    mutate(
      stage = stage_of(group),
      inverted = mapply(is_inverted_arm, group, arm),
      expected_relation = expected_relation(candidate_label, expected_match_candidate),

      evidence_observed_pass = as.integer(pass_fail == "PASS"),
      evidence_expected_pass = as.integer(expected_relation == "MATCH"),

      membership_observed_pass = observed_esf_pass(esf_equiv_result),
      membership_expected_pass = as.integer(expected_relation == "MATCH"),

      esf_n_corpus = as.integer(baseline_esf_rows),
      esf_mismatch_used = observed_esf_mismatch_used(inverted, baseline_only_count, audit_only_count),

      observed_missing = as.integer(missing_count_summary),
      observed_extras  = as.integer(extras_count_summary),
      observed_swap_k  = as.integer(swap_k)
    )

  chk <- df %>%
    group_by(node_id, group, arm, operator) %>%
    summarise(ncand=n_distinct(candidate_label), .groups="drop")
  assert_or_stop(all(chk$ncand==2), "QC FAIL: not all arm×node×operator have both branches")

  # ---- Stage IV ----
  df_iv <- df %>%
    filter(stage=="Stage_IV") %>%
    rowwise() %>%
    mutate(
      expected_k_hash = expected_stageiv_keys(arm)$k_hash,
      expected_esf_mismatch_key = expected_stageiv_keys(arm)$esf_mismatch,
      exp_me = list(expected_missing_extras_stageiv(inverted, expected_k_hash)),
      expected_missing_key = exp_me$missing,
      expected_extras_key  = exp_me$extras,
      expected_swap_k_key  = 0L
    ) %>%
    ungroup() %>%
    select(-exp_me) %>%
    mutate(
      # APPLY EXPECTATIONS ONLY TO MISMATCH BRANCH; MATCH BRANCH EXPECTS 0
      expected_missing = ifelse(expected_relation=="MISMATCH", expected_missing_key, 0L),
      expected_extras  = ifelse(expected_relation=="MISMATCH", expected_extras_key,  0L),
      expected_swap_k  = 0L,
      expected_esf_mismatch = ifelse(expected_relation=="MISMATCH", expected_esf_mismatch_key, 0L),
      comparison = paste0(arm, " vs ", candidate_label)
    )

  # ---- Stage IIIA ----
  k3 <- expected_stageiiia_keys()
  df_iiia <- df %>%
    filter(stage=="Stage_IIIA") %>%
    mutate(
      expected_missing = ifelse(expected_relation=="MISMATCH", k3$expected_missing, 0L),
      expected_extras  = ifelse(expected_relation=="MISMATCH", k3$expected_extras,  0L),
      expected_swap_k  = ifelse(expected_relation=="MISMATCH", k3$expected_swap_k,  0L),
      expected_esf_mismatch = ifelse(expected_relation=="MISMATCH", k3$expected_esf_mismatch, 0L),
      comparison = paste0(arm, " vs ", candidate_label)
    )

  # Branch tables
  t2_iv_evidence <- df_iv %>%
    select(stage,node_id,group,arm,comparison,candidate_label,operator,expected_relation,
           n_corpus,tamper_k_effective,
           expected_missing,expected_extras,expected_swap_k,
           observed_missing,observed_extras,observed_swap_k,
           evidence_expected_pass,evidence_observed_pass)

  t2_iv_membership <- df_iv %>%
    select(stage,node_id,group,arm,comparison,candidate_label,operator,expected_relation,
           n_corpus,tamper_k_effective,
           esf_n_corpus,expected_esf_mismatch,esf_mismatch_used,
           baseline_only_count,audit_only_count,
           membership_expected_pass,membership_observed_pass)

  t2_iiia_evidence <- df_iiia %>%
    select(stage,node_id,group,arm,comparison,candidate_label,operator,expected_relation,
           n_corpus,tamper_k_effective,
           expected_missing,expected_extras,expected_swap_k,
           observed_missing,observed_extras,observed_swap_k,
           evidence_expected_pass,evidence_observed_pass)

  t2_iiia_membership <- df_iiia %>%
    select(stage,node_id,group,arm,comparison,candidate_label,operator,expected_relation,
           n_corpus,tamper_k_effective,
           esf_n_corpus,expected_esf_mismatch,esf_mismatch_used,
           baseline_only_count,audit_only_count,
           membership_expected_pass,membership_observed_pass)

  # Metrics
  m_iv_evidence <- build_branch_metrics(t2_iv_evidence,
    obs_pass_col = sym("evidence_observed_pass"),
    exp_pass_col = sym("evidence_expected_pass"),
    n_col = sym("n_corpus"),
    k_col = sym("tamper_k_effective"),
    esf_n_col = sym("n_corpus"),
    esf_k_col = sym("tamper_k_effective")
  ) %>% mutate(layer="EVIDENCE", stage="Stage_IV")

  m_iv_membership <- build_branch_metrics(t2_iv_membership,
    obs_pass_col = sym("membership_observed_pass"),
    exp_pass_col = sym("membership_expected_pass"),
    n_col = sym("n_corpus"),
    k_col = sym("tamper_k_effective"),
    esf_n_col = sym("esf_n_corpus"),
    esf_k_col = sym("esf_mismatch_used")
  ) %>% mutate(layer="MEMBERSHIP", stage="Stage_IV")

  m_iiia_evidence <- build_branch_metrics(t2_iiia_evidence,
    obs_pass_col = sym("evidence_observed_pass"),
    exp_pass_col = sym("evidence_expected_pass"),
    n_col = sym("n_corpus"),
    k_col = sym("tamper_k_effective"),
    esf_n_col = sym("n_corpus"),
    esf_k_col = sym("tamper_k_effective")
  ) %>% mutate(layer="EVIDENCE", stage="Stage_IIIA")

  m_iiia_membership <- build_branch_metrics(t2_iiia_membership,
    obs_pass_col = sym("membership_observed_pass"),
    exp_pass_col = sym("membership_expected_pass"),
    n_col = sym("n_corpus"),
    k_col = sym("tamper_k_effective"),
    esf_n_col = sym("esf_n_corpus"),
    esf_k_col = sym("esf_mismatch_used")
  ) %>% mutate(layer="MEMBERSHIP", stage="Stage_IIIA")

  metrics_all <- bind_rows(m_iv_evidence, m_iv_membership, m_iiia_evidence, m_iiia_membership)

  assert_or_stop(all(metrics_all$FP==0), "QC FAIL: FP detected in Table2 metrics")
  assert_or_stop(all(metrics_all$FN==0), "QC FAIL: FN detected in Table2 metrics")

  write_tbl(t2_iv_evidence, file.path(tables_dir, "Table2A_STAGEIV_EVIDENCE_branch.csv"))
  write_tbl(t2_iv_membership, file.path(tables_dir, "Table2B_STAGEIV_MEMBERSHIP_branch.csv"))
  write_tbl(t2_iiia_evidence, file.path(tables_dir, "Table2A_STAGEIIIA_EVIDENCE_branch.csv"))
  write_tbl(t2_iiia_membership, file.path(tables_dir, "Table2B_STAGEIIIA_MEMBERSHIP_branch.csv"))
  write_tbl(metrics_all, file.path(tables_dir, "Table2_metrics_EVIDENCE_and_MEMBERSHIP.csv"))

  invisible(list(metrics=metrics_all))
}