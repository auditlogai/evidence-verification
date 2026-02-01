# R_05_tables_hvtA.R (v6.0)
suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
})

write_table <- function(df, out_path) {
  dir.create(dirname(out_path), showWarnings = FALSE, recursive = TRUE)
  write_csv(df, out_path)
  message("Wrote: ", out_path)
}

# Table 2 (candidate-level outcomes)
table2_candidate_outcomes <- function(df_primary_rows) {
  df_primary_rows %>%
    count(node_id, group, arm, operator, candidate_label, pass_fail, name = "n") %>%
    arrange(node_id, group, arm, operator, candidate_label)
}

# Table 3a (arm-level detection performance)
table3a_detection_performance <- function(arm_level) {
  arm_level %>%
    mutate(
      TP = ifelse(tamper_present_expected == 1 & arm_correct == 1, 1L, 0L),
      FN = ifelse(tamper_present_expected == 1 & arm_correct == 0, 1L, 0L),
      TN = ifelse(tamper_present_expected == 0 & arm_correct == 1, 1L, 0L),
      FP = ifelse(tamper_present_expected == 0 & arm_correct == 0, 1L, 0L)
    ) %>%
    summarise(TP=sum(TP), FN=sum(FN), TN=sum(TN), FP=sum(FP)) %>%
    mutate(
      sensitivity = TP/(TP+FN),
      specificity = TN/(TN+FP),
      false_positive_rate = FP/(FP+TN),
      false_negative_rate = FN/(FN+TP)
    )
}

# Table 3b (file-level descriptive totals on mismatch comparisons)
table3b_file_level_totals <- function(df_primary_rows) {
  df_primary_rows %>%
    mutate(expected_is_mismatch = (candidate_label == expected_mismatch_candidate)) %>%
    filter(expected_is_mismatch) %>%
    summarise(
      n_mismatch_comparisons = n(),
      total_tamper_k_effective = sum(tamper_k_effective, na.rm = TRUE),
      total_tamper_k_raw = sum(tamper_k, na.rm = TRUE),
      total_swap_k = sum(swap_k, na.rm = TRUE),
      median_tamper_k_effective = median(tamper_k_effective, na.rm = TRUE),
      median_n_corpus = median(n_corpus, na.rm = TRUE),
      min_n_corpus = min(n_corpus, na.rm = TRUE),
      max_n_corpus = max(n_corpus, na.rm = TRUE)
    )
}

# Table 4 (agreement + kappa where n_ops==2)
table4_operator_agreement <- function(arm_level) {
  per_arm <- arm_level %>%
    group_by(node_id, group, arm) %>%
    summarise(n_ops=n(), all_same=as.integer(n_distinct(arm_correct)==1), .groups="drop")

  per_arm_two <- per_arm %>% filter(n_ops==2)
  percent_agreement_twoops <- if (nrow(per_arm_two)>0) mean(per_arm_two$all_same) else NA_real_

  kappa_by_node <- arm_level %>%
    group_by(node_id, group, arm) %>%
    filter(n()==2) %>%
    arrange(operator) %>%
    mutate(rater_idx=row_number()) %>%
    select(node_id, group, arm, rater_idx, arm_correct) %>%
    pivot_wider(names_from=rater_idx, values_from=arm_correct) %>%
    group_by(node_id) %>%
    summarise(
      kappa = {
        op1 <- `1`; op2 <- `2`
        a <- sum(op1==1 & op2==1); b <- sum(op1==1 & op2==0)
        c <- sum(op1==0 & op2==1); d <- sum(op1==0 & op2==0)
        n <- a+b+c+d
        po <- (a+d)/n
        p1 <- ((a+b)/n)*((a+c)/n)
        p0 <- ((c+d)/n)*((b+d)/n)
        pe <- p1+p0
        if (abs(1-pe)<1e-12) 1 else (po-pe)/(1-pe)
      },
      .groups="drop"
    )

  summary <- tibble::tibble(
    percent_agreement_twoops = percent_agreement_twoops,
    note = "Agreement/kappa computed only where 2 blinded operators exist. Node03 has 1 blinded operator after architect exclusion; kappa not applicable."
  )

  list(per_arm=per_arm, summary=summary, kappa_by_node=kappa_by_node)
}

