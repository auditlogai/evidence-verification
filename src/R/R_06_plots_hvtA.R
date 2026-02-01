# R_06_plots_hvtA.R (v6.3.0 - CORRECTED with model labels)
# Uses regression-derived r/p values from Fig_model_labels.csv for all figure annotations

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(readr)
})

# ----------------------------
# Local visual constants only
# ----------------------------
.shell_grey <- "#F1EEE9"  # Oxford shell grey (panel strip + CI ribbon)

.arm_family_order <- c(
  "Baseline_Reproducibility",
  "Tamper_Detection",
  "IIIB_Parity",
  "Positive_Controls",
  "Stage_IIIA"
)

.arm_family_labels <- c(
  "Baseline_Reproducibility" = "Baseline\nReproducibility",
  "Tamper_Detection"         = "Tamper\nDetection",
  "IIIB_Parity"              = "IIIB\nParity",
  "Positive_Controls"        = "Positive\nControls",
  "Stage_IIIA"               = "Stage\nIIIA"
)

.arm_family_fills <- c(
  "Baseline_Reproducibility" = "#689BE1",
  "Tamper_Detection"         = "#A9043D",
  "IIIB_Parity"              = "#E4CAD0",
  "Positive_Controls"        = oxford_cols$sky,
  "Stage_IIIA"               = oxford_cols$blue
)

.arm_family_shapes <- c(
  "Baseline_Reproducibility" = 21,
  "Tamper_Detection"         = 21,
  "IIIB_Parity"              = 21,
  "Positive_Controls"        = 21,
  "Stage_IIIA"               = 24
)

.mid_dot <- function(x) gsub("\\.", "\u00B7", x)

# LDH p formatting: 2 significant figures unless p<0·0001
.fmt_p <- function(p) {
  vapply(p, function(x) {
    if (!is.finite(x)) return("P not estimable")
    if (x < 0.0001) return("P<0\u00B70001")
    s <- signif(x, 2)
    txt <- format(s, scientific = FALSE, trim = TRUE)
    paste0("P=", .mid_dot(txt))
  }, character(1))
}

.fmt_r <- function(r) {
  vapply(r, function(x) {
    if (!is.finite(x)) return("r not estimable")
    paste0("r=", .mid_dot(sprintf("%.2f", x)))
  }, character(1))
}

# ----------------------------
# Model label payload helpers
# ----------------------------

# Load Fig_model_labels.csv (created by R_04b)
.load_fig_model_labels <- function(run_dir) {
  p <- file.path(run_dir, "tables", "Fig_model_labels.csv")
  if (!file.exists(p)) {
    stop(paste0("QC FAIL: missing Fig_model_labels.csv at: ", p), call. = FALSE)
  }
  read_csv(p, show_col_types = FALSE)
}

# Format label with r, p, adj_r2, n
.make_label <- function(r, p_value, adj_r2, n) {
  r_txt <- .fmt_r(r)
  p_txt <- .fmt_p(p_value)
  paste(r_txt, p_txt, sep = "\n")
}

# Get model label for specific figure panel with FACETING VARIABLES
# CORRECTED: Now includes comparison_type and stage for proper facet placement
.get_model_label_df <- function(labels_df, fig, panel, stage_code, 
                               corner = c("top_right", "top_left"),
                               include_facet_vars = TRUE) {
  corner <- match.arg(corner)
  
  row <- labels_df %>%
    filter(fig == !!fig, panel == !!panel, stage == !!stage_code)
  
  if (nrow(row) != 1) {
    stop(paste0("QC FAIL: expected exactly 1 label row for fig=", fig,
                " panel=", panel, " stage=", stage_code,
                " but found ", nrow(row)), call. = FALSE)
  }
  
  x_pos <- if (corner == "top_right") Inf else -Inf
  y_pos <- Inf
  
  label_text <- .make_label(row$r, row$p_value, row$adj_r2, row$n)
  
  # Base data frame
  result <- data.frame(
    label = label_text,
    x = x_pos,
    y = y_pos,
    stringsAsFactors = FALSE
  )
  
  # Add faceting variables if requested (required for faceted plots)
  if (include_facet_vars) {
    # Map panel to comparison_type (matches .decorate() output)
    result$comparison_type <- factor(
      ifelse(panel == "PASS-like", 
             "PASS-like (expected match)", 
             "FAIL-like (expected mismatch)"),
      levels = c("FAIL-like (expected mismatch)", "PASS-like (expected match)")
    )
    
    # Map stage code to stage factor (matches .decorate() output)
    if (stage_code == "Stage_IV") {
      result$stage <- factor("Stage IV", levels = c("Stage IV", "Stage IIIA"))
    } else if (stage_code == "Stage_IIIA") {
      result$stage <- factor("Stage IIIA", levels = c("Stage IV", "Stage IIIA"))
    }
    # For "Pooled", don't add stage variable (not used in faceting)
  }
  
  result
}

