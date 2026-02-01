# R_06a_fig1_stats_table.R (updated)
# Fig 1 statistics tables:
#  (1) Descriptives by family × PASS/FAIL
#  (2) FAIL-like: Stage IIIA vs Stage IV (Welch t-test + Wilcoxon)
#  (3) PASS-like across families (Kruskal–Wallis)
#  (4) Stage IV FAIL-like across families (Kruskal–Wallis)
#
# Input:
#   <run_dir>/derived/hvtA_primary_rows.csv
# Output:
#   <run_dir>/tables/Fig1_stats_by_family.csv
#   <run_dir>/tables/Fig1_failonly_stage_comparison.csv
#   <run_dir>/tables/Fig1_kw_passlike_by_family.csv
#   <run_dir>/tables/Fig1_kw_stageIV_faillike_by_family.csv

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(stringr)
})

assert_or_stop <- function(ok, msg) {
  if (!isTRUE(ok)) stop(msg, call. = FALSE)
}

iqr_val <- function(x) IQR(x, na.rm = TRUE)

make_fig1_stats <- function(run_dir) {
  run_dir <- normalizePath(run_dir, mustWork = TRUE)
  in_path <- file.path(run_dir, "derived", "hvtA_primary_rows.csv")
  out_dir <- file.path(run_dir, "tables")
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

  df <- read_csv(in_path, show_col_types = FALSE)

  req <- c("node_id","group","arm","operator","candidate_label",
           "expected_match_candidate","expected_mismatch_candidate",
           "hv_duration_seconds","n_corpus","tamper_k_effective")
  miss <- setdiff(req, names(df))
  assert_or_stop(length(miss) == 0,
                 paste0("QC FAIL: missing columns in hvtA_primary_rows.csv: ", paste(miss, collapse=", ")))

  df <- df %>%
    mutate(
      hv_duration_seconds = as.numeric(hv_duration_seconds),
      n_corpus = as.numeric(n_corpus),
      tamper_k_effective = as.numeric(tamper_k_effective),

      stage = ifelse(str_detect(group, "^IIIA_"), "Stage_IIIA", "Stage_IV"),
      comparison_type = ifelse(candidate_label == expected_match_candidate,
                               "PASS-like (expected match)",
                               "FAIL-like (expected mismatch)"),
      arm_family = case_when(
        str_detect(group, "^IIIA_") ~ "Stage_IIIA",
        group == "IIIB_Parity" ~ "IIIB_Parity",
        group == "Positive_Controls" ~ "Positive_Controls",
        group == "Tamper_Detection" ~ "Tamper_Detection",
        group == "Baseline_Reproducibility" ~ "Baseline_Reproducibility",
        TRUE ~ "Other"
      )
    )

  # -----------------------------
  # (1) Descriptives by family × PASS/FAIL
  # -----------------------------
  desc <- df %>%
    group_by(comparison_type, arm_family) %>%
    summarise(
      n = n(),
      mean_sec = mean(hv_duration_seconds, na.rm = TRUE),
      sd_sec = sd(hv_duration_seconds, na.rm = TRUE),
      median_sec = median(hv_duration_seconds, na.rm = TRUE),
      iqr_sec = iqr_val(hv_duration_seconds),
      min_sec = min(hv_duration_seconds, na.rm = TRUE),
      max_sec = max(hv_duration_seconds, na.rm = TRUE),
      median_n_corpus = median(n_corpus, na.rm = TRUE),
      median_k_effective = median(tamper_k_effective, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    arrange(comparison_type, arm_family)

  out1 <- file.path(out_dir, "Fig1_stats_by_family.csv")
  write_csv(desc, out1)
  message("Wrote: ", out1)

  # -----------------------------
  # (2) FAIL-like only: Stage IIIA vs Stage IV (primary contrast for Fig1)
  # -----------------------------
  fail_df <- df %>%
    filter(comparison_type == "FAIL-like (expected mismatch)") %>%
    filter(stage %in% c("Stage_IIIA","Stage_IV")) %>%
    filter(is.finite(hv_duration_seconds))

  assert_or_stop(nrow(fail_df) > 0, "QC FAIL: no FAIL-like rows found for inferential test")

  x <- fail_df %>% filter(stage=="Stage_IIIA") %>% pull(hv_duration_seconds)
  y <- fail_df %>% filter(stage=="Stage_IV") %>% pull(hv_duration_seconds)

  assert_or_stop(length(x) >= 2, "QC FAIL: Stage IIIA FAIL-like sample too small")
  assert_or_stop(length(y) >= 2, "QC FAIL: Stage IV FAIL-like sample too small")

  t_res <- t.test(x, y, var.equal = FALSE)        # Welch
  w_res <- wilcox.test(x, y, exact = FALSE)       # Robust check
  diff_means <- mean(x, na.rm=TRUE) - mean(y, na.rm=TRUE)

  out2 <- tibble::tibble(
    comparison = "FAIL-like duration: Stage IIIA vs Stage IV",
    n_stage_IIIA = length(x),
    n_stage_IV = length(y),
    mean_stage_IIIA = mean(x, na.rm = TRUE),
    sd_stage_IIIA = sd(x, na.rm = TRUE),
    mean_stage_IV = mean(y, na.rm = TRUE),
    sd_stage_IV = sd(y, na.rm = TRUE),
    diff_means_sec = diff_means,
    welch_t_p = unname(t_res$p.value),
    welch_t_stat = unname(t_res$statistic),
    welch_df = unname(t_res$parameter),
    wilcox_p = unname(w_res$p.value),
    wilcox_W = unname(w_res$statistic),
    note = "Primary contrast for Fig1 FAIL-like: Welch t-test (means) + Wilcoxon robustness check."
  )

  out2_path <- file.path(out_dir, "Fig1_failonly_stage_comparison.csv")
  write_csv(out2, out2_path)
  message("Wrote: ", out2_path)

  # -----------------------------
  # (3) PASS-like across families (exploratory confirmation of no major differences)
  # Kruskal–Wallis (robust, no normality assumption)
  # -----------------------------
  pass_df <- df %>%
    filter(comparison_type == "PASS-like (expected match)") %>%
    filter(arm_family != "Other") %>%
    filter(is.finite(hv_duration_seconds))

  assert_or_stop(nrow(pass_df) > 0, "QC FAIL: no PASS-like rows found for Kruskal–Wallis")

  kw_pass <- kruskal.test(hv_duration_seconds ~ arm_family, data = pass_df)

  out3 <- tibble::tibble(
    test = "Kruskal–Wallis: PASS-like duration across families",
    n_total = nrow(pass_df),
    n_families = n_distinct(pass_df$arm_family),
    statistic = unname(kw_pass$statistic),
    df = unname(kw_pass$parameter),
    p_value = unname(kw_pass$p.value),
    note = "Exploratory: PASS-like across families. Non-significance supports stability/constancy."
  )

  out3_path <- file.path(out_dir, "Fig1_kw_passlike_by_family.csv")
  write_csv(out3, out3_path)
  message("Wrote: ", out3_path)

  # -----------------------------
  # (4) Stage IV FAIL-like across families (exploratory)
  # Kruskal–Wallis within Stage IV only, FAIL-like only, family effects
  # -----------------------------
  fail_iv_df <- df %>%
    filter(comparison_type == "FAIL-like (expected mismatch)") %>%
    filter(stage == "Stage_IV") %>%
    filter(arm_family != "Other", arm_family != "Stage_IIIA") %>%
    filter(is.finite(hv_duration_seconds))

  assert_or_stop(nrow(fail_iv_df) > 0, "QC FAIL: no Stage IV FAIL-like rows found for Kruskal–Wallis")

  kw_fail_iv <- kruskal.test(hv_duration_seconds ~ arm_family, data = fail_iv_df)

  out4 <- tibble::tibble(
    test = "Kruskal–Wallis: Stage IV FAIL-like duration across families",
    n_total = nrow(fail_iv_df),
    n_families = n_distinct(fail_iv_df$arm_family),
    statistic = unname(kw_fail_iv$statistic),
    df = unname(kw_fail_iv$parameter),
    p_value = unname(kw_fail_iv$p.value),
    note = "Exploratory: Stage IV FAIL-like across families. Non-significance supports invariance across contexts at similar k."
  )

  out4_path <- file.path(out_dir, "Fig1_kw_stageIV_faillike_by_family.csv")
  write_csv(out4, out4_path)
  message("Wrote: ", out4_path)

  invisible(list(desc=desc, fail_stage=out2, kw_pass=out3, kw_fail_iv=out4))
}