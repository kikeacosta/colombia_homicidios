# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 45. Arbitrating between UN IGME / WPP 2024 and NRC 1982 with the Brass
#     estimates of the 1973 census
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# The NRC 1982 life tables (44) give three to four years less life
# expectancy at birth than WPP 2024 and than our adjusted series in
# 1950-1975. Here the gap is split into what comes from mortality under five
# and what comes from ages 5+, and the under-five part is arbitrated with an
# estimate that is independent of all three: the Brass-Trussell q(5) from the
# children ever born and surviving of the 1973 census (43), dated 1959-1972.
#
# 1. q(5), both sexes, at the Brass reference dates: the Brass estimate of
#    each Coale-Demeny family (zone total, El-Badry parities) against our
#    series (UN IGME under five, 41), WPP 2024, the registered deaths and
#    NRC 1982 (interpolated between its five-year tables)
# 2. decomposition of e0(NRC) - e0(ours) at 1950, 1955, ..., 1975 by sex into
#    an under-five part (NRC's l(1), l(5) with our survival above five) and a
#    5+ part (the rest). All life tables are rebuilt from l(x) at 0, 1, 5,
#    10, ..., 80 and e(80) with the same abridged formulas (a0 Coale-Demeny,
#    4a1 = 1.5, 5ax = 2.5), so that the three sources are treated alike;
#    the rebuilt e0 is checked against each source's own e0
#
# inputs: output/tables/child_mortality_brass_census1973.csv (43)
#         output/tables/mortality_adjusted_components_1950-2023.csv (42)
#         output/tables/mortality_adjusted_summary.csv (42)
#         data_input/reference/nrc1982_colombia_lifetables.csv (44)
# output: output/tables/brass1973_arbitration_q5.csv
#         output/tables/brass1973_e0_gap_decomposition.csv
#         figures/06_components/brass1973_arbitration.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
suppressMessages({library(dplyr); library(tidyr); library(readr); library(ggplot2); library(purrr)})
srb <- 1.05                      # weight of the sexes in the both-sex q(5)
w_m <- srb / (1 + srb)

# ---- life tables from abridged mx (ours, WPP, registered) -------------------
comp <- read_csv("output/tables/mortality_adjusted_components_1950-2023.csv", show_col_types = FALSE) |>
  filter(year <= 1980) |>
  select(year, sex, age, ours = mx_total, wpp = mx_wpp, registered = mx_registered) |>
  pivot_longer(c(ours, wpp, registered), names_to = "series", values_to = "mx")
a0_cd <- function(m0, sex) {          # Coale-Demeny a0 as a function of m0 (Preston et al. 2001, table 3.3)
  if_else(sex == "m", if_else(m0 >= 0.107, 0.330, 0.045 + 2.684 * m0), if_else(m0 >= 0.107, 0.350, 0.053 + 2.800 * m0))
}
lt_from_mx <- function(d, sex) {      # d: one year, sex, series; ages 0, 1, 5, ..., 80
  d <- arrange(d, age)
  n <- c(1, 4, rep(5, 15), Inf)
  ax <- c(a0_cd(d$mx[1], sex), 1.5, rep(2.5, 15), NA)
  qx <- n * d$mx / (1 + (n - ax) * d$mx); qx[18] <- 1
  lx <- cumprod(c(1, 1 - qx[-18]))
  tibble(age = d$age, lx = lx, e80 = 1 / d$mx[18])
}
lt <- comp |> group_by(year, sex, series) |> group_modify(~ lt_from_mx(.x, .y$sex)) |> ungroup()

# ---- NRC 1982 l(x) ----------------------------------------------------------
nrc <- read_csv("data_input/reference/nrc1982_colombia_lifetables.csv", show_col_types = FALSE) |>
  filter(age %in% c(0, 1, seq(5, 80, 5))) |>
  group_by(year, sex) |> mutate(e80 = ex[age == 80], e0_printed = ex[age == 0]) |> ungroup() |>
  transmute(year, sex, series = "nrc", age, lx, e80, e0_printed)

