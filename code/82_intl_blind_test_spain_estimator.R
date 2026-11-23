# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 82. Blind test of the Spain estimator (80) where the causes are known:
#     violent deaths from the excess of male deaths, and the split of the
#     excess deaths into violent and non-violent
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# The estimator of 80 is applied exactly as in Spain, using only deaths by
# unit, year and sex, and then compared with the causes:
#   - base years (a calmer period): per unit, rho = mean sex ratio of ALL
#     deaths, and the expected deaths (unit levels and a common log-linear
#     trend)
#   - test years: H = (D_M - rho D_F) / (pi - rho (1 - pi)), pi = 0.95 as in
#     Spain; excess = D - expected; non-violent excess = excess - H
# rho includes the violence of the base years, so H estimates violence ABOVE
# the base level. The truth on the same footing, with s the violent share of
# the unit in the base years and E the expected deaths:
#     violent above base      = h - s E
#     non-violent excess      = (D - h) - (1 - s) E
# (the two add up to the excess). The two assumptions are also measured: the
# share of men among violent deaths (pi) and the change of the sex ratio of
# non-violent deaths against the base years.
# Tests: Ecuador (2015-2019 base; COVID-19 in 2020-2021, the surge of
# 2022-2024), Mexico (2000-2006; the rise from 2008, COVID-19 in 2020-2021),
# Colombia (1979-1983; the rise of 1985-1993 and 1998-2002), Brazil
# (1996-2000), United States (1999-2004).
# Colombia: EEVV microdata by age (deaths and violent deaths by sex), the 15
# units of 60. United States: no violent deaths by sex from 2005.
#
# input    data_inter/intl_datasets.rds (72), data_inter/deaths_munic_age_1979-2023.rds
# output   output/tables/intl_blind_test_spain_estimator.csv (country, ages, year)
#          output/tables/intl_blind_test_spain_estimator_units.csv (unit, period)
#          figures/09_international/intl_blind_test_spain_estimator.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
rm(list = ls()); gc(); source("code/00_setup.R")
options(width = 220)

ds <- readRDS("data_inter/intl_datasets.rds")$datasets
# Colombia from the EEVV microdata by age (deaths and violent deaths by sex),
# the 15 units of 60; violent = homicide + undetermined intent + legal
# intervention (dx_v, as in 60)
cod_unit <- c("05" = "antioquia", "08" = "atlantico", "13" = "bolivar", "23" = "bolivar", "70" = "bolivar",
              "15" = "boyaca", "17" = "caldas", "63" = "caldas", "66" = "caldas", "19" = "cauca",
              "11" = "cundinamarca", "25" = "cundinamarca", "41" = "huila", "47" = "magdalena", "20" = "magdalena",
              "52" = "narino", "54" = "norte_de_santander", "68" = "santander", "73" = "tolima", "76" = "valle_del_cauca")
ca <- readRDS("data_inter/deaths_munic_age_1979-2023.rds") |>
  mutate(cod_dpto = sprintf("%02d", as.integer(cod_dpto)), unit = coalesce(unname(cod_unit[cod_dpto]), "territorios")) |>
  filter(year %in% 1979:2019)
col_ds <- function(dat) dat |> summarise(d = sum(dx_tot), dm = sum(dx_tot[sex %in% "m"]), df = sum(dx_tot[sex %in% "f"]), # a few deaths have no sex
                                         h = sum(dx_v), hm = sum(dx_v[sex %in% "m"]), hf = sum(dx_v[sex %in% "f"]), .by = c(unit, year)) |>
  mutate(unit_label = unit) |> arrange(unit, year)
ds[["colombia all"]] <- list(md = list(md = col_ds(ca)))
ds[["colombia 15-44"]] <- list(md = list(md = col_ds(filter(ca, age %in% seq(15, 40, 5)))))
tests <- tribble(~country, ~base0, ~base1, ~label,
                 "ecuador", 2015, 2019, "Ecuador",
                 "mexico", 2000, 2006, "México",
                 "colombia", 1979, 1983, "Colombia",
                 "brazil", 1996, 2000, "Brasil",
                 "us", 1999, 2004, "Estados Unidos")
PI <- 0.95

blind <- function(dat, base, pi = PI, country_name = "") {
  dat <- dat |> filter(dm > 0, df > 0)
  b <- dat |> filter(year %in% base)
  ub <- b |> summarise(rho = exp(mean(log(dm / df))), s = sum(h) / sum(d),
                       lsr_nv = mean(log((dm - hm) / (df - hf))), .by = unit)
  fit <- lm(log(d) ~ factor(unit) + I(year - max(base)), data = b)
  t <- dat |> filter(year > max(base), unit %in% ub$unit) |> left_join(ub, by = "unit")
  t |> mutate(E = exp(predict(fit, t)),
              H = (dm - rho * df) / (pi - rho * (1 - pi)),
              excess = d - E, nv_hat = excess - H,
              v_true = h - s * E, nv_true = (d - h) - (1 - s) * E,
              v_true2 = h - s / (1 - s) * (d - h), # without the expected deaths: violent deaths above the base share of the deaths observed
              pi_true = hm / (hm + hf),
              dlsr_nv = log((dm - hm) / (df - hf)) - lsr_nv)
}

res <- list()
for (k in seq_len(nrow(tests))) for (a in c("all", "15-44")) {
  key <- paste(tests$country[k], a); if (is.null(ds[[key]])) next
  dat <- ds[[key]]$md$md |> select(unit, unit_label, year, d, dm, df, h, hm, hf)
  r <- blind(dat, tests$base0[k]:tests$base1[k], country_name = tests$country[k])
  res[[key]] <- r |> mutate(country = tests$country[k], label = tests$label[k], ages = a, base = paste(tests$base0[k], tests$base1[k], sep = "-"))
}
res <- bind_rows(res)

