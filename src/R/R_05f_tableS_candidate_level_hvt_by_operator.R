# R_05f_tableS_candidate_level_hvt_by_operator.R (v6.2.3-final-layout)
# Supplementary: Candidate-level HVT timing by operator (PASS-like vs FAIL-like)
#
# LAYOUT-ONLY UPDATE:
# - No statistical logic or calculations changed.
# - Self-contained styling constants to avoid reliance on global variables.
# - Uses "HVT" terminology in labels.

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(stringr)
  library(tibble)
  library(ggplot2)
})

# ---- Local styling constants (self-contained) ----
.shell_grey <- "#F1EEE9"  # Oxford shell grey (match main figures)

# If oxford_cols isn't available (should be from R_00_config.R), define minimal fallback
if (!exists("oxford_cols")) {
  oxford_cols <- list(
    blue = "#002147",
    red = "#AA1A2D",
    charcoal = "#211D1C",
    offwhite = "#F2F0F0",
    ash = "#61615F"
  )
}

# Theme fallback if theme_oxford_pub isn't defined in this run
theme_oxford_pub_fallback <- function(base_size = 9, base_family = "Helvetica") {
  ggplot2::theme_minimal(base_size = base_size, base_family = base_family) +
    ggplot2::theme(
      plot.title.position = "plot",
      plot.title = ggplot2::element_text(face = "bold", size = base_size + 2),
      axis.title = ggplot2::element_text(face = "plain"),
      axis.text  = ggplot2::element_text(colour = oxford_cols$charcoal),
      panel.grid.major = ggplot2::element_blank(),
      panel.grid.minor = ggplot2::element_blank(),
      axis.line = ggplot2::element_line(linewidth = 0.35, colour = oxford_cols$charcoal),
      legend.title = ggplot2::element_text(face = "plain"),
      legend.text  = ggplot2::element_text(size = base_size - 1),
      legend.position = "top",
      plot.margin = ggplot2::margin(6, 6, 6, 6)
    )
}

.get_theme <- function() {
  if (exists("theme_oxford_pub", mode = "function")) theme_oxford_pub() else theme_oxford_pub_fallback()
}

assert_or_stop <- function(ok, msg) { if (!isTRUE(ok)) stop(msg, call. = FALSE) }

write_tbl <- function(df, path) {
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
  write_csv(df, path)
  message("Wrote: ", path)
}

# Use project-level save_pub if available (from R_00_config.R), otherwise fallback.
save_fig <- function(p, path, w_mm = 170, h_mm = 120) {
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
  if (exists("save_pub", mode = "function")) {
    save_pub(p, path, w = w_mm, h = h_mm, units = "mm")
  } else {
    ggsave(path, plot = p, width = w_mm, height = h_mm, units = "mm", dpi = 600, bg = "white")
  }
  message("Saved: ", path)
}

detect_passfail_col <- function(df) {
  if ("pass_fail_summary" %in% names(df)) return("pass_fail_summary")
  if ("pass_fail" %in% names(df)) return("pass_fail")
  stop("QC FAIL: no pass/fail column found (expected pass_fail_summary or pass_fail).", call. = FALSE)
}

summarize_tbl <- function(dat) {
  dat %>%
    group_by(operator, operator_role, workload) %>%
    summarise(
      n_rows = n(),
      mean_sec   = ifelse(all(!is.finite(hv_duration_seconds)), NA_real_, mean(hv_duration_seconds, na.rm = TRUE)),
      sd_sec     = ifelse(sum(is.finite(hv_duration_seconds)) < 2, NA_real_, sd(hv_duration_seconds, na.rm = TRUE)),
      median_sec = ifelse(all(!is.finite(hv_duration_seconds)), NA_real_, median(hv_duration_seconds, na.rm = TRUE)),
      iqr_sec    = ifelse(all(!is.finite(hv_duration_seconds)), NA_real_, IQR(hv_duration_seconds, na.rm = TRUE)),
      min_sec    = ifelse(all(!is.finite(hv_duration_seconds)), NA_real_, min(hv_duration_seconds, na.rm = TRUE)),
      max_sec    = ifelse(all(!is.finite(hv_duration_seconds)), NA_real_, max(hv_duration_seconds, na.rm = TRUE)),
      .groups = "drop"
    ) %>%
    arrange(operator_role, operator, workload)
}

