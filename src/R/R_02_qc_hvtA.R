# R_02_qc_hvtA.R (QMSv5 Stage IV)
suppressPackageStartupMessages({
  library(dplyr)
})

assert_or_stop <- function(ok, msg) {
  if (!isTRUE(ok)) stop(msg, call. = FALSE)
}

qc_hvtA_with_blinding <- function(df) {
  # df = raw row-level WITH_BLINDING dataframe (96 rows)
  qc <- df %>%
    summarise(
      n_rows = n(),
      n_unique_hv = n_distinct(hv_record_id),
      nodes_ok = all(c("Node02_HVT_A_COMPLETED","Node03_HVT_A_COMPLETED") %in% unique(node_id)),
      candidate_labels_ok = all(candidate_label %in% c("QMSv5_01","QMSv5_02")),
      passfail_ok = all(pass_fail %in% c("PASS","FAIL")),
      blinding_fields_ok = all(expected_match_candidate %in% c("QMSv5_01","QMSv5_02")) &&
                           all(expected_mismatch_candidate %in% c("QMSv5_01","QMSv5_02")) &&
                           all(expected_match_candidate != expected_mismatch_candidate) &&
                           all(classification_correct %in% c(0L,1L)),
      node03_pc_override_ok = all(
        df %>%
          filter(node_id == "Node03_HVT_A_COMPLETED", group == "Positive_Controls") %>%
          pull(blinding_map_manual_override_flag) %in% 1L
      )
    )

  print(qc)

  assert_or_stop(qc$n_rows == 96, paste0("QC FAIL: expected 96 rows, got ", qc$n_rows))
  assert_or_stop(qc$n_unique_hv == 96, paste0("QC FAIL: expected 96 unique hv_record_id, got ", qc$n_unique_hv))
  assert_or_stop(qc$nodes_ok, "QC FAIL: missing expected nodes")
  assert_or_stop(qc$candidate_labels_ok, "QC FAIL: candidate_label not restricted to QMSv5_01/QMSv5_02")
  assert_or_stop(qc$passfail_ok, "QC FAIL: pass_fail must be PASS/FAIL")
  assert_or_stop(qc$blinding_fields_ok, "QC FAIL: blinding fields missing/invalid")
  assert_or_stop(qc$node03_pc_override_ok, "QC FAIL: Node03 Positive Controls must have manual override flag == 1")

  invisible(qc)
}

qc_hvtA_arm_level <- function(arm_level) {
  # arm_level = derived dataset: one row per (node, group, arm, operator)
  qc <- arm_level %>%
    summarise(
      n_rows = n(),
      any_missing_operator = any(is.na(operator) | operator == ""),
      any_missing_duration = any(is.na(hv_duration_seconds)),
      any_missing_arm_correct = any(is.na(arm_correct)),
      arm_correct_values_ok = all(arm_correct %in% c(0L,1L))
    )

  print(qc)

  assert_or_stop(!qc$any_missing_operator, "QC FAIL: missing operator in arm_level")
  assert_or_stop(!qc$any_missing_duration, "QC FAIL: missing hv_duration_seconds in arm_level")
  assert_or_stop(!qc$any_missing_arm_correct, "QC FAIL: missing arm_correct in arm_level")
  assert_or_stop(qc$arm_correct_values_ok, "QC FAIL: arm_correct must be 0/1")

  invisible(qc)
}