nat <- res |> summarise(across(c(d, h, E, excess, H, v_true, v_true2, nv_hat, nv_true), sum),
                        pi_true = sum(hm) / sum(hm + hf), dlsr_nv = log(sum(dm - hm) / sum(df - hf)) - log(sum(exp(lsr_nv) * (df - hf)) / sum(df - hf)),
                        .by = c(country, label, ages, base, year))
write_csv(nat, "output/tables/intl_blind_test_spain_estimator.csv")

cat("== national, by year: estimated (H, non-violent) against the truth (violent above base, non-violent excess), thousands ==\n")
for (cc in unique(nat$country)) for (a in c("all", "15-44")) {
  z <- nat |> filter(country == cc, ages == a); if (!nrow(z)) next
  cat("\n--", cc, a, "| base", z$base[1], "\n")
  print(as.data.frame(z |> transmute(year, deaths = round(d / 1e3, 1), excess = round(excess / 1e3, 1),
                                     H = round(H / 1e3, 1), v_true = round(v_true / 1e3, 1), v_true2 = round(v_true2 / 1e3, 1),
                                     nv_hat = round(nv_hat / 1e3, 1), nv_true = round(nv_true / 1e3, 1),
                                     pi_true = round(pi_true, 3), nv_sexratio_change_pct = round(100 * (exp(dlsr_nv) - 1), 1))), row.names = FALSE)
}

# unit level: sums over test periods
per <- res |> mutate(period = case_when(
  country == "ecuador" & year %in% 2020:2021 ~ "2020-2021 (COVID-19)", country == "ecuador" & year >= 2022 ~ "2022-2024",
  country == "mexico" & year %in% 2008:2012 ~ "2008-2012", country == "mexico" & year %in% 2020:2021 ~ "2020-2021 (COVID-19)",
  country == "colombia" & year %in% 1985:1993 ~ "1985-1993", country == "colombia" & year %in% 1998:2002 ~ "1998-2002",
  country == "brazil" & year %in% 2010:2017 ~ "2010-2017", country == "us" & year %in% 2015:2019 ~ "2015-2019",
  .default = NA)) |> filter(!is.na(period))
up <- per |> summarise(across(c(d, h, E, excess, H, v_true, v_true2, nv_hat, nv_true), sum), .by = c(country, label, ages, period, unit, unit_label))
write_csv(up, "output/tables/intl_blind_test_spain_estimator_units.csv")
# unit-level measures first (summarise reuses names once they are summed)
sc <- up |> summarise(units = n(),
                      cor_units = round(cor(H, v_true2, use = "complete.obs"), 2),
                      mae_pct_of_truth = round(100 * median(abs(H - v_true2), na.rm = TRUE) / median(abs(v_true2), na.rm = TRUE)),
                      bias_pct = round(100 * (sum(H) - sum(v_true2)) / abs(sum(v_true2))),
                      H = sum(H), v_true = sum(v_true), v_true2 = sum(v_true2),
                      nv_hat = sum(nv_hat), nv_true = sum(nv_true), .by = c(country, ages, period))
write_csv(sc, "output/tables/intl_blind_test_spain_estimator_scores.csv")
cat("\n== by period, over units: H against violent deaths above the base share of the deaths observed (v_true2) ==\n")
print(as.data.frame(sc |> mutate(across(c(H, v_true, v_true2, nv_hat, nv_true), ~ round(.x / 1e3, 1)))), row.names = FALSE)

# figure: national, estimated against true, by year
fl <- nat |> select(label, ages, year, `violent: estimated` = H, `violent: true` = v_true2, `non-violent: estimated` = nv_hat, `non-violent: true` = nv_true) |>
  pivot_longer(-c(label, ages, year)) |>
  separate(name, c("part", "kind"), sep = ": ") |>
  # Colombia: registration grew fast in 1979-1983, so the expected deaths (and
  # the non-violent part) cannot be judged there; only the violent part is drawn
  filter(!(label == "Colombia" & part == "non-violent")) |>
  mutate(label = factor(label, tests$label), ages = factor(ifelse(ages == "all", "all ages", "ages 15-44"), c("all ages", "ages 15-44")))
fig <- ggplot(fl, aes(year, value / 1000, colour = part, linetype = kind)) +
  geom_hline(yintercept = 0, colour = "grey60", linewidth = 0.3) +
  geom_line(linewidth = 0.6) +
  scale_colour_manual(values = c(violent = "#2a78d6", `non-violent` = "#f2a541"), name = NULL) +
  scale_linetype_manual(values = c(estimated = "solid", true = "22"), name = NULL) +
  facet_grid(ages ~ label, scales = "free") +
  labs(title = "Blind test of the Spain estimator: deaths above the base years, estimated from deaths by sex only, against the causes",
       subtitle = paste0("Violent: male deaths above the base-year sex ratio (95 % of victims men), against violent deaths above the base-year share. ",
                         "Non-violent: excess deaths minus the violent part.\nBase years: Ecuador 2015-2019, Mexico 2000-2006, Colombia 1979-1983 (violent part only: registration grew fast in the base), Brazil 1996-2000, United States 1999-2004."),
       x = NULL, y = "thousand deaths") +
  theme_minimal(base_size = 9) +
  theme(legend.position = "bottom", panel.grid.minor = element_blank(), plot.title = element_text(face = "bold"), strip.text = element_text(face = "bold"))
ggsave("figures/09_international/intl_blind_test_spain_estimator.png", fig, w = 14, h = 6.5, bg = "white", dpi = 160)
