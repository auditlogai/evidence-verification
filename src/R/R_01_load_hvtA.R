# R_01_load_hvtA.R (v6.0)
suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(stringr)
  library(tidyr)
  library(jsonlite)
  library(digest)
})

utc_tag <- function() format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")

assert_or_stop <- function(ok, msg) {
  if (!isTRUE(ok)) stop(msg, call. = FALSE)
}

derive_candidate_label <- function(compare_folder, candidate_label) {
  out <- candidate_label
  out[is.na(out) | out == ""] <- ifelse(
    grepl("_01$", compare_folder), "QMSv5_01",
    ifelse(grepl("_02$", compare_folder), "QMSv5_02", NA_character_)
  )
  out
}

normalize_operator <- function(x) {
  y <- trimws(as.character(x))
  y <- gsub("\\s+", " ", y)
  y <- gsub("^dr\\.\\s*", "Dr. ", y, ignore.case = TRUE)
  y <- gsub("(?i)jiexiang", "Jiexiang", y, perl = TRUE)
  y
}

count_swap_lines <- function(hv_metadata_path) {
  d <- dirname(hv_metadata_path)
  p1 <- file.path(d, "SWAP_CANDIDATES.ndjson")
  if (file.exists(p1)) {
    x <- readLines(p1, warn = FALSE)
    return(sum(nzchar(trimws(x))))
  }
  cand <- list.files(d, pattern = "^SWAP_CANDIDATES.*\\.ndjson$", full.names = TRUE)
  if (length(cand) == 0) return(0L)
  cand <- sort(cand)
  x <- readLines(cand[1], warn = FALSE)
  sum(nzchar(trimws(x)))
}

load_hvtA_with_blinding <- function(path_csv) {
  df <- read_csv(path_csv, show_col_types = FALSE)

  operator_raw <- if ("hv_validator_name_norm" %in% names(df)) {
    as.character(df$hv_validator_name_norm)
  } else {
    as.character(df$hv_validator_name_raw)
  }

  df <- df %>%
    mutate(
      hv_duration_seconds = as.numeric(hv_duration_seconds),
      tamper_k = as.numeric(tamper_k),

      # n: HV_FT to lock in Methods as source_total_rows_read (HASHES_GLOBAL rows read)
      source_total_rows_read = as.numeric(source_total_rows_read),
      windows_total_rows_read = as.numeric(windows_total_rows_read),
      n_corpus = case_when(
        is.finite(source_total_rows_read) ~ source_total_rows_read,
        is.finite(windows_total_rows_read) ~ windows_total_rows_read,
        TRUE ~ NA_real_
      ),

      node_id = as.character(node_id),
      group = as.character(group),
      arm = as.character(arm),
      compare_folder = as.character(compare_folder),
      candidate_label = derive_candidate_label(compare_folder, as.character(candidate_label)),
      pass_fail = as.character(pass_fail),

      expected_match_candidate = as.character(expected_match_candidate),
      expected_mismatch_candidate = as.character(expected_mismatch_candidate),
      classification_correct = as.integer(classification_correct),

      blinding_map_source_sha256 = as.character(blinding_map_source_sha256),
      blinding_map_job_id = as.character(blinding_map_job_id),
      blinding_map_manual_override_flag = as.integer(blinding_map_manual_override_flag),

      operator_raw = operator_raw,
      operator = normalize_operator(operator_raw),
      is_architect_operator = if ("is_architect_operator" %in% names(df)) as.integer(is_architect_operator) else as.integer(str_detect(operator, ARCHITECT_NAME_REGEX))
    ) %>%
    mutate(
      is_blinded_primary_operator = ifelse(is_architect_operator == 1L, 0L, 1L),
      swap_lines = vapply(hv_metadata_path, count_swap_lines, integer(1)),
      swap_k = 2 * as.numeric(swap_lines),
      tamper_k_effective = tamper_k + swap_k
    )

  # ---- Fail-closed QC ----
  if (QC_REQUIRE_COMPLETE_DATASET) {
    assert_or_stop(nrow(df) == 96, paste0("QC_FAIL: expected 96 rows, got ", nrow(df)))
    assert_or_stop(length(unique(df$hv_record_id)) == 96, "QC_FAIL: hv_record_id not unique or missing")
    assert_or_stop(all(c("Node02_HVT_A_COMPLETED","Node03_HVT_A_COMPLETED") %in% unique(df$node_id)), "QC_FAIL: missing expected nodes")
    assert_or_stop(all(df$candidate_label %in% c("QMSv5_01","QMSv5_02")), "QC_FAIL: candidate_label must be QMSv5_01/QMSv5_02")
  }

  if (QC_REQUIRE_BLINDING_FIELDS) {
    assert_or_stop(all(df$expected_match_candidate %in% c("QMSv5_01","QMSv5_02")), "QC_FAIL: expected_match_candidate invalid")
    assert_or_stop(all(df$expected_mismatch_candidate %in% c("QMSv5_01","QMSv5_02")), "QC_FAIL: expected_mismatch_candidate invalid")
    assert_or_stop(all(df$expected_match_candidate != df$expected_mismatch_candidate), "QC_FAIL: expected_match == expected_mismatch")
    assert_or_stop(all(df$classification_correct %in% c(0L,1L)), "QC_FAIL: classification_correct must be 0/1")
    assert_or_stop(all(!is.na(df$blinding_map_source_sha256) & df$blinding_map_source_sha256 != ""), "QC_FAIL: blinding_map_source_sha256 missing")
  }

  if (QC_REQUIRE_NODE03_PC_OVERRIDE_FLAG) {
    pc_node03 <- df %>% filter(node_id == "Node03_HVT_A_COMPLETED", group == "Positive_Controls")
    assert_or_stop(nrow(pc_node03) > 0, "QC_FAIL: expected Node03 Positive Controls rows")
    assert_or_stop(all(pc_node03$blinding_map_manual_override_flag == 1L), "QC_FAIL: Node03 Positive Controls must have manual override flag == 1")
  }

  assert_or_stop(all(is.finite(df$n_corpus)), "QC_FAIL: n_corpus missing")
  assert_or_stop(all(is.finite(df$tamper_k_effective)), "QC_FAIL: tamper_k_effective missing")

  df
}

