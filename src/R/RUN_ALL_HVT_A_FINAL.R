rm(list = ls()); gc()
setwd("/Users/rosmontos/QMSv5.StageIV")

cat("\n=== QMSv5 HVT-A FINAL FULL RUN START ===\n")

# 0) Core load + derive (creates run_dir, derived/, qc/run_manifest.json)
source("R_00_config.R")
source("R_01_load_hvtA.R")

res <- run_load_and_derive(HVT_A_WITH_BLINDING_CSV, OUT_DIR)
cat("Run directory:\n", res$run_dir, "\n")

# Ensure output dirs exist
tables_dir <- file.path(res$run_dir, DIR_TABLES)
plots_dir  <- file.path(res$run_dir, DIR_PLOTS)
qc_dir     <- file.path(res$run_dir, DIR_QC)

dir.create(tables_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(plots_dir,  showWarnings = FALSE, recursive = TRUE)
dir.create(qc_dir,     showWarnings = FALSE, recursive = TRUE)

# 1) QC gates
source("R_02_qc_hvtA.R")
qc_hvtA_with_blinding(res$df)
qc_hvtA_arm_level(res$derived$arm_level)

# 2) Ontology §2 tables (branch-explicit evidence + membership + metrics)
source("R_05_table2_primary_outcomes_v2.R")
write_table2_outputs_v2(res$derived$df_primary, tables_dir)

# 3) Ontology §3 (detection performance) + §6–8 (supporting)
source("R_05_tables_hvtA.R")

write_table(table3a_detection_performance(res$derived$arm_level),
            file.path(tables_dir, "Table3a_detection_performance.csv"))

write_table(table3b_file_level_totals(res$derived$df_primary),
            file.path(tables_dir, "Table3b_file_level_totals.csv"))

write_table(table6_tamper_class(res$derived$df_primary),
            file.path(tables_dir, "Table6_tamper_class.csv"))

write_table(table7_commit_reveal(),
            file.path(tables_dir, "Table7_commit_reveal_integrity.csv"))

write_table(table8_corpus_characteristics(res$derived$df_primary),
            file.path(tables_dir, "Table8_corpus_characteristics.csv"))

# Optional: keep (non-ontology) helper context table
write_table(table_architect_context(res$df),
            file.path(tables_dir, "Architect_context_nonprimary.csv"))

# --- Supplementary: Candidate-level HVT by operator (PASS-like vs FAIL-like) ---
source("R_05f_tableS_candidate_level_hvt_by_operator.R")
write_candidate_level_operator_outputs(res$run_dir, include_architect_context = TRUE)

# 3.5) Additional supporting tables from R_05_tables_hvtA.R
write_table(table2_candidate_outcomes(res$derived$df_primary),
            file.path(tables_dir, "Table2_candidate_outcomes.csv"))

t4 <- table4_operator_agreement(res$derived$arm_level)
write_table(t4$per_arm, file.path(tables_dir, "Table4_per_arm_agreement.csv"))
write_table(t4$summary, file.path(tables_dir, "Table4_agreement_summary.csv"))
write_table(t4$kappa_by_node, file.path(tables_dir, "Table4_kappa_by_node.csv"))

write_table(table5_timing_by_operator(res$derived$operator_summary),
            file.path(tables_dir, "Table5_timing_by_operator.csv"))
write_table(table5_timing_by_family(res$derived$arm_level),
            file.path(tables_dir, "Table5_timing_by_family.csv"))

# 4) Ontology §4.1 Temporal parameters (missing table)
source("R_04a_table4_1_temporal_parameters.R")
make_temporal_table(res$run_dir)

# 5) Ontology §4.2 Complexity model summary table (missing table)
source("R_04b_table4_2_complexity_models.R")
write_complexity_model_table(res$run_dir)

# 5b) Load regression-derived figure label payload (must exist after R_04b)
labels_path <- file.path(res$run_dir, "tables", "Fig_model_labels.csv")
if (!file.exists(labels_path)) stop(paste0("QC FAIL: missing ", labels_path), call. = FALSE)

labels_df <- readr::read_csv(labels_path, show_col_types = FALSE)

# 6) Ontology §4 models printout (already used for console; optional)
source("R_04_models_hvtA_complexity.R")
m <- fit_complexity_models(res$derived$arm_level)
print_model_summaries(m)

# 7) Ontology §5 Cross-operator reproducibility (missing tables)
source("R_05_table5_cross_operator_reproducibility.R")
write_table5_cross_operator(res$run_dir)

# 8) Figures (final layout script)
source("R_06_plots_hvtA.R")# 9) Fig1 stats tables (missing 4 tables)
source("R_06a_fig1_stats_table.R")
make_fig1_stats(res$run_dir)

# Fig1 (family boxplot) does not require model labels
save_pub(plot_fig1_family(res$derived$df_primary),
         file.path(plots_dir, "Fig1_family_PASS_vs_FAIL.pdf"))

# Model-labeled figures (regression-derived r/p/adjR2) require labels_df
save_pub(plot_fig2_duration_vs_n(res$derived$df_primary, labels_df),
         file.path(plots_dir, "Fig2_duration_vs_n.pdf"))

save_pub(plot_fig2_duration_vs_n_by_stage(res$derived$df_primary, labels_df),
         file.path(plots_dir, "Fig2b_duration_vs_n_by_stage.pdf"))

save_pub(plot_fig3_duration_vs_k_fail(res$derived$df_primary, labels_df),
         file.path(plots_dir, "Fig3_duration_vs_k_fail.pdf"))

# Fig3b unchanged unless you later decide to label it too
save_pub(plot_fig3_duration_vs_k_fail_by_stage(res$derived$df_primary),
         file.path(plots_dir, "Fig3b_duration_vs_k_fail_by_stage.pdf"))

# 10) Item-level enumeration performance (files + ESFs)
source("R_05c_table_item_level_enumeration_performance.R")
write_item_level_enumeration_tables(res$run_dir)

# --- Supplementary: HVT by Operator ---
source("R_05d_tableS_hvt_by_operator.R")
derive_operator_tables(res$run_dir)

source("R_06b_figS_hvt_by_operator_boxplot.R")
plot_hvt_by_operator(res$run_dir)

cat("\n=== QMSv5 HVT-A FINAL FULL RUN COMPLETE ===\n")
cat("Outputs written to:\n", res$run_dir, "\n")