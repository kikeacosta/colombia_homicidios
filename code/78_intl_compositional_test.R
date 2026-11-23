# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 78. Compositional versions of the state-space model, against the current
#     one, in the same hidden blocks of 72
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# The deaths of a unit-year are a composition of four parts: men and women,
# violent and non-violent. The model of 60 and 70 follows two log-ratios of it
# (the violent share, the non-violent sex ratio) and fixes a third (the share
# of men among the violent deaths). Two changes in the spirit of compositional
# data analysis are tested:
#   logit       the violent share on the log-ratio scale violent / non-violent
#               instead of its log, so that it stays between 0 and 1 (the log
#               version caps it at 0.9 inside the identity). matters where the
#               share is large: ages 15-44
#   logit + pi  in addition, the share of men among the violent deaths is a
#               third state per unit (logit, random walk), observed in the
#               years with violent deaths by sex and carried by the model in
#               the hidden years, instead of one fixed value per country
# Colombia runs only the first change: its table (60) has no sex of the
# victims. In the US, the sex of the victims by state is known in 1979-2004
# (microdata) and not after (WONDER).
#
# input    data_inter/intl_datasets.rds (72)
#          output/tables/intl_validation_predictions.csv (72: the log version)
# output   output/tables/intl_compositional_scores.csv
#          output/tables/intl_compositional_predictions.csv
#          output/tables/intl_compositional_parameters.csv
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
rm(list = ls()); gc(); source("code/00_setup.R")
source("code/70_intl_model_functions.R")
say <- function(...) cat(format(Sys.time(), "%H:%M:%S"), ..., "\n")
options(width = 200)

io <- readRDS("data_inter/intl_datasets.rds")
cfg <- io$cfg; datasets <- io$datasets
versions <- list("logit" = list(link = "logit", free_pi = FALSE), "logit + pi" = list(link = "logit", free_pi = TRUE))

pars <- list(); pred <- list()
for (nm in names(datasets)) {
  ds <- datasets[[nm]]; cc <- ds$country
  bl <- c(cfg[[cc]]$blocks, cfg[[cc]]$back, cfg[[cc]]$forward)
  for (vn in names(versions)) {
    v <- versions[[vn]]
    if (v$free_pi && cc == "colombia") next
    # rebuild the observations on the scale of the version (the national
    # quantities and the fixed share of men do not change)
    dat <- ds$md$md |> dplyr::select(country, unit, unit_label, year, d, dm, df, h, hm, hf)
    mdv <- intl_model_data(dat, pi_m = ds$md$pi_m, link = v$link)
    ft <- intl_fit(mdv$md, mdv$pi_m, link = v$link, free_pi = v$free_pi)
    say(nm, "|", vn, "|", paste(names(ft$par), signif(ft$par, 3), collapse = " "), "| loglik", round(ft$loglik, 1), "| convergence", ft$convergence)
    pars[[length(pars) + 1]] <- tibble(country = cc, ages = ds$ages, version = vn, parameter = names(ft$par), value = unname(ft$par),
                                       loglik = ft$loglik, convergence = ft$convergence)
    pred[[length(pred) + 1]] <- intl_validate(mdv$md, ft$par, mdv$pi_m, bl, link = v$link, free_pi = v$free_pi) |>
      mutate(country = cc, ages = ds$ages, version = vn,
             test = case_when(block %in% names(cfg[[cc]]$back) ~ "backcast", block %in% names(cfg[[cc]]$forward) ~ "forward", TRUE ~ "interior"))
  }
}
pars <- bind_rows(pars); write_csv(pars, "output/tables/intl_compositional_parameters.csv")
base <- read_csv("output/tables/intl_validation_predictions.csv", show_col_types = FALSE, col_types = cols(unit = col_character())) |>
  filter(family == "state-space") |> mutate(version = "log (current)")
pred <- bind_rows(base, bind_rows(pred) |> select(any_of(names(base))))
write_csv(pred, "output/tables/intl_compositional_predictions.csv")

# the same cells in every version
common <- pred |> count(country, ages, block, model, unit, year) |>
  left_join(pred |> distinct(country, ages, version) |> count(country, ages, name = "nv"), by = c("country", "ages")) |>
  filter(n == nv) |> select(-n, -nv)
pc <- pred |> inner_join(common, by = c("country", "ages", "block", "model", "unit", "year"))
sc <- intl_scores(pc, by = c("country", "ages", "test", "version", "model")) |>
  mutate(version = factor(version, c("log (current)", "logit", "logit + pi")))
write_csv(sc, "output/tables/intl_compositional_scores.csv")

cat("\n== median absolute error (%), by test, model version and variant (N without clues, S sex ratio, ST + national total) ==\n")
print(as.data.frame(sc |> mutate(m = sub(":.*", "", model), v = round(median_abs_error_pct)) |>
                      select(country, ages, test, version, m, v) |> pivot_wider(names_from = m, values_from = v) |>
                      arrange(country, ages, test, version)), row.names = FALSE)
cat("\n== coverage of the 90 % interval with the sex ratio (%) ==\n")
print(as.data.frame(sc |> filter(model == "S: sex ratio") |> mutate(cov = round(100 * coverage90)) |>
                      select(country, ages, test, version, cov) |> pivot_wider(names_from = version, values_from = cov) |>
                      arrange(country, ages, test)), row.names = FALSE)
say("done")
