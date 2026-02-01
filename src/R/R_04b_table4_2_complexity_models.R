# R_04b_table4_2_complexity_models.R (v2)
# Writes:
# 1) Table4_2_complexity_models_summary.csv  (arm-level, pre-registered models)
# 2) Fig_model_labels.csv                   (candidate-level, figure annotation payload)
#
# Rationale:
# - Arm-level models are the canonical pre-registered regressions (n=36, Stage IV n=30).
# - Figures (Fig1, Fig2A, Fig2B) are drawn from candidate-level rows and are stratified
#   by PASS-like vs FAIL-like; therefore figure annotations must be computed on the
#   same dataset/subsets used in plotting to be auditable and consistent.

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(stringr)
  library(broom)
  library(tibble)
})

assert_or_stop <- function(ok, msg) {
  if (!isTRUE(ok)) stop(msg, call. = FALSE)
}

# Helper: safe linear model wrapper
.safe_lm <- function(formula, data) {
  # Require >= 3 rows and non-zero variance in x and y
  mf <- model.frame(formula, data = data, na.action = na.omit)
  if (nrow(mf) < 3) return(NULL)
  x <- mf[[2]]
  y <- mf[[1]]
  if (sd(x, na.rm = TRUE) == 0 || sd(y, na.rm = TRUE) == 0) return(NULL)
  lm(formula, data = data)
}

# Convert regression output to r (signed sqrt of R2)
.r_from_r2 <- function(estimate, r2) {
  if (!is.finite(r2)) return(NA_real_)
  if (!is.finite(estimate)) return(NA_real_)
  sign(estimate) * sqrt(max(0, r2))
}

