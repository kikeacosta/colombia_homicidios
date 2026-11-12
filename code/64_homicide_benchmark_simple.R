# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 64. Benchmark: a simple regression that distributes the national total of
#     homicides among the units with the sex ratio, against the state-space
#     model of 60, in the same hidden blocks
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# The municipal model of 07 (homicides of the municipality from its sex
# ratio, its excess mortality and the homicide rate of the department, with
# random effects, predictions rescaled to the department total) taken one
# level up: homicides of the unit from the NATIONAL homicide rate and the sex
# ratio of the unit, rescaled to the national total. The question is how much
# the state-space model of 60 gains over it.
#
# model     negative binomial mixed model (glmmTMB), offset log(population)
#             B0  national rate + crude death rate + (1 | unit)
#             B1  B0 + log sex ratio of the unit, slope varying by unit
#             B2  B1 + log excess mortality (as 06: deaths above the upper
#                 95 % bound of a quasi-Poisson trend, three passes; here the
#                 trend is a smooth in time, the series being 105 years long)
#             B3  B1 + national log sex ratio (control for the trend of the
#                 non-violent sex ratio, 1.04 in the 1920s to 1.29 in the 1980s)
#           differences with 07: no zero inflation (units have no zeros), the
#           national rate in logs and without the interaction with the share
#           of population, the crude death rate in logs
# training  two schemes, both WITHOUT the unit-years of the hidden block:
#             all     anuarios (1923-1965) and EEVV (1979-2019)
#             modern  EEVV only: the original plan of training on 1979+ and
#                     applying it to the past
# given     inside the block the model gets the sex ratio and the deaths of
#           each unit and the national total of homicides of the year (sum of
#           the units that have a count). predictions are rescaled to it
# compared  with the variants of 60 in the same blocks, on the same cells:
#           N, S, SP (without the national total) and T, ST (with it, and
#           rescaled to it here as the simple model is). 60
#           estimates its parameters once with all the data; this model is
#           refitted without each block, so the comparison favours 60 a little
#
# inputs   output/tables/homicide_backcast_dept_1915-2019.csv              (60)
#          output/tables/homicide_backcast_validation_predictions.csv      (60)
# outputs  output/tables/homicide_benchmark_simple_predictions.csv
#          output/tables/homicide_benchmark_comparison.csv
#          output/tables/homicide_benchmark_comparison_units.csv
#          figures/08_backcast/benchmark_simple_check.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
rm(list = ls()); gc(); source("code/00_setup.R")
library(glmmTMB)
library(mgcv)

dir.create("figures/08_backcast", showWarnings = FALSE, recursive = TRUE)
say <- function(...) cat(format(Sys.time(), "%H:%M:%S"), ..., "\n")
options(width = 200)

blocks <- list("1946-1965" = 1946:1965, "1946-1953" = 1946:1953, "1954-1965" = 1954:1965,
               "1979-1984" = 1979:1984, "1985-1997" = 1985:1997, "1998-2010" = 1998:2010)
fig_units <- c("antioquia", "valle_del_cauca", "tolima", "bolivar")

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 1. data ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
est <- read_csv("output/tables/homicide_backcast_dept_1915-2019.csv", show_col_types = FALSE)
pan <- est |>
  transmute(
    unit, unit_label, year, d = deaths_reg, sr = sex_ratio_deaths,
    # a partial year (EEVV 1979 in some units) counts deaths and homicides of
    # part of the year: the exposure is cut in the same proportion
    expo = pop * deaths_reg / deaths_adj,
    gross = !is.na(anuario_gross_error_prob) & anuario_gross_error_prob > 0.5,
    h = coalesce(hom_eevv, ifelse(gross, NA, hom_anuario)),
    h = ifelse(!is.na(h) & h > 0, h, NA),
    src = case_when(is.na(h) ~ NA_character_, !is.na(hom_eevv) ~ "eevv", TRUE ~ "anuario"),
    lsr = log(sr), log_cdr = log(d / expo)
  ) |>
  arrange(unit, year)