write_candidate_level_operator_outputs <- function(run_dir,
                                                   include_architect_context = TRUE,
                                                   architect_name = "Dr. Fernando Telles") {

  run_dir <- normalizePath(run_dir, mustWork = TRUE)
  tables_dir <- file.path(run_dir, "tables")
  plots_dir  <- file.path(run_dir, "plots")

  primary_path <- file.path(run_dir, "derived", "hvtA_primary_rows.csv")
  assert_or_stop(file.exists(primary_path),
                 paste0("QC FAIL: missing derived file: ", primary_path))

  df <- read_csv(primary_path, show_col_types = FALSE)

  req <- c("node_id","group","arm","operator","candidate_label","hv_duration_seconds")
  miss <- setdiff(req, names(df))
  assert_or_stop(length(miss) == 0,
                 paste0("QC FAIL: missing required columns in hvtA_primary_rows.csv: ", paste(miss, collapse=", ")))

  passfail_col <- detect_passfail_col(df)

  df <- df %>%
    mutate(
      operator = str_squish(as.character(operator)),
      candidate_label = as.character(candidate_label),
      hv_duration_seconds = as.numeric(hv_duration_seconds),
      pass_fail_val = as.character(.data[[passfail_col]]),
      workload = ifelse(pass_fail_val == "PASS", "PASS-like", "FAIL-like"),
      operator_role = "Blinded operator"
    )

  arch_path <- file.path(tables_dir, "Architect_context_nonprimary.csv")
  if (include_architect_context && file.exists(arch_path)) {
    arch <- read_csv(arch_path, show_col_types = FALSE)

    req_a <- c("node_id","group","arm","operator","candidate_label","pass_fail","hv_duration_seconds")
    miss_a <- setdiff(req_a, names(arch))
    assert_or_stop(length(miss_a) == 0,
                   paste0("QC FAIL: missing required columns in Architect_context_nonprimary.csv: ", paste(miss_a, collapse=", ")))

    arch <- arch %>%
      mutate(
        operator = str_squish(as.character(operator)),
        candidate_label = as.character(candidate_label),
        hv_duration_seconds = as.numeric(hv_duration_seconds),
        pass_fail_val = as.character(pass_fail),
        workload = ifelse(pass_fail_val == "PASS", "PASS-like", "FAIL-like"),
        operator_role = "Architect (context only)"
      ) %>%
      select(node_id, group, arm, operator, candidate_label, hv_duration_seconds, pass_fail_val, workload, operator_role)

    df <- df %>%
      select(node_id, group, arm, operator, candidate_label, hv_duration_seconds, pass_fail_val, workload, operator_role) %>%
      bind_rows(arch)
  } else {
    df <- df %>%
      select(node_id, group, arm, operator, candidate_label, hv_duration_seconds, pass_fail_val, workload, operator_role)
  }

  qc_counts <- df %>%
    filter(operator_role == "Blinded operator") %>%
    count(operator, workload)

  assert_or_stop(all(c("PASS-like","FAIL-like") %in% unique(qc_counts$workload)),
                 "QC FAIL: missing PASS-like or FAIL-like rows for blinded operators in candidate-level data.")

  tbl_all <- df %>%
    group_by(operator, operator_role) %>%
    summarise(
      n_rows = n(),
      mean_sec   = mean(hv_duration_seconds, na.rm = TRUE),
      sd_sec     = sd(hv_duration_seconds, na.rm = TRUE),
      median_sec = median(hv_duration_seconds, na.rm = TRUE),
      iqr_sec    = IQR(hv_duration_seconds, na.rm = TRUE),
      min_sec    = min(hv_duration_seconds, na.rm = TRUE),
      max_sec    = max(hv_duration_seconds, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    arrange(operator_role, operator)

  tbl_pass <- summarize_tbl(filter(df, workload == "PASS-like"))
  tbl_fail <- summarize_tbl(filter(df, workload == "FAIL-like"))

  write_tbl(tbl_all,  file.path(tables_dir, "TableS_CandHVT_by_operator_all.csv"))
  write_tbl(tbl_pass, file.path(tables_dir, "TableS_CandHVT_by_operator_passlike.csv"))
  write_tbl(tbl_fail, file.path(tables_dir, "TableS_CandHVT_by_operator_faillike.csv"))

  # tests unchanged
  df_blinded <- df %>% filter(operator_role == "Blinded operator")
  test_rows <- list()

  if (n_distinct(df_blinded$operator) > 1) {
    k <- kruskal.test(hv_duration_seconds ~ operator, data = df_blinded)
    test_rows[[length(test_rows) + 1]] <- tibble(
      comparison = "All candidate rows (blinded operators only)",
      test = "Kruskal–Wallis",
      statistic = unname(k$statistic),
      df = unname(k$parameter),
      p_value = k$p.value,
      note = "Exploratory; unadjusted; candidate-level timing."
    )
  }

  datp <- df_blinded %>% filter(workload == "PASS-like")
  if (n_distinct(datp$operator) > 1) {
    k <- kruskal.test(hv_duration_seconds ~ operator, data = datp)
    test_rows[[length(test_rows) + 1]] <- tibble(
      comparison = "PASS-like only (blinded operators only)",
      test = "Kruskal–Wallis",
      statistic = unname(k$statistic),
      df = unname(k$parameter),
      p_value = k$p.value,
      note = "Exploratory; unadjusted."
    )
  }

  datf <- df_blinded %>% filter(workload == "FAIL-like")
  if (n_distinct(datf$operator) > 1) {
    k <- kruskal.test(hv_duration_seconds ~ operator, data = datf)
    test_rows[[length(test_rows) + 1]] <- tibble(
      comparison = "FAIL-like only (blinded operators only)",
      test = "Kruskal–Wallis",
      statistic = unname(k$statistic),
      df = unname(k$parameter),
      p_value = k$p.value,
      note = "Exploratory; unadjusted."
    )
  }

  test_tbl <- if (length(test_rows) == 0) tibble(
    comparison = character(0), test = character(0),
    statistic = numeric(0), df = numeric(0), p_value = numeric(0), note = character(0)
  ) else bind_rows(test_rows)

  write_tbl(test_tbl, file.path(tables_dir, "TableS_CandHVT_by_operator_tests.csv"))

  # ---- Plot (final) ----
  workload_cols <- c(
    "PASS-like" = "#689BE1",
    "FAIL-like" = oxford_cols$red
  )

  op_map <- c(
    "Dr. Fernando Telles" = "Operator 1",
    "Fernando Telles"     = "Operator 1",
    "Dr Fernando Telles"  = "Operator 1",
    "Dr. Jiexiang Yang"   = "Operator 3",
    "Dr Jiexiang Yang"    = "Operator 3",
    "Jiexiang Yang"       = "Operator 3",
    "Jacob Yang"          = "Operator 3",
    "Dr. Andrew Woo"      = "Operator 5",
    "Andrew Woo"          = "Operator 5",
    "Eng Benjamin Hookey" = "Operator 4",
    "Benjamin Hookey"     = "Operator 4",
    "Ben Hookey"          = "Operator 4"
  )

  node_map <- c(
    "Operator 3" = "Node 02",
    "Operator 4" = "Node 02",
    "Operator 5" = "Node 03",
    "Operator 1" = "Node 03"
  )

  dfp <- df %>%
    mutate(
      operator_id = dplyr::recode(operator, !!!op_map, .default = operator),
      operator_role = dplyr::recode(operator_role, "Architect (context only)" = "Study lead (context only)"),
      operator_role = factor(operator_role, levels = c("Blinded operator", "Study lead (context only)")),
      operator_id_node = paste0(operator_id, "\n(", node_map[operator_id], ")"),
      operator_id_node = factor(
        operator_id_node,
        levels = c(
          "Operator 4\n(Node 02)",
          "Operator 3\n(Node 02)",
          "Operator 5\n(Node 03)",
          "Operator 1\n(Node 03)"
        )
      ),
      workload = factor(workload, levels = c("FAIL-like", "PASS-like"))
    )

  p <- ggplot(dfp, aes(x = operator_id_node, y = hv_duration_seconds, fill = workload)) +
    geom_boxplot(outlier.shape = 16, linewidth = 0.35, colour = oxford_cols$charcoal) +
    facet_wrap(~ operator_role, scales = "free_x") +
    scale_fill_manual(values = workload_cols, drop = FALSE) +
    labs(
      title = "Candidate-level HVT duration by operator",
      x = expression(bold("Operator ID")),
      y = expression(bold("Candidate-level HVT Duration")~"(seconds)"),
      fill = NULL
    ) +
    .get_theme() +
    theme(
      plot.title = element_text(hjust = 0.5, face = "bold"),
      strip.background = element_rect(fill = .shell_grey, colour = NA),
      strip.text = element_text(face = "bold"),
      axis.text.x = element_text(face = "bold", angle = 0, hjust = 0.5, lineheight = 0.95)
    )

  save_fig(p, file.path(plots_dir, "FigS_CandHVT_by_operator_boxplot.pdf"), w_mm = 180, h_mm = 120)

  invisible(list(all = tbl_all, pass = tbl_pass, fail = tbl_fail, tests = test_tbl))
}