# Main writer
write_complexity_model_table <- function(run_dir) {
  run_dir <- normalizePath(run_dir, mustWork = TRUE)

  out_dir <- file.path(run_dir, "tables")
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

  # -----------------------------
  # PART A — Arm-level canonical models (Table4_2)
  # -----------------------------
  arm_path <- file.path(run_dir, "derived", "hvtA_arm_level.csv")
  assert_or_stop(file.exists(arm_path), paste0("QC FAIL: missing file: ", arm_path))

  df_arm <- read_csv(arm_path, show_col_types = FALSE)

  req_arm <- c("hv_duration_seconds","n_corpus","tamper_k_effective","group")
  miss_arm <- setdiff(req_arm, names(df_arm))
  assert_or_stop(length(miss_arm) == 0,
                 paste0("QC FAIL: missing columns in hvtA_arm_level.csv: ", paste(miss_arm, collapse=", ")))

  df_arm <- df_arm %>%
    mutate(
      hv_duration_seconds = as.numeric(hv_duration_seconds),
      n_corpus = as.numeric(n_corpus),
      tamper_k_effective = as.numeric(tamper_k_effective),
      stage = ifelse(str_detect(group, "^IIIA_"), "Stage_IIIA", "Stage_IV")
    )

  mA <- lm(hv_duration_seconds ~ n_corpus, data = df_arm)
  mB <- lm(hv_duration_seconds ~ tamper_k_effective, data = df_arm)

  mA_iv <- lm(hv_duration_seconds ~ n_corpus, data = df_arm %>% filter(stage == "Stage_IV"))
  mB_iv <- lm(hv_duration_seconds ~ tamper_k_effective, data = df_arm %>% filter(stage == "Stage_IV"))

  # Stage IIIA within-stage slopes are not estimable (n fixed; k fixed), keep NA rows
  pack_arm <- function(name, model, term) {
    if (is.null(model)) {
      return(tibble(
        model = name, term = term,
        estimate = NA_real_, std_error = NA_real_, p_value = NA_real_,
        r2 = 0, adj_r2 = 0, n = NA_real_
      ))
    }
    tt <- tidy(model)
    gl <- glance(model)
    row <- tt %>% filter(term == !!term)
    tibble(
      model = name,
      term = term,
      estimate = row$estimate,
      std_error = row$std.error,
      p_value = row$p.value,
      r2 = gl$r.squared,
      adj_r2 = gl$adj.r.squared,
      n = gl$nobs
    )
  }

  out_arm <- bind_rows(
    pack_arm("Primary Model A (duration ~ n)", mA, "n_corpus"),
    pack_arm("Primary Model B (duration ~ k_effective)", mB, "tamper_k_effective"),
    pack_arm("Stage IV: Model A", mA_iv, "n_corpus"),
    tibble(model="Stage IIIA: Model A", term="n_corpus", estimate=NA_real_, std_error=NA_real_, p_value=NA_real_, r2=0, adj_r2=0, n=6),
    pack_arm("Stage IV: Model B", mB_iv, "tamper_k_effective"),
    tibble(model="Stage IIIA: Model B", term="tamper_k_effective", estimate=NA_real_, std_error=NA_real_, p_value=NA_real_, r2=0, adj_r2=0, n=6)
  )

  out_path <- file.path(out_dir, "Table4_2_complexity_models_summary.csv")
  write_csv(out_arm, out_path)
  message("Wrote: ", out_path)

  # -----------------------------
  # PART B — Candidate-level figure label payload (Fig_model_labels.csv)
  # -----------------------------
  # Figures are produced from derived/hvtA_primary_rows.csv (candidate-level).
  primary_path <- file.path(run_dir, "derived", "hvtA_primary_rows.csv")
  assert_or_stop(file.exists(primary_path), paste0("QC FAIL: missing file: ", primary_path))

  dfp <- read_csv(primary_path, show_col_types = FALSE)

  # Required candidate-level fields
  req_p <- c("hv_duration_seconds","n_corpus","tamper_k_effective","group",
             "candidate_label","expected_match_candidate","expected_mismatch_candidate")
  miss_p <- setdiff(req_p, names(dfp))
  assert_or_stop(length(miss_p) == 0,
                 paste0("QC FAIL: missing columns in hvtA_primary_rows.csv: ", paste(miss_p, collapse=", ")))

  dfp <- dfp %>%
    mutate(
      hv_duration_seconds = as.numeric(hv_duration_seconds),
      n_corpus = as.numeric(n_corpus),
      tamper_k_effective = as.numeric(tamper_k_effective),
      stage = ifelse(str_detect(group, "^IIIA_"), "Stage_IIIA", "Stage_IV"),
      comparison_type = ifelse(candidate_label == expected_match_candidate, "PASS-like", "FAIL-like")
    ) %>%
    filter(is.finite(hv_duration_seconds))

  # Define the exact subsets that appear in figures:
  # Fig1: FAIL-like only, x = k_effective
  # Fig2A: pooled, PASS-like and FAIL-like, x = n
  # Fig2B: by stage, PASS-like and FAIL-like, x = n
  subsets <- list(
    list(fig="Fig1", panel="FAIL-like", stage="Pooled", comparison_type="FAIL-like", xvar="tamper_k_effective"),
    list(fig="Fig2A", panel="PASS-like", stage="Pooled", comparison_type="PASS-like", xvar="n_corpus"),
    list(fig="Fig2A", panel="FAIL-like", stage="Pooled", comparison_type="FAIL-like", xvar="n_corpus"),
    list(fig="Fig2B", panel="PASS-like", stage="Stage_IV", comparison_type="PASS-like", xvar="n_corpus"),
    list(fig="Fig2B", panel="FAIL-like", stage="Stage_IV", comparison_type="FAIL-like", xvar="n_corpus"),
    list(fig="Fig2B", panel="PASS-like", stage="Stage_IIIA", comparison_type="PASS-like", xvar="n_corpus"),
    list(fig="Fig2B", panel="FAIL-like", stage="Stage_IIIA", comparison_type="FAIL-like", xvar="n_corpus")
  )

  fit_one <- function(dat, xvar) {
    form <- as.formula(paste0("hv_duration_seconds ~ ", xvar))
    m <- .safe_lm(form, dat)
    if (is.null(m)) {
      return(tibble(
        estimate = NA_real_, std_error = NA_real_, p_value = NA_real_,
        r2 = 0, adj_r2 = 0, n = nrow(na.omit(model.frame(form, dat))),
        r = NA_real_
      ))
    }
    tt <- tidy(m)
    gl <- glance(m)
    row <- tt %>% filter(term == xvar)
    r_val <- .r_from_r2(row$estimate, gl$r.squared)
    tibble(
      estimate = row$estimate,
      std_error = row$std.error,
      p_value = row$p.value,
      r2 = gl$r.squared,
      adj_r2 = gl$adj.r.squared,
      n = gl$nobs,
      r = r_val
    )
  }

  rows <- lapply(subsets, function(s) {
    dat <- dfp
    if (s$stage != "Pooled") dat <- dat %>% filter(stage == s$stage)
    dat <- dat %>% filter(comparison_type == s$comparison_type)

    res <- fit_one(dat, s$xvar)

    tibble(
      fig = s$fig,
      panel = s$panel,
      stage = s$stage,
      subset = paste0(s$stage, " / ", s$panel),
      xvar = s$xvar,
      n = res$n,
      estimate = res$estimate,
      std_error = res$std_error,
      p_value = res$p_value,
      r = res$r,
      adj_r2 = res$adj_r2
    )
  }) %>% bind_rows()

  figlab_path <- file.path(out_dir, "Fig_model_labels.csv")
  write_csv(rows, figlab_path)
  message("Wrote: ", figlab_path)

  invisible(list(table4_2 = out_path, fig_labels = figlab_path))
}