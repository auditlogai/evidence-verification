# R_04_models_hvtA_complexity.R (v6.0)
suppressPackageStartupMessages({
  library(dplyr)
})

fit_complexity_models <- function(arm_level) {
  dat <- arm_level %>%
    filter(is.finite(hv_duration_seconds), is.finite(n_corpus), is.finite(tamper_k_effective))

  if (nrow(dat) < 6) stop("QC FAIL: insufficient rows for models.", call. = FALSE)

  # Primary (pre-registered)
  model_n_all <- lm(hv_duration_seconds ~ n_corpus, data = dat)
  model_k_all <- lm(hv_duration_seconds ~ tamper_k_effective, data = dat)

  # Secondary (allowed diagnostic): control confounding
  model_ctrl <- lm(hv_duration_seconds ~ tamper_k_effective + n_corpus + stage, data = dat)

  list(model_n_all = model_n_all, model_k_all = model_k_all, model_ctrl = model_ctrl,
       n_rows = nrow(dat))
}

print_model_summaries <- function(m) {
  cat("\n--- Primary Model A: duration ~ n_corpus ---\n")
  print(summary(m$model_n_all))
  cat("\n--- Primary Model B: duration ~ tamper_k_effective ---\n")
  print(summary(m$model_k_all))
  cat("\n--- Secondary diagnostic: duration ~ k_effective + n + stage ---\n")
  print(summary(m$model_ctrl))
}