# excess mortality as in 06, by unit: deaths above the upper 95 % bound of a
# quasi-Poisson trend, refitted twice without the years above the bound
excess_unit <- function(z) {
  ok <- !is.na(z$d) & !is.na(z$expo)
  w <- as.numeric(ok)
  for (i in 1:3) {
    m <- gam(d ~ s(year, k = 8) + offset(log(expo)), data = z[ok, ], weights = w[ok], family = quasipoisson)
    pr <- predict(m, newdata = z[ok, ], type = "response", se.fit = TRUE)
    up <- pr$fit + 1.96 * pr$se.fit
    w[ok] <- as.numeric(z$d[ok] <= up)
  }
  z$excess <- NA_real_
  z$excess[ok] <- pmax(z$d[ok] - up, 0)
  z
}
pan <- pan |> group_by(unit) |> group_modify(~ excess_unit(.x)) |> ungroup() |>
  mutate(exc_log = log((excess + 1) / expo))

# national quantities of each year: the homicide rate of the units that have
# a count (what the model is given) and the sex ratio of all the deaths
nat <- pan |>
  mutate(dm = d * sr / (1 + sr), df = d / (1 + sr)) |>
  summarise(h_nat = sum(h, na.rm = TRUE), expo_nat = sum(expo[!is.na(h)]),
            lsr_nat = log(sum(dm, na.rm = TRUE) / sum(df, na.rm = TRUE)), .by = year) |>
  mutate(log_nat = ifelse(h_nat > 0, log(h_nat / expo_nat), NA))
pan <- pan |> left_join(nat, by = "year") |>
  mutate(lsr_c = lsr - mean(lsr[!is.na(h)], na.rm = TRUE), lsr_nat_c = lsr_nat - mean(lsr_nat[!is.na(h)], na.rm = TRUE))
cells <- pan |> filter(!is.na(h), !is.na(lsr), !is.na(exc_log), !is.na(log_nat))
say("unit-years with a homicide count and a sex ratio:", nrow(cells), "| anuario", sum(cells$src == "anuario"), "| EEVV", sum(cells$src == "eevv"))
say("unit-years with a count but no sex ratio (not predicted):", sum(!is.na(pan$h) & is.na(pan$lsr)))

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 2. models and hidden blocks ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
forms <- list(
  "B0: national total" = h ~ log_nat + log_cdr + (1 | unit) + offset(log(expo)),
  "B1: sex ratio + national total" = h ~ log_nat + log_cdr + lsr_c + (1 + lsr_c | unit) + offset(log(expo)),
  "B2: sex ratio + excess + national total" = h ~ log_nat + log_cdr + lsr_c + exc_log + (1 + lsr_c | unit) + offset(log(expo)),
  "B3: sex ratio + national sex ratio + national total" = h ~ log_nat + log_cdr + lsr_c + lsr_nat_c + (1 + lsr_c | unit) + offset(log(expo))
)
fit_one <- function(f, dat) {
  m <- tryCatch(suppressWarnings(glmmTMB(f, data = dat, family = nbinom2)), error = function(e) NULL)
  bad <- is.null(m) || !isTRUE(m$sdr$pdHess) || m$fit$convergence != 0
  if (bad && grepl("1 \\+ lsr_c \\| unit", deparse1(f))) {
    # correlated intercept and slope did not converge: uncorrelated ones
    f2 <- as.formula(gsub("(1 + lsr_c | unit)", "(1 | unit) + (0 + lsr_c | unit)", deparse1(f), fixed = TRUE))
    m2 <- tryCatch(suppressWarnings(glmmTMB(f2, data = dat, family = nbinom2)), error = function(e) NULL)
    if (!is.null(m2)) return(list(m = m2, note = "uncorrelated"))
  }
  list(m = m, note = if (bad) "not converged" else "ok")
}

