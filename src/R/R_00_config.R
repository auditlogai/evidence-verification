# R_00_config.R (v6.0)

# ---- USER CONFIG ----
HVT_A_WITH_BLINDING_CSV <- "/Users/rosmontos/QMSv5.StageIV/EXEC_HVT_A_FINAL/__EXTRACT_OUT__/hvtA_comparisons__WITH_BLINDING.csv"
OUT_DIR <- "/Users/rosmontos/QMSv5_R/out"
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

# ---- COHORT RULES (LOCKED) ----
EXCLUDE_ARCHITECT_FROM_PRIMARY <- TRUE
ARCHITECT_NAME_REGEX <- "(?i)fernando\\s+telles|drtelles"

# ---- QC INVARIANTS ----
QC_REQUIRE_COMPLETE_DATASET <- TRUE
QC_REQUIRE_BLINDING_FIELDS <- TRUE
QC_REQUIRE_NODE03_PC_OVERRIDE_FLAG <- TRUE

# ---- OUTPUT SUBFOLDERS ----
DIR_DERIVED <- "derived"
DIR_TABLES  <- "tables"
DIR_PLOTS   <- "plots"
DIR_QC      <- "qc"

# ============================
# Canonical visual formatting
# ============================

# ---- Oxford colour palette (hex) ----
oxford_cols <- list(
  blue      = "#002147",
  mauve     = "#776885",
  peach     = "#E08D79",
  red       = "#AA1A2D",
  viridian  = "#15616D",
  sky       = "#B9D6F2",
  charcoal  = "#211D1C",
  ash       = "#61615F",
  offwhite  = "#F2F0F0"
)

pal_oxford <- c(
  oxford_cols$blue,
  oxford_cols$viridian,
  oxford_cols$red,
  oxford_cols$mauve,
  oxford_cols$peach,
  oxford_cols$ash
)

theme_oxford_pub <- function(base_size = 9, base_family = "Helvetica") {
  ggplot2::theme_minimal(base_size = base_size, base_family = base_family) +
    ggplot2::theme(
      plot.title.position = "plot",
      plot.title = ggplot2::element_text(face = "bold", size = base_size + 2),
      plot.subtitle = ggplot2::element_text(size = base_size),
      plot.caption = ggplot2::element_text(size = base_size - 1, colour = oxford_cols$ash),

      axis.title = ggplot2::element_text(face = "plain"),
      axis.text  = ggplot2::element_text(colour = oxford_cols$charcoal),

      panel.grid.major = ggplot2::element_line(linewidth = 0.25, colour = oxford_cols$offwhite),
      panel.grid.minor = ggplot2::element_blank(),
      axis.line = ggplot2::element_line(linewidth = 0.35, colour = oxford_cols$charcoal),

      legend.title = ggplot2::element_text(face = "plain"),
      legend.text  = ggplot2::element_text(size = base_size - 1),
      legend.position = "right",

      strip.text = ggplot2::element_text(face = "bold"),
      strip.background = ggplot2::element_rect(fill = oxford_cols$offwhite, colour = NA),

      plot.margin = ggplot2::margin(6, 6, 6, 6)
    )
}

scale_colour_oxford <- function(...) ggplot2::scale_colour_manual(values = pal_oxford, ...)
scale_fill_oxford   <- function(...) ggplot2::scale_fill_manual(values = pal_oxford, ...)

geom_line_ox  <- function(..., linewidth = 0.6, alpha = 1) ggplot2::geom_line(..., linewidth = linewidth, alpha = alpha)
geom_point_ox <- function(..., size = 1.8, stroke = 0.25) ggplot2::geom_point(..., size = size, stroke = stroke)

# Export helper (vector-first)
save_pub <- function(p, filename, w = 170, h = 120, units = "mm") {
  ggplot2::ggsave(filename, plot = p, width = w, height = h, units = units, dpi = 600, bg = "white")
}