.theme_no_grid <- function() {
  theme(
    panel.grid.major = element_blank(),
    panel.grid.minor = element_blank()
  )
}

.theme_strip_shell <- function() {
  theme(
    strip.background = element_rect(fill = .shell_grey, colour = NA),
    strip.text = element_text(face = "bold")
  )
}

.theme_title_center <- function() {
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold")
  )
}

.decorate <- function(df_primary_rows) {
  df_primary_rows %>%
    mutate(
      comparison_type = ifelse(candidate_label == expected_match_candidate,
                               "PASS-like (expected match)",
                               "FAIL-like (expected mismatch)"),
      comparison_type = factor(comparison_type,
                               levels = c("FAIL-like (expected mismatch)",
                                          "PASS-like (expected match)")),
      stage = ifelse(grepl("^IIIA_", group), "Stage IIIA", "Stage IV"),
      stage = factor(stage, levels = c("Stage IV", "Stage IIIA")),
      arm_family = case_when(
        grepl("^IIIA_", group) ~ "Stage_IIIA",
        group == "IIIB_Parity" ~ "IIIB_Parity",
        group == "Positive_Controls" ~ "Positive_Controls",
        group == "Tamper_Detection" ~ "Tamper_Detection",
        group == "Baseline_Reproducibility" ~ "Baseline_Reproducibility",
        TRUE ~ "Other"
      ),
      arm_family = factor(arm_family, levels = .arm_family_order)
    )
}

# ----------------------------
# FIG 1 — family PASS vs FAIL (no annotations, unchanged)
# ----------------------------
plot_fig1_family <- function(df_primary_rows) {
  dat <- .decorate(df_primary_rows)

  ggplot(dat, aes(x = arm_family, y = hv_duration_seconds, fill = arm_family)) +
    geom_boxplot(outlier.shape = 16, linewidth = 0.35, colour = oxford_cols$charcoal) +
    facet_wrap(~comparison_type, scales = "free_x") +
    scale_x_discrete(
      limits = .arm_family_order,
      labels = .arm_family_labels,
      expand = expansion(add = 0.65)
    ) +
    scale_fill_manual(values = .arm_family_fills, breaks = .arm_family_order, drop = FALSE) +
    guides(fill = "none") +
    labs(
      title = "HVT Duration by Audit Arm Family",
      x = expression(bold("Audit Arm Family")),
      y = expression(bold("HVT Duration")~"(seconds)"),
      caption = "All arms are Stage IV unless otherwise indicated (Stage IIIA)."
    ) +
    theme_oxford_pub() +
    .theme_no_grid() +
    .theme_strip_shell() +
    .theme_title_center() +
    theme(
      axis.text.x = element_text(face = "bold", lineheight = 0.95, size = rel(0.90)),
      legend.position = "none"
    ) +
    scale_y_continuous(expand = expansion(mult = c(0.05, 0.12))) +
    coord_cartesian(clip = "off")
}