pred <- list(); coefs <- list()
for (b in names(blocks)) {
  inb <- cells$year %in% blocks[[b]]
  for (tr in c("all", "modern")) {
    train <- cells[!inb & (tr == "all" | cells$src == "eevv"), ]
    test <- cells[inb, ]
    for (mn in names(forms)) {
      ft <- fit_one(forms[[mn]], train)
      if (is.null(ft$m)) { say("FAILED", b, tr, mn); next }
      mu <- predict(ft$m, newdata = test, type = "response", allow.new.levels = TRUE)
      pred[[length(pred) + 1]] <- test |>
        transmute(block = b, train = tr, model = mn, unit, unit_label, year, pop = expo, hom_obs = h, hom_raw = mu) |>
        mutate(hom_pred = hom_raw * sum(hom_obs) / sum(hom_raw), .by = year) # rescaled to the national total
      fe <- fixef(ft$m)$cond
      coefs[[length(coefs) + 1]] <- tibble(block = b, train = tr, model = mn, note = ft$note, n_train = nrow(train),
                                           term = names(fe), estimate = unname(fe))
    }
  }
  say("block", b, "done")
}
pred <- bind_rows(pred)
coefs <- bind_rows(coefs)
write_csv(pred, "output/tables/homicide_benchmark_simple_predictions.csv")
cat("\n== fits that did not converge as specified ==\n")
print(as.data.frame(coefs |> distinct(block, train, model, note) |> count(model, train, note)), row.names = FALSE)
cat("\n== coefficient of the log sex ratio (B1), by block and training set ==\n")
print(as.data.frame(coefs |> filter(model == "B1: sex ratio + national total", term %in% c("lsr_c", "log_nat", "log_cdr")) |>
                      mutate(estimate = round(estimate, 2)) |> pivot_wider(names_from = term, values_from = estimate) |> select(-model)), row.names = FALSE)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 3. comparison with the state-space model, on the same cells ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ss <- read_csv("output/tables/homicide_backcast_validation_predictions.csv", show_col_types = FALSE) |>
  transmute(block, family = "state-space (60)", model = variant, unit, year, hom_obs, hom_pred) |>
  # T and ST get the national total through the filter, and the smoothed
  # estimates end up 1-25 % above it (the total is a sum of exponentials and
  # the filter treats it as linear). they are rescaled to the total here,
  # which is what the simple model does with its own predictions
  mutate(hom_pred = if (grepl("national total", model[1])) hom_pred * sum(hom_obs) / sum(hom_pred) else hom_pred, .by = c(block, model, year))
simple <- pred |>
  transmute(block, family = paste0("simple (64), trained on ", train), model, unit, year, hom_obs, hom_pred)
# cells predicted by every model of the block
both <- bind_rows(ss, simple)
n_mod <- both |> distinct(block, family, model) |> count(block, name = "n_models")
common <- both |> count(block, unit, year) |> left_join(n_mod, by = "block")
# the Policia variants of 60 do not exist in every block: a cell is common if
# all the models that exist in its block predict it
common <- common |> filter(n == n_models) |> select(block, unit, year)
cmp <- both |> inner_join(common, by = c("block", "unit", "year")) |>
  mutate(lr = log(hom_pred / hom_obs))
stats <- function(z) z |>
  mutate(tw = log(hom_obs) - mean(log(hom_obs)), ew = log(hom_pred) - mean(log(hom_pred)), .by = unit) |>
  summarise(n = n(), median_abs_error_pct = 100 * median(abs(exp(lr) - 1)), p90_abs_error_pct = 100 * quantile(abs(exp(lr) - 1), 0.9),
            rmse_log = sqrt(mean(lr^2)), r_log_within_unit = cor(tw, ew))
tab <- cmp |> group_by(block, family, model) |> group_modify(~ stats(.x)) |> ungroup()
write_csv(tab, "output/tables/homicide_benchmark_comparison.csv")
cat("\n== median absolute error (%), same cells in every column ==\n")
print(as.data.frame(tab |> mutate(col = paste0(ifelse(grepl("state", family), "SS ", ifelse(grepl("all", family), "simple-all ", "simple-modern ")), sub(":.*", "", model)),
                                  v = round(median_abs_error_pct)) |>
                      select(block, n, col, v) |> pivot_wider(names_from = col, values_from = v)), row.names = FALSE)
cat("\n== rmse of the log error ==\n")
print(as.data.frame(tab |> mutate(col = paste0(ifelse(grepl("state", family), "SS ", ifelse(grepl("all", family), "simple-all ", "simple-modern ")), sub(":.*", "", model)),
                                  v = round(rmse_log, 2)) |>
                      select(block, col, v) |> pivot_wider(names_from = col, values_from = v)), row.names = FALSE)

# by unit, the two models that get the same information: sex ratio and national total
tab_u <- cmp |>
  filter(model %in% c("ST: sex ratio + national total", "B1: sex ratio + national total"), block != "1946-1965") |>
  mutate(era = case_when(block %in% c("1946-1953", "1954-1965") ~ "1946-1965", block == "1979-1984" ~ "1979-1984", TRUE ~ "1985-2010")) |>
  summarise(n = n(), median_abs_error_pct = 100 * median(abs(exp(lr) - 1)), .by = c(era, unit, family))