# ---- abridged e0, e5 from l(x) at 0, 1, 5, ..., 80 and e(80) ---------------
ex_from_lx <- function(lx, e80, sex) {   # lx: 18 values (ages 0, 1, 5, ..., 80)
  q0 <- 1 - lx[2] / lx[1]; m0 <- q0 / (1 - (1 - 0.33) * q0)   # a0 only needs an approximate m0
  a0 <- a0_cd(m0, sex)
  L <- c(a0 * lx[1] + (1 - a0) * lx[2],                  # 1L0
         4 * lx[3] + 1.5 * (lx[2] - lx[3]),             # 4L1
         2.5 * (lx[3:17] + lx[4:18]),                    # 5Lx, 5-79
         lx[18] * e80)                                   # T80
  c(e0 = sum(L) / lx[1], e5 = sum(L[-(1:2)]) / lx[3], under5 = sum(L[1:2]))
}
all_lt <- bind_rows(lt, select(nrc, -e0_printed))
ind <- all_lt |> group_by(year, sex, series) |>
  summarise(as_tibble(as.list(ex_from_lx(lx, e80[1], sex[1]))), l1 = lx[age == 1], l5 = lx[age == 5], .groups = "drop") |>
  mutate(q5 = 1 - l5)

# check: the rebuilt e0 against each source's own e0
own <- bind_rows(
  read_csv("output/tables/mortality_adjusted_summary.csv", show_col_types = FALSE) |>
    filter(series %in% c("Ajustada por componentes", "WPP 2024", "Registradas")) |>
    transmute(year, sex, series = c(`Ajustada por componentes` = "ours", `WPP 2024` = "wpp", Registradas = "registered")[series], e0_own = e0),
  nrc |> distinct(year, sex, series, e0_own = e0_printed))
chk <- ind |> inner_join(own, by = c("year", "sex", "series")) |> mutate(d = e0 - e0_own) |> filter(year <= 1978)
cat("rebuilt e0 against the source's own e0 (years): mean and largest absolute difference by series\n")
print(chk |> summarise(mean = round(mean(d), 2), max_abs = round(max(abs(d)), 2), .by = series) |> as.data.frame())

# ---- 1. q(5) both sexes at the Brass reference dates ------------------------
q5_bs <- ind |> select(year, sex, series, q5) |>
  pivot_wider(names_from = sex, values_from = q5) |>
  mutate(q5 = w_m * m + (1 - w_m) * f) |> select(series, year, q5)
interp <- function(s, at) {            # linear interpolation of a series at fractional dates
  d <- q5_bs |> filter(series == s) |> arrange(year)
  approx(d$year, d$q5, xout = at, rule = 2)$y
}
brass <- read_csv("output/tables/child_mortality_brass_census1973.csv", show_col_types = FALSE) |>
  filter(zone == "total", parity_variant == "El-Badry") |>
  transmute(family = model, age_group = age, ref_date, q5_brass = q5, use)
arb <- brass |>
  mutate(q5_ours_igme = interp("ours", ref_date), q5_wpp = interp("wpp", ref_date),
         q5_registered = interp("registered", ref_date), q5_nrc1982 = interp("nrc", ref_date),
         ratio_brass_igme = q5_brass / q5_ours_igme, ratio_brass_nrc = q5_brass / q5_nrc1982) |>
  arrange(family, desc(ref_date))
write_csv(arb, "output/tables/brass1973_arbitration_q5.csv")
cat("\nq(5) both sexes at the Brass reference dates (per mil), zone total, El-Badry parities\n")
print(arb |> filter(use != "no") |>
        transmute(family, age_group, date = round(ref_date, 1), brass = round(1000 * q5_brass), igme = round(1000 * q5_ours_igme),
                  wpp = round(1000 * q5_wpp), reg = round(1000 * q5_registered), nrc = round(1000 * q5_nrc1982),
                  brass_igme = round(ratio_brass_igme, 3), brass_nrc = round(ratio_brass_nrc, 3)) |> as.data.frame())
summ_arb <- arb |> filter(use == "yes") |>
  summarise(n = n(), brass_over_igme = mean(ratio_brass_igme), brass_over_nrc = mean(ratio_brass_nrc),
            lo_igme = min(ratio_brass_igme), hi_igme = max(ratio_brass_igme), lo_nrc = min(ratio_brass_nrc), hi_nrc = max(ratio_brass_nrc))
cat(sprintf("\nover the %d usable Brass points (mothers 25-49, dated 1959-1970, four families): Brass / IGME = %.3f (%.3f-%.3f); Brass / NRC 1982 = %.3f (%.3f-%.3f)\n",
            summ_arb$n, summ_arb$brass_over_igme, summ_arb$lo_igme, summ_arb$hi_igme, summ_arb$brass_over_nrc, summ_arb$lo_nrc, summ_arb$hi_nrc))