# Table 5 (timing)
table5_timing_by_operator <- function(operator_summary) operator_summary %>% arrange(node_id, operator)
table5_timing_by_family <- function(arm_level) {
  arm_level %>%
    group_by(node_id, stage, arm_family) %>%
    summarise(
      n=n(),
      mean_sec=mean(hv_duration_seconds, na.rm=TRUE),
      sd_sec=sd(hv_duration_seconds, na.rm=TRUE),
      median_sec=median(hv_duration_seconds, na.rm=TRUE),
      iqr_sec=IQR(hv_duration_seconds, na.rm=TRUE),
      .groups="drop"
    ) %>% arrange(node_id, stage, arm_family)
}

# Table 6 (tamper class analysis; Stage IIIB/IV deletions only; Stage IIIA includes swaps)
table6_tamper_class <- function(df_primary_rows) {
  df_primary_rows %>%
    mutate(expected_is_mismatch = (candidate_label == expected_mismatch_candidate)) %>%
    filter(expected_is_mismatch) %>%
    mutate(
      deletion_detected = as.integer(tamper_k > 0),
      swap_detected = as.integer(swap_k > 0),
      addition_detected = 0L,       # not observed in these stage datasets per protocol note
      substitution_detected = as.integer(swap_k > 0) # swap implies substitution-type evidence
    ) %>%
    group_by(stage = ifelse(grepl("^IIIA_", group), "Stage_IIIA", "Stage_IV")) %>%
    summarise(
      n_mismatch = n(),
      deletion_any = as.integer(any(deletion_detected==1)),
      swap_any = as.integer(any(swap_detected==1)),
      substitution_any = as.integer(any(substitution_detected==1)),
      addition_any = as.integer(any(addition_detected==1)),
      .groups="drop"
    )
}

# Table 7 (commit–reveal integrity verification) — placeholder structure (needs anchor txid inputs)
table7_commit_reveal <- function() {
  tibble::tibble(
    parameter=c("Commit digest match","Post-hoc modification","Operator blinding maintained"),
    expected=c("TRUE","NONE","TRUE"),
    observed=c(NA, NA, NA),
    evidence_pointer=c("Bitcoin commit txid (to be linked)","Hash-chain / ledger check (to be linked)","Blinding map + reveal verification (to be linked)")
  )
}

# Table 8 (corpus characteristics) — descriptive from n_corpus by family/stage
table8_corpus_characteristics <- function(df_primary_rows) {
  df_primary_rows %>%
    mutate(
      stage = ifelse(grepl("^IIIA_", group), "Stage_IIIA", "Stage_IV"),
      arm_family = case_when(
        grepl("^IIIA_", group) ~ "Stage_IIIA",
        group == "IIIB_Parity" ~ "IIIB_Parity",
        group == "Positive_Controls" ~ "Positive_Controls",
        group == "Tamper_Detection" ~ "Tamper_Detection",
        group == "Baseline_Reproducibility" ~ "Baseline_Reproducibility",
        TRUE ~ "Other"
      )
    ) %>%
    group_by(stage, arm_family) %>%
    summarise(
      n_rows = n(),
      n_corpus_median = median(n_corpus, na.rm=TRUE),
      n_corpus_min = min(n_corpus, na.rm=TRUE),
      n_corpus_max = max(n_corpus, na.rm=TRUE),
      .groups="drop"
    ) %>% arrange(stage, arm_family)
}

table_architect_context <- function(df_all_rows) {
  df_all_rows %>%
    filter(is_architect_operator==1L) %>%
    select(node_id, group, arm, operator, candidate_label, pass_fail,
           hv_duration_seconds, n_corpus, tamper_k, swap_k, tamper_k_effective) %>%
    arrange(node_id, group, arm, candidate_label)
}