write_csv(tab_u, "output/tables/homicide_benchmark_comparison_units.csv")
cat("\n== by unit: median absolute error (%), sex ratio + national total ==\n")
print(as.data.frame(tab_u |> mutate(col = paste(era, ifelse(grepl("state", family), "SS", ifelse(grepl("all", family), "simple-all", "simple-modern"))),
                                    v = round(median_abs_error_pct)) |>
                      select(unit, col, v) |> pivot_wider(names_from = col, values_from = v) |> arrange(unit)), row.names = FALSE)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 4. figure: observed and predicted, four units ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ink <- "#1f1f1e"
lines_lab <- c("ss" = "Modelo actual: razón de sexos + total nacional", "simple_all" = "Modelo simple, entrenado con anuarios y EEVV",
               "simple_modern" = "Modelo simple, entrenado solo con EEVV (1979+)")
fig_blocks <- setdiff(names(blocks), "1946-1965")
lab_u <- pan |> distinct(unit, unit_label)
fd <- bind_rows(
  cmp |> filter(model == "ST: sex ratio + national total") |> mutate(line = "ss"),
  cmp |> filter(model == "B1: sex ratio + national total", grepl("all", family)) |> mutate(line = "simple_all"),
  cmp |> filter(model == "B1: sex ratio + national total", grepl("modern", family)) |> mutate(line = "simple_modern")
) |>
  filter(block %in% fig_blocks, unit %in% fig_units) |>
  left_join(pan |> select(unit, year, expo), by = c("unit", "year")) |>
  left_join(lab_u, by = "unit") |>
  mutate(rate = 1e5 * hom_pred / expo, line = factor(lines_lab[line], lines_lab),
         unit_label = factor(unit_label, lab_u$unit_label[match(fig_units, lab_u$unit)]))
obs <- pan |> filter(unit %in% fig_units, !is.na(h), year >= 1938) |>
  mutate(rate = 1e5 * h / expo, unit_label = factor(unit_label, levels(fd$unit_label)),
         fuente = ifelse(src == "eevv", "EEVV", "Anuarios"))
rect <- tibble(block = fig_blocks) |> mutate(x0 = as.numeric(substr(block, 1, 4)) - 0.4, x1 = as.numeric(substr(block, 6, 9)) + 0.4)
fig <- ggplot() +
  geom_rect(data = rect, aes(xmin = x0, xmax = x1, ymin = 0, ymax = Inf), fill = "grey94") +
  geom_line(data = obs, aes(year, rate, group = fuente), colour = ink, linewidth = 0.35) +
  geom_point(data = obs, aes(year, rate, shape = fuente), colour = ink, fill = "white", size = 1.3) +
  geom_line(data = fd, aes(year, rate, colour = line, group = interaction(block, line)), linewidth = 0.65) +
  scale_shape_manual(values = c("Anuarios" = 21, "EEVV" = 16), name = NULL) +
  scale_colour_manual(values = setNames(c("#2a78d6", "#1baf7a", "#eb6834"), lines_lab), name = NULL) +
  scale_y_log10(labels = scales::label_number(drop0trailing = TRUE)) +
  facet_wrap(~unit_label, ncol = 2, scales = "free_y") +
  labs(title = "Modelo actual y modelo simple: homicidios observados y predichos en años ocultos",
       subtitle = paste0("Homicidios por 100.000 habitantes, escala logarítmica. Franjas grises: años ocultos a los dos modelos.\n",
                         "Dentro de la franja los dos reciben lo mismo: la razón de sexos de la unidad y el total nacional de homicidios del año."),
       x = NULL, y = NULL,
       caption = "El modelo simple se vuelve a ajustar sin cada bloque; el actual usa los parámetros estimados con todos los datos.") +
  guides(colour = guide_legend(order = 1, nrow = 1), shape = guide_legend(order = 2)) +
  theme_minimal(base_size = 10) +
  theme(legend.position = "top", legend.box = "vertical", legend.margin = margin(0, 0, 0, 0), panel.grid.minor = element_blank(),
        panel.grid.major.x = element_blank(), strip.text = element_text(face = "bold", hjust = 0),
        plot.title = element_text(face = "bold"), plot.caption = element_text(colour = "grey45", hjust = 0))
ggsave("figures/08_backcast/benchmark_simple_check.png", fig, w = 12, h = 8, bg = "white", dpi = 160)
say("done")