build_derived_datasets <- function(df, out_run_dir) {
  dir.create(file.path(out_run_dir, DIR_DERIVED), showWarnings = FALSE, recursive = TRUE)

  df_primary <- df
  if (EXCLUDE_ARCHITECT_FROM_PRIMARY) df_primary <- df_primary %>% filter(is_blinded_primary_operator == 1L)

  arm_level <- df_primary %>%
    mutate(
      expected_is_match = (candidate_label == expected_match_candidate),
      expected_is_mismatch = (candidate_label == expected_mismatch_candidate),
      observed_is_pass = (pass_fail == "PASS")
    ) %>%
    group_by(node_id, group, arm, operator) %>%
    summarise(
      arm_correct = as.integer(all(observed_is_pass[expected_is_match] == TRUE) &&
                                 all(observed_is_pass[expected_is_mismatch] == FALSE)),
      hv_duration_seconds = mean(hv_duration_seconds, na.rm = TRUE),
      n_corpus = mean(n_corpus, na.rm = TRUE),
      tamper_k_raw = suppressWarnings(max(tamper_k[expected_is_mismatch], na.rm = TRUE)),
      swap_k = suppressWarnings(max(swap_k[expected_is_mismatch], na.rm = TRUE)),
      tamper_k_effective = suppressWarnings(max(tamper_k_effective[expected_is_mismatch], na.rm = TRUE)),
      .groups = "drop"
    ) %>%
    mutate(
      stage = ifelse(grepl("^IIIA_", group), "Stage_IIIA", "Stage_IV"),
      arm_family = case_when(
        grepl("^IIIA_", group) ~ "Stage_IIIA",
        group == "IIIB_Parity" ~ "IIIB_Parity",
        group == "Positive_Controls" ~ "Positive_Controls",
        group == "Tamper_Detection" ~ "Tamper_Detection",
        group == "Baseline_Reproducibility" ~ "Baseline_Reproducibility",
        TRUE ~ "Other"
      ),
      tamper_present_expected = as.integer(arm_family %in% c("Tamper_Detection","IIIB_Parity","Positive_Controls","Stage_IIIA"))
    )

  operator_summary <- arm_level %>%
    group_by(node_id, operator) %>%
    summarise(
      n_arms = n(),
      median_hvtA_sec = median(hv_duration_seconds, na.rm = TRUE),
      mean_hvtA_sec = mean(hv_duration_seconds, na.rm = TRUE),
      sd_hvtA_sec = sd(hv_duration_seconds, na.rm = TRUE),
      min_hvtA_sec = min(hv_duration_seconds, na.rm = TRUE),
      max_hvtA_sec = max(hv_duration_seconds, na.rm = TRUE),
      accuracy = mean(arm_correct, na.rm = TRUE),
      .groups = "drop"
    )

  write_csv(df_primary, file.path(out_run_dir, DIR_DERIVED, "hvtA_primary_rows.csv"))
  write_csv(arm_level,  file.path(out_run_dir, DIR_DERIVED, "hvtA_arm_level.csv"))
  write_csv(operator_summary, file.path(out_run_dir, DIR_DERIVED, "hvtA_operator_summary.csv"))

  list(df_primary = df_primary, arm_level = arm_level, operator_summary = operator_summary)
}

run_load_and_derive <- function(csv_path, out_base_dir) {
  run_dir <- file.path(out_base_dir, paste0("run_", utc_tag()))
  dir.create(run_dir, showWarnings = FALSE, recursive = TRUE)
  dir.create(file.path(run_dir, DIR_QC), showWarnings = FALSE, recursive = TRUE)

  df <- load_hvtA_with_blinding(csv_path)
  derived <- build_derived_datasets(df, run_dir)

  # SHA256 of analysis input (derived dataset anchoring not required; include digest)
  in_sha <- digest::digest(file = csv_path, algo = "sha256")

  manifest <- list(
    ts_utc = utc_tag(),
    input_csv = csv_path,
    input_csv_sha256 = in_sha,
    run_dir = run_dir,
    script = "R_01_load_hvtA.R",
    notes = "v6.0: locks n=n_corpus (source_total_rows_read); k_effective includes swaps; operator normalization; writes input sha256 for provenance."
  )
  writeLines(jsonlite::toJSON(manifest, auto_unbox = TRUE, pretty = TRUE),
             file.path(run_dir, DIR_QC, "run_manifest.json"))

  list(run_dir = run_dir, df = df, derived = derived)
}