# ----------------------------
# FIG 2 — duration vs n (PASS vs FAIL panels) — CORRECTED with model labels
# ----------------------------
plot_fig2_duration_vs_n <- function(df_primary_rows, labels_df) {
  dat <- .decorate(df_primary_rows) %>%
    filter(is.finite(n_corpus), is.finite(hv_duration_seconds))

  # Get labels for both facets (PASS-like and FAIL-like pooled)
  lab_pass <- .get_model_label_df(labels_df, fig = "Fig2A", panel = "PASS-like", 
                                  stage_code = "Pooled", corner = "top_right",
                                  include_facet_vars = TRUE)
  lab_fail <- .get_model_label_df(labels_df, fig = "Fig2A", panel = "FAIL-like", 
                                  stage_code = "Pooled", corner = "top_right",
                                  include_facet_vars = TRUE)

  ggplot(dat, aes(x = n_corpus, y = hv_duration_seconds)) +
    geom_smooth(
      data = dat %>% filter(comparison_type == "PASS-like (expected match)"),
      method = "lm", se = TRUE,
      linewidth = 0.6,
      colour = oxford_cols$blue,
      fill = .shell_grey,
      alpha = 0.55
    ) +
    geom_smooth(
      data = dat %>% filter(comparison_type == "FAIL-like (expected mismatch)"),
      method = "lm", se = TRUE,
      linewidth = 0.6,
      colour = oxford_cols$red,
      fill = .shell_grey,
      alpha = 0.55
    ) +
    geom_point(
      aes(fill = arm_family, shape = arm_family),
      size = 2.2,
      stroke = 0.35,
      colour = oxford_cols$charcoal,
      alpha = 0.9
    ) +
    facet_wrap(~comparison_type) +
    scale_fill_manual(values = .arm_family_fills, breaks = .arm_family_order, 
                     labels = .arm_family_labels, drop = FALSE) +
    scale_shape_manual(values = .arm_family_shapes, breaks = .arm_family_order, 
                      labels = .arm_family_labels, drop = FALSE) +
    # PASS-like label (with faceting variable for correct placement)
    geom_text(
      data = lab_pass,
      aes(x = x, y = y, label = label),
      inherit.aes = FALSE,
      hjust = 1.05, vjust = 1.1, size = 3.2
    ) +
    # FAIL-like label (with faceting variable for correct placement)
    geom_text(
      data = lab_fail,
      aes(x = x, y = y, label = label),
      inherit.aes = FALSE,
      hjust = 1.05, vjust = 1.1, size = 3.2
    ) +
    labs(
      title = "Human Verification Time versus Corpus Size",
      x = "Corpus Size n (rows extracted from HASHES_GLOBAL.ndjson)",
      y = expression(bold("HVT Duration")~"(seconds)"),
      fill = NULL,
      shape = NULL
    ) +
    theme_oxford_pub() +
    .theme_no_grid() +
    .theme_strip_shell() +
    .theme_title_center() +
    scale_y_continuous(expand = expansion(mult = c(0.05, 0.12))) +
    theme(
      legend.position = "top",
      legend.direction = "horizontal",
      legend.box = "horizontal"
    )
}

# ----------------------------
# FIG 2b — duration vs n (by stage) — CORRECTED with model labels
# ----------------------------
plot_fig2_duration_vs_n_by_stage <- function(df_primary_rows, labels_df) {
  dat <- .decorate(df_primary_rows) %>%
    filter(is.finite(n_corpus), is.finite(hv_duration_seconds))

  # Get labels for all four facets (2 stages × 2 comparison types)
  lab_iv_pass <- .get_model_label_df(labels_df, fig = "Fig2B", panel = "PASS-like", 
                                     stage_code = "Stage_IV", corner = "top_right",
                                     include_facet_vars = TRUE)
  lab_iv_fail <- .get_model_label_df(labels_df, fig = "Fig2B", panel = "FAIL-like", 
                                     stage_code = "Stage_IV", corner = "top_right",
                                     include_facet_vars = TRUE)
  lab_iiia_pass <- .get_model_label_df(labels_df, fig = "Fig2B", panel = "PASS-like", 
                                       stage_code = "Stage_IIIA", corner = "top_right",
                                       include_facet_vars = TRUE)
  lab_iiia_fail <- .get_model_label_df(labels_df, fig = "Fig2B", panel = "FAIL-like", 
                                       stage_code = "Stage_IIIA", corner = "top_right",
                                       include_facet_vars = TRUE)

  ggplot(dat, aes(x = n_corpus, y = hv_duration_seconds)) +
    geom_smooth(
      data = dat %>% filter(comparison_type == "PASS-like (expected match)"),
      method = "lm", se = TRUE,
      linewidth = 0.6,
      colour = oxford_cols$blue,
      fill = .shell_grey,
      alpha = 0.55
    ) +
    geom_smooth(
      data = dat %>% filter(comparison_type == "FAIL-like (expected mismatch)"),
      method = "lm", se = TRUE,
      linewidth = 0.6,
      colour = oxford_cols$red,
      fill = .shell_grey,
      alpha = 0.55
    ) +
    geom_point(
      aes(fill = arm_family, shape = arm_family),
      size = 2.1,
      stroke = 0.35,
      colour = oxford_cols$charcoal,
      alpha = 0.9
    ) +
    facet_grid(stage ~ comparison_type) +
    scale_fill_manual(values = .arm_family_fills, breaks = .arm_family_order, 
                     labels = .arm_family_labels, drop = FALSE) +
    scale_shape_manual(values = .arm_family_shapes, breaks = .arm_family_order, 
                      labels = .arm_family_labels, drop = FALSE) +
    # Four facet labels (each with correct faceting variables)
    geom_text(data = lab_iv_pass,   aes(x = x, y = y, label = label), 
             inherit.aes = FALSE, hjust = 1.05, vjust = 1.1, size = 2.9) +
    geom_text(data = lab_iv_fail,   aes(x = x, y = y, label = label), 
             inherit.aes = FALSE, hjust = 1.05, vjust = 1.1, size = 2.9) +
    geom_text(data = lab_iiia_pass, aes(x = x, y = y, label = label), 
             inherit.aes = FALSE, hjust = 1.05, vjust = 1.1, size = 2.9) +
    geom_text(data = lab_iiia_fail, aes(x = x, y = y, label = label), 
             inherit.aes = FALSE, hjust = 1.05, vjust = 1.1, size = 2.9) +
    labs(
      title = "Stratified Human Verification Time versus Corpus Size by Stage",
      x = "Corpus Size n (rows extracted from HASHES_GLOBAL.ndjson)",
      y = expression(bold("HVT Duration")~"(seconds)"),
      fill = NULL,
      shape = NULL
    ) +
    theme_oxford_pub() +
    .theme_no_grid() +
    .theme_strip_shell() +
    .theme_title_center() +
    scale_y_continuous(expand = expansion(mult = c(0.05, 0.12))) +
    theme(
      legend.position = "top",
      legend.direction = "horizontal",
      legend.box = "horizontal"
    )
}

