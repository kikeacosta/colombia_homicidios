# run_all.R ------------------------------------------------------------------
# runs the full pipeline from the raw data. each script runs in a fresh R
# process, so the rm(list = ls()) at the top of every script cannot interfere
# with this loop. run from the project root, with Rscript on the PATH:
#
#   Rscript run_all.R
#
# 01 needs the 45 DANE microdata files in data_input/micro/ and several GB of
# RAM; 03 needs the three DANE projection workbooks in data_input/DANEpop/.
# 13 (extract_dane_lifetables) needs the PDF text, see its header, and is not run here
# the historical module (code/historical/) is not part of this run.

scripts <- c(
  "01_load_microdata.R",
  "02_summarise_deaths.R",
  "03_population.R",
  "04_descriptives.R",
  "05_municipal_panel.R",
  "06_excess_deaths.R",
  "07_model_zinb.R",
  "08_model_validation.R",
  "09_sex_ratio_by_cause.R",
  "10_registration_completeness.R",
  "11_shared_dataset.R",
  "11b_shared_dataset_age.R",
  "12_underregistration_test.R",
  "14_completeness_dane.R",
  "15_model_completeness.R",
  "16_age_placebo.R",
  "17_residence.R",
  "18_ddm_completeness.R",
  "19_completeness_vs_correlation.R"
)

t0 <- Sys.time()
for (s in scripts) {
  message(format(Sys.time(), "%H:%M:%S"), "  ", s)
  status <- system2("Rscript", shQuote(file.path("code", s)))
  if (status != 0) stop("script failed: ", s)
}
message("done in ", round(difftime(Sys.time(), t0, units = "mins"), 1), " min")
