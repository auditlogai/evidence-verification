# R_03_operator_rollup_hvtA.R (QMSv5 Stage IV)
suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

# arm_level expected columns:
# node_id, group, arm, operator, arm_correct (0/1), hv_duration_seconds, tamper_k, arm_family, tamper_present_expected

rollup_operator_summary <- function(arm_level) {
  arm_level %>%
    group_by(node_id, operator) %>%
    summarise(
      n_arms = n(),
      accuracy = mean(arm_correct, na.rm = TRUE),
      median_hvtA_sec = median(hv_duration_seconds, na.rm = TRUE),
      mean_hvtA_sec = mean(hv_duration_seconds, na.rm = TRUE),
      min_hvtA_sec = min(hv_duration_seconds, na.rm = TRUE),
      max_hvtA_sec = max(hv_duration_seconds, na.rm = TRUE),
      .groups = "drop"
    )
}

rollup_family_timing <- function(arm_level) {
  arm_level %>%
    group_by(node_id, arm_family) %>%
    summarise(
      n = n(),
      median_hvtA_sec = median(hv_duration_seconds, na.rm = TRUE),
      iqr_hvtA_sec = IQR(hv_duration_seconds, na.rm = TRUE),
      mean_hvtA_sec = mean(hv_duration_seconds, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    arrange(node_id, arm_family)
}

# Confusion matrix at arm-level:
# We treat "tamper_present_expected" as ground truth that the arm includes a tamper mismatch candidate.
# The operator succeeds on the arm if arm_correct==1.
# For sensitivity/specificity in your ontology, we need TP/TN/FP/FN defined over expected classes.
#
# Practical approach:
# - For arms where tamper_present_expected==1 (tamper should be detected):
#     TP = arm_correct==1
#     FN = arm_correct==0
# - For arms where tamper_present_expected==0 (baseline reproducibility confirmation):
#     TN = arm_correct==1
#     FP = arm_correct==0
rollup_confusion <- function(arm_level) {
  arm_level %>%
    mutate(
      TP = ifelse(tamper_present_expected == 1 & arm_correct == 1, 1L, 0L),
      FN = ifelse(tamper_present_expected == 1 & arm_correct == 0, 1L, 0L),
      TN = ifelse(tamper_present_expected == 0 & arm_correct == 1, 1L, 0L),
      FP = ifelse(tamper_present_expected == 0 & arm_correct == 0, 1L, 0L)
    ) %>%
    summarise(
      TP = sum(TP), FN = sum(FN), TN = sum(TN), FP = sum(FP)
    ) %>%
    mutate(
      sensitivity = TP / (TP + FN),
      specificity = TN / (TN + FP),
      false_positive_rate = FP / (FP + TN),
      false_negative_rate = FN / (FN + TP)
    )
}

write_rollup <- function(df, out_path) {
  write_csv(df, out_path)
  message("Wrote: ", out_path)
}