# ----------------------------
# FIG 3 — duration vs k_effective (FAIL-like only) — CORRECTED with model labels
# ----------------------------
plot_fig3_duration_vs_k_fail <- function(df_primary_rows, labels_df) {
  dat <- .decorate(df_primary_rows) %>%
    filter(comparison_type == "FAIL-like (expected mismatch)",
           is.finite(tamper_k_effective),
           is.finite(hv_duration_seconds))

  # Get label for Fig1 (no faceting, so don't include facet variables)
  stats_df <- .get_model_label_df(labels_df, fig = "Fig1", panel = "FAIL-like", 
                                  stage_code = "Pooled", corner = "top_left",
                                  include_facet_vars = FALSE)

  ggplot(dat, aes(x = tamper_k_effective, y = hv_duration_seconds)) +
    geom_smooth(
      method = "lm", se = TRUE,
      linewidth = 0.6,
      colour = oxford_cols$red,
      fill = .shell_grey,
      alpha = 0.55
    ) +
    geom_point(
      aes(fill = arm_family, shape = arm_family),
      size = 2.2,
      stroke = 0.35,
      colour = oxford_cols$charcoal,
      alpha = 0.9
    ) +
    geom_text(
      data = stats_df,
      aes(x = x, y = y, label = label),
      inherit.aes = FALSE,
      hjust = -0.05,
      vjust = 1.1,
      size = 3.2
    ) +
    scale_fill_manual(values = .arm_family_fills, breaks = .arm_family_order, 
                     labels = .arm_family_labels, drop = FALSE) +
    scale_shape_manual(values = .arm_family_shapes, breaks = .arm_family_order, 
                      labels = .arm_family_labels, drop = FALSE) +
    labs(
      title = "Human Verification Time versus Tamper Burden (FAIL-like arms)",
      x = "Tamper Size (k_effective = missing + extras + swaps)",
      y = expression(bold("HVT Duration")~"(seconds)"),
      fill = NULL,
      shape = NULL
    ) +
    theme_oxford_pub() +
    .theme_no_grid() +
    .theme_strip_shell() +
    .theme_title_center()
}

# ----------------------------
# FIG 3b — FAIL-like vs n, Stage IV fit (no annotations, unchanged)
# ----------------------------
plot_fig3_duration_vs_k_fail_by_stage <- function(df_primary_rows) {
  dat_all <- .decorate(df_primary_rows) %>%
    filter(comparison_type == "FAIL-like (expected mismatch)",
           is.finite(n_corpus),
           is.finite(hv_duration_seconds))

  dat_fit <- dat_all %>% filter(stage == "Stage IV")

  ggplot(dat_all, aes(x = n_corpus, y = hv_duration_seconds)) +
    geom_smooth(
      data = dat_fit,
      method = "lm", se = TRUE,
      linewidth = 0.6,
      colour = oxford_cols$red,
      fill = .shell_grey,
      alpha = 0.55
    ) +
    geom_point(
      aes(fill = arm_family, shape = arm_family),
      size = 2.2,
      stroke = 0.35,
      colour = oxford_cols$charcoal,
      alpha = 0.9
    ) +
    scale_fill_manual(values = .arm_family_fills, breaks = .arm_family_order, 
                     labels = .arm_family_labels, drop = FALSE) +
    scale_shape_manual(values = .arm_family_shapes, breaks = .arm_family_order, 
                      labels = .arm_family_labels, drop = FALSE) +
    labs(
      title = "HVT duration vs corpus size n",
      subtitle = "FAIL-like (expected mismatch)",
      x = "Corpus Size n (rows extracted from HASHES_GLOBAL.ndjson)",
      y = expression(bold("HVT Duration")~"(seconds)"),
      fill = NULL,
      shape = NULL
    ) +
    theme_oxford_pub() +
    .theme_no_grid() +
    .theme_strip_shell() +
    .theme_title_center()
}