# ---- 2. decomposition of e0(NRC) - e0(ours) ---------------------------------
dec <- all_lt |> filter(series %in% c("ours", "nrc"), year %in% seq(1950, 1975, 5)) |>
  group_by(year, sex) |>
  group_modify(function(d, k) {
    o <- d |> filter(series == "ours") |> arrange(age); n <- d |> filter(series == "nrc") |> arrange(age)
    eo <- ex_from_lx(o$lx, o$e80[1], k$sex); en <- ex_from_lx(n$lx, n$e80[1], k$sex)
    # mixed table: NRC survival to 1 and 5, our survival above 5 (scaled to NRC's l5)
    mixed <- c(n$lx[1:2], n$lx[3] * o$lx[3:18] / o$lx[3])
    em <- ex_from_lx(mixed, o$e80[1], k$sex)
    tibble(e0_ours = eo[["e0"]], e0_nrc = en[["e0"]], gap = en[["e0"]] - eo[["e0"]],
           under_five = em[["e0"]] - eo[["e0"]], five_plus = en[["e0"]] - em[["e0"]],
           e5_ours = eo[["e5"]], e5_nrc = en[["e5"]], q5_ours = 1 - o$lx[3], q5_nrc = 1 - n$lx[3])
  }) |> ungroup()
write_csv(dec, "output/tables/brass1973_e0_gap_decomposition.csv")
cat("\ne0 NRC 1982 - ours (years) split into under five and 5+; e5 of both\n")
print(dec |> mutate(across(where(is.numeric) & !year, ~ round(., 2))) |> as.data.frame())

# ---- figure -----------------------------------------------------------------
lab_series <- c(ours = "Propia (UN IGME en menores de cinco)", wpp = "WPP 2024", nrc = "NRC 1982", registered = "Registradas")
cols <- c(`Propia (UN IGME en menores de cinco)` = "#1f5fa6", `WPP 2024` = "#7a7a7a", `NRC 1982` = "#d6641a", Registradas = "#9bbfdf")
p1 <- ggplot() +
  geom_line(data = q5_bs |> filter(year <= 1978) |> mutate(series = factor(lab_series[series], lab_series)),
            aes(year, 1000 * q5, colour = series, linetype = series), linewidth = 0.8) +
  geom_point(data = arb |> filter(use != "no") |> mutate(family = paste("Brass 1973,", family), usable = use == "yes"),
             aes(ref_date, 1000 * q5_brass, shape = family, fill = usable), size = 2.6, colour = "black", stroke = 0.6) +
  scale_colour_manual(values = cols, name = NULL) +
  scale_linetype_manual(values = c(1, 1, 1, 3), name = NULL) +
  scale_shape_manual(values = c(21, 22, 24, 23), name = NULL) +
  scale_fill_manual(values = c(`TRUE` = "black", `FALSE` = "white"), guide = "none") +
  scale_x_continuous(breaks = seq(1950, 1978, 4)) +
  labs(x = NULL, y = "5q0, ambos sexos (por mil)",
       title = "Mortalidad de menores de cinco años: Brass del censo 1973 frente a las series",
       subtitle = "Puntos: Brass-Trussell por familia Coale-Demeny en su fecha de referencia; huecos: madres de 20-24 (con cautela)") +
  theme_minimal(base_size = 11) + theme(legend.position = "bottom", legend.box = "vertical", panel.grid.minor = element_blank())
p2 <- dec |> select(year, sex, `Menores de cinco` = under_five, `Cinco y más` = five_plus) |>
  pivot_longer(-c(year, sex), names_to = "part", values_to = "years") |>
  mutate(sex = c(m = "Hombres", f = "Mujeres")[sex], part = factor(part, c("Menores de cinco", "Cinco y más"))) |>
  ggplot(aes(year, years, fill = part)) +
  geom_col(width = 3.2, colour = "white", linewidth = 0.4) +
  geom_text(data = dec |> mutate(sex = c(m = "Hombres", f = "Mujeres")[sex]), aes(year, gap, label = sprintf("%.1f", gap)), inherit.aes = FALSE, vjust = 1.4, size = 3.2, colour = "white") +
  facet_wrap(~ sex) +
  scale_fill_manual(values = c(`Menores de cinco` = "#d6641a", `Cinco y más` = "#7a7a7a"), name = NULL) +
  scale_x_continuous(breaks = seq(1950, 1975, 5)) +
  labs(x = NULL, y = "e0 NRC 1982 menos e0 propia (años)",
       title = "De dónde viene la brecha de esperanza de vida con NRC 1982") +
  theme_minimal(base_size = 11) + theme(legend.position = "bottom", panel.grid.minor = element_blank())
g <- patchwork::wrap_plots(p1, p2, ncol = 1, heights = c(1.3, 1))
ggsave("figures/06_components/brass1973_arbitration.png", g, width = 9, height = 10, bg = "white", dpi = 150)
cat("\nwritten: output/tables/brass1973_arbitration_q5.csv, brass1973_e0_gap_decomposition.csv, figures/06_components/brass1973_arbitration.png\n")
