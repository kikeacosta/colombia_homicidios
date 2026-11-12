# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 42. Adjusted mortality by component, sex and age, 1950-2023
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# The registered deaths are adjusted component by component (40) and then
# added up, instead of adjusting total mortality in one go:
#
#   under five      all causes from UN IGME (41): m0 and 4m1
#   natural, 5-64   registered natural deaths / completeness (see below),
#                   then smoothed over age and time with a tensor P-spline
#                   (quasi-Poisson GAM by sex, 1950-2019), which irons out
#                   the registration dips of 1969-1971 and 1978-1979 and the
#                   age errors of 1991. 2020-2023 keep the corrected annual
#                   rates: COVID-19 is real mortality, not noise
#   natural, 65+    a relational model instead of the rates by age. In the
#                   early decades the registered rates are too low at 65-79
#                   and far too high at 80+ (deaths reported at older ages
#                   than they occurred), and a curve extrapolated from 50-79
#                   undershoots at 80+. The age pattern is that of a standard
#                   (WPP 2024 for Colombia, mean of 2010-2019, single ages
#                   65-100+) shifted on the logit scale, and the shift of
#                   each year and sex is the one that reproduces the total
#                   of corrected natural deaths at 65+ on the WPP population
#                   by single age: the level comes from our deaths, the
#                   shape from the standard, and transfers of deaths between
#                   ages above 65 do not matter. The annual shift is smoothed
#                   over time (P-spline, 1950-2019)
#   bad years       1969-1971 and 1978-1979, when registration broke down,
#                   are left out of both smooths and take the fitted values
#   other external  registered / the same completeness (ASSUMPTION: accidents
#                   and suicide are missed like natural deaths; there is no
#                   separate evidence)
#   violent         registered (homicide, undetermined intent, legal
#                   intervention) + conflict deaths missing from the registry
#                   in 1985-2018 (MSE homicides not registered as violent +
#                   enforced disappearances, 27). No completeness factor:
#                   violent deaths are certified by legal medicine and the
#                   natural-death factor does not apply to them
#
# completeness of the natural and other external deaths at ages 5+
#   1970-2023   empirical method (Adair-Lopez model 1 on non-violent deaths,
#               36), annual
#   1950-1969   the empirical method is out of its calibration period there
#               and gives about 0.98, against every other source. The
#               completeness is anchored instead at 1951 and 1964 on two
#               independent estimates of adult completeness and interpolated
#               on the logit scale between 1951, 1964 and the empirical value
#               of 1970 (1950 takes the value of 1951):
#                 NRC 1982    National Research Council (1982, Table 50,
#                             p. 102): mean of the Preston-Coale estimate on
#                             age-redistributed deaths and the projection
#                             estimate, both sets of growth rates. Men 0.774
#                             (1951) and 0.817 (1964); women 0.727 and 0.800
#                 WPP 2024    registered / WPP deaths at ages 15+, mean of
#                             1950-1952 and of 1963-1965
#               The two agree for 1951 and disagree for 1964 (about 0.81
#               against 0.94), so three variants are carried:
#                 central           mean of the two sources at each anchor
#                 anclas NRC 1982   NRC 1982 anchors
#                 anclas WPP 2024   WPP 2024 anchors
#
# Rates use the WPP 2024 population as denominator (the reconstruction of 39
# recomputes them on its own exposures). The main output is the central
# variant; the other two are in the variants files.
#
# output: output/tables/mortality_adjusted_components_1950-2023.csv
#         output/tables/mortality_adjusted_old_age_model.csv
#         output/tables/mortality_adjusted_summary.csv
#         output/tables/mortality_adjusted_completeness_variants.csv
#         output/tables/mortality_adjusted_variants_summary.csv
#         figures/06_components/natural_mortality_model.png
#         figures/06_components/old_age_model.png
#         figures/06_components/adjusted_vs_wpp.png
#         figures/06_components/adjusted_variants.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
source("code/00_setup.R")

years <- 1950:2023
std_years <- 2010:2019   # WPP years that give the standard old-age pattern
last_smooth <- 2019
bad_years <- c(1969:1971, 1978:1979)   # registration breakdowns, left out of the smooths
grp_lo <- c(0, 1, seq(5, 80, 5))
age_mid <- \(a) case_when(a == 0 ~ 0.5, a == 1 ~ 3, TRUE ~ a + 2.5)
lab_sex <- \(s) factor(s, c("m", "f"), c("Hombres", "Mujeres"))

comp <- read_csv("output/tables/deaths_components_registered_1950-2023.csv", show_col_types = FALSE)
exp <- read_csv("output/tables/deaths_expected_wpp_mse_1950-2023.csv", show_col_types = FALSE)
c_al <- read_csv("output/tables/completeness_compared_annual.csv", show_col_types = FALSE) |>
  filter(method == "Adair-Lopez, modelo 1") |> select(year, sex, c_al = completeness)
child <- read_csv("output/tables/igme_child_mortality_1950-2023.csv", show_col_types = FALSE)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# completeness variants ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
nrc <- tribble(~sex, ~year, ~nrc,
               "m", 1951, mean(c(.755, .768, .786, .788)), "m", 1964, mean(c(.819, .800, .831, .818)),
               "f", 1951, mean(c(.700, .712, .747, .748)), "f", 1964, mean(c(.794, .776, .830, .801)))
wpp_anchor <- exp |> filter(age >= 15, year %in% c(1950:1952, 1963:1965)) |>
  mutate(year = if_else(year <= 1952, 1951, 1964)) |>
  summarise(wpp = sum(registered) / sum(wpp_total), .by = c(sex, year))
anchors <- nrc |> left_join(wpp_anchor, by = c("sex", "year")) |>
  transmute(sex, year, central = (nrc + wpp) / 2, `anclas NRC 1982` = nrc, `anclas WPP 2024` = wpp)
variants <- c("central", "anclas NRC 1982", "anclas WPP 2024")
cat("anchors of the completeness of deaths at ages 5+ (natural and other external):\n")
print(anchors |> mutate(across(all_of(variants), ~ round(.x, 3))) |> arrange(sex, year) |> as.data.frame())

completeness <-
  expand_grid(variant = variants, c_al) |>
  group_by(variant, sex) |>
  group_modify(\(d, k) {
    a <- anchors |> filter(sex == k$sex) |> arrange(year)
    xs <- c(a$year, 1970); ys <- qlogis(c(a[[k$variant]], d$c_al[d$year == 1970]))
    d |> mutate(c = if_else(year < 1970, plogis(approx(xs, ys, xout = year, rule = 2)$y), c_al))
  }) |>
  ungroup() |>
  mutate(variant = factor(variant, variants))
write_csv(completeness |> select(variant, year, sex, completeness = c, empirical = c_al), "output/tables/mortality_adjusted_completeness_variants.csv")

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# the adjustment, for one completeness series ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
pop1 <- read_csv("data_input/reference/wpp2024_colombia_pop_single_age_1950-2023.csv", show_col_types = FALSE) |>
  filter(AgeGrpStart >= 65) |>
  transmute(year = Time, age = AgeGrpStart, m = PopMale * 1000, f = PopFemale * 1000) |>
  pivot_longer(c(m, f), names_to = "sex", values_to = "pop")
std <- read_csv("data_input/reference/wpp2024_colombia_lt_complete_1950-2100.csv", show_col_types = FALSE) |>
  filter(Time %in% std_years, Sex != "Total", AgeGrpStart >= 65) |>
  summarise(y_s = qlogis(mean(mx)), .by = c(Sex, AgeGrpStart)) |>
  transmute(sex = unname(c(Female = "f", Male = "m")[Sex]), age = AgeGrpStart, y_s)

build <- function(cc, verbose = FALSE) {
  d <- comp |>
    left_join(exp |> select(year, sex, age, wpp_total, expected, hom_excess, dsp), by = c("year", "sex", "age")) |>
    left_join(cc, by = c("year", "sex")) |>
    mutate(nat_c = natural / c, oext_c = other_external / c, viol_adj = violent + hom_excess + dsp, x = age_mid(age))

  # natural mortality at 5-79: smooth surface (used below 65)
  nat <- map_dfr(c("m", "f"), \(s) {
    dd <- d |> filter(sex == s, age >= 5, age < 80)
    m <- gam(nat_c ~ te(x, year, k = c(10, 16), bs = "ps") + offset(log(pop)), family = quasipoisson(),
             data = dd |> filter(year <= last_smooth, !year %in% bad_years), method = "REML")
    if (verbose) cat(sprintf("natural mortality surface, %s: deviance explained %.4f, dispersion %.1f\n", s, summary(m)$dev.expl, summary(m)$dispersion))
    dd |> mutate(mx_nat_obs = nat_c / pop,
                 mx_nat = if_else(year <= last_smooth, as.numeric(predict(m, newdata = mutate(dd, year = pmin(year, last_smooth)), type = "response")) / pop, mx_nat_obs))
  }) |> select(year, sex, age, mx_nat_obs, mx_nat)

  # natural mortality at 65+: logit m(x, t) = alpha(t) + logit m_s(x); alpha
  # is the root of sum_x m(x, t) P(x, t) = corrected natural deaths at 65+
  d65 <- d |> filter(age >= 65) |> summarise(deaths = sum(nat_c), .by = c(year, sex))
  old1 <- pop1 |> left_join(std, by = c("sex", "age")) |> left_join(d65, by = c("year", "sex")) |>
    mutate(alpha_obs = uniroot(\(a) sum(plogis(a + y_s) * pop) - deaths[1], c(-6, 6), tol = 1e-10)$root, .by = c(year, sex))
  # the annual shift is smoothed over time like the rates below 65, leaving the bad years out of the fit
  al <- old1 |> distinct(year, sex, alpha_obs) |>
    mutate(alpha = { ok <- year <= last_smooth & !year %in% bad_years
                     f <- gam(alpha_obs ~ s(year, k = 14, bs = "ps"), data = tibble(alpha_obs = alpha_obs[ok], year = year[ok]), method = "REML")
                     if_else(year <= last_smooth, as.numeric(predict(f, newdata = tibble(year = year))), alpha_obs) }, .by = sex)
  old1 <- old1 |> left_join(al |> select(year, sex, alpha), by = c("year", "sex")) |> mutate(mx = plogis(alpha + y_s))
  old <- old1 |> mutate(age = pmin(5 * (age %/% 5), 80)) |> summarise(mx_nat_old = sum(mx * pop) / sum(pop), .by = c(year, sex, age))

  adj <- d |>
    left_join(nat, by = c("year", "sex", "age")) |>
    left_join(old, by = c("year", "sex", "age")) |>
    left_join(child |> select(year, sex, m0, m1_4), by = c("year", "sex")) |>
    mutate(mx_other_external = oext_c / pop, mx_violent = viol_adj / pop,
           mx_natural = case_when(age == 0 ~ pmax(m0 - mx_other_external - mx_violent, 0), age == 1 ~ pmax(m1_4 - mx_other_external - mx_violent, 0),
                                  age >= 65 ~ mx_nat_old, TRUE ~ mx_nat),
           # under five the total is IGME's; the external rates are capped by it
           mx_total = case_when(age == 0 ~ m0, age == 1 ~ m1_4, TRUE ~ mx_natural + mx_other_external + mx_violent),
           mx_registered = registered / pop, mx_wpp = wpp_total / pop, mx_wpp_mse = expected / pop,
           method_natural = case_when(age < 5 ~ "UN IGME (todas las causas)", age >= 65 ~ "modelo relacional 65+",
                                      year <= last_smooth ~ "corregida y suavizada", TRUE ~ "corregida, anual"),
           method_completeness = if_else(year < 1970, "anclada (NRC 1982 y WPP 2024)", "empírica (Adair-Lopez)")) |>
    select(year, sex, age, pop, mx_natural, mx_other_external, mx_violent, mx_total, mx_registered, mx_wpp, mx_wpp_mse,
           completeness_natural = c, method_natural, method_completeness)
  stopifnot(!anyNA(adj$mx_total), all(adj$mx_total > 0))
  list(adj = adj, nat = nat, old1 = old1, d = d)
}

# life tables (abridged, as in 28)
lifetable <- function(age, mx, sex) {
  n <- c(diff(age), Inf)
  m0 <- mx[1]
  a0 <- if (sex == "m") { if (m0 < 0.023) 0.14929 - 1.99545 * m0 else if (m0 < 0.08307) 0.02832 + 3.26201 * m0 else 0.29915 } else
                        { if (m0 < 0.01724) 0.14903 - 2.05527 * m0 else if (m0 < 0.06891) 0.04667 + 3.88089 * m0 else 0.31411 }
  a1 <- if (sex == "m") { if (m0 < 0.023) 1.6534 else if (m0 < 0.08307) 1.5806 else 1.3607 } else
                        { if (m0 < 0.01724) 1.6338 else if (m0 < 0.06891) 1.5265 else 1.3062 }
  ax <- c(a0, a1, rep(2.5, length(age) - 3), 1 / mx[length(age)])
  qx <- n * mx / (1 + (n - ax) * mx); qx[length(age)] <- 1
  lx <- c(1, cumprod(1 - qx))[seq_along(age)]
  dx <- lx * qx
  Lx <- n * (lx - dx) + ax * dx; Lx[length(age)] <- lx[length(age)] / mx[length(age)]
  Tx <- rev(cumsum(rev(Lx)))
  tibble(age, lx, ex = Tx / lx)
}
indicators <- function(x) {   # x: grouped by series or variant, year and sex; columns age, mx
  gv <- group_vars(x)
  x |> reframe(lifetable(age, mx, first(sex))) |>
    summarise(e0 = ex[age == 0], q5 = 1 - lx[age == 5], q45_15 = 1 - lx[age == 60] / lx[age == 15], q20_60 = 1 - lx[age == 80] / lx[age == 60],
              e60 = ex[age == 60], e80 = ex[age == 80], .by = all_of(gv))
}

res <- map(set_names(variants), \(v) build(completeness |> filter(variant == v) |> select(year, sex, c), verbose = v == "central"))
central <- res$central
adj <- central$adj; nat <- central$nat; d <- central$d
write_csv(adj, "output/tables/mortality_adjusted_components_1950-2023.csv")
write_csv(central$old1 |> select(year, sex, age, pop, alpha, mx_natural = mx), "output/tables/mortality_adjusted_old_age_model.csv")

series <- c("Ajustada por componentes" = "mx_total", "WPP 2024" = "mx_wpp", "WPP + MSE" = "mx_wpp_mse", "Registradas" = "mx_registered")
summ <- adj |>
  pivot_longer(all_of(unname(series)), names_to = "v", values_to = "mx") |>
  mutate(series = factor(names(series)[match(v, series)], names(series))) |>
  arrange(series, year, sex, age) |> group_by(series, year, sex) |> indicators()
write_csv(summ, "output/tables/mortality_adjusted_summary.csv")

vsumm <- imap_dfr(res, \(r, v) r$adj |> transmute(variant = v, year, sex, age, mx = mx_total)) |>
  mutate(variant = factor(variant, variants)) |>
  arrange(variant, year, sex, age) |> group_by(variant, year, sex) |> indicators()
write_csv(vsumm, "output/tables/mortality_adjusted_variants_summary.csv")

cat("\ncompleteness applied at ages 5+, by variant:\n")
print(completeness |> filter(year %in% c(1950, 1955, 1960, 1965, 1969, 1970, 1975)) |>
        transmute(variant, sex, year, c = round(c, 3)) |> pivot_wider(names_from = year, values_from = c) |> arrange(sex, variant) |> as.data.frame())
cat("\ne0 and 45q15 (per 1,000) by variant, against WPP 2024:\n")
print(vsumm |> filter(year %in% c(1950, 1955, 1960, 1965, 1969)) |>
        left_join(summ |> filter(series == "WPP 2024") |> select(year, sex, e0_wpp = e0, q_wpp = q45_15), by = c("year", "sex")) |>
        transmute(sex, year, variant, e0 = round(e0, 1), q45_15 = round(1000 * q45_15), e0_wpp = round(e0_wpp, 1), q_wpp = round(1000 * q_wpp)) |>
        pivot_wider(names_from = variant, values_from = c(e0, q45_15)) |> arrange(sex, year) |> as.data.frame())
cat("\ncentral variant against WPP 2024, selected years:\n")
print(summ |> filter(series %in% c("Ajustada por componentes", "WPP 2024"), year %in% c(1950, 1960, 1970, 1980, 1990, 2000, 2010, 2018)) |>
        select(series, year, sex, e0, q45_15, e60) |> pivot_wider(names_from = series, values_from = c(e0, q45_15, e60)) |>
        transmute(sex, year, e0 = round(`e0_Ajustada por componentes`, 1), e0_wpp = round(`e0_WPP 2024`, 1), d_e0 = round(e0 - e0_wpp, 1),
                  r_45q15 = round(`q45_15_Ajustada por componentes` / `q45_15_WPP 2024`, 2),
                  e60 = round(`e60_Ajustada por componentes`, 1), e60_wpp = round(`e60_WPP 2024`, 1)) |> arrange(sex, year) |> as.data.frame())
cat("\ndeaths by component, thousands (WPP population), central variant:\n")
print(adj |> filter(year %in% c(1950, 1960, 1980, 1990, 2000, 2010, 2018, 2021)) |>
        summarise(natural = round(sum(mx_natural * pop) / 1e3, 1), otras_externas = round(sum(mx_other_external * pop) / 1e3, 1), violenta = round(sum(mx_violent * pop) / 1e3, 1),
                  total = round(sum(mx_total * pop) / 1e3, 1), registradas = round(sum(mx_registered * pop) / 1e3, 1), wpp = round(sum(mx_wpp * pop) / 1e3, 1), .by = year) |> as.data.frame())

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# figures ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ink <- "#52514e"
base <- theme_bw(base_size = 11) +
  theme(panel.grid.minor = element_blank(), panel.grid.major = element_line(colour = "grey92"),
        legend.position = "bottom", strip.background = element_rect(fill = "grey96", colour = NA),
        plot.title = element_text(size = 12, face = "bold"), plot.subtitle = element_text(size = 9.5, colour = ink))
age_lab <- \(a) factor(a, grp_lo, c("0", "1-4", paste0(seq(5, 75, 5), "-", seq(9, 79, 5)), "80+"))

# natural mortality: corrected annual rates and smooth surface, selected ages
nat |>
  filter(age %in% c(5, 15, 30, 45, 60)) |>
  left_join(d |> transmute(year, sex, age, reg = natural / pop), by = c("year", "sex", "age")) |>
  mutate(sex = lab_sex(sex), age = age_lab(age)) |>
  ggplot(aes(year)) +
  geom_line(aes(y = 1e5 * reg, col = "Registrada"), linewidth = 0.4) +
  geom_line(aes(y = 1e5 * mx_nat_obs, col = "Corregida por completitud"), linewidth = 0.4) +
  geom_line(aes(y = 1e5 * mx_nat, col = "Corregida y suavizada"), linewidth = 0.9) +
  facet_grid(sex ~ age) +
  scale_y_log10() +
  scale_color_manual(values = c("Registrada" = "#8a8983", "Corregida por completitud" = "#eb6834", "Corregida y suavizada" = "#2a78d6")) +
  scale_x_continuous(breaks = seq(1960, 2020, 20)) +
  labs(title = "Mortalidad natural por edad: registrada, corregida por completitud y suavizada (por 100.000, escala log), variante central",
       subtitle = "La superficie suavizada cubre 1950-2019; 2020-2023 conserva las tasas corregidas anuales (COVID-19)",
       x = NULL, y = "Tasa por 100.000", col = NULL) +
  base
ggsave("figures/06_components/natural_mortality_model.png", w = 15, h = 7, bg = "white")

# old ages
p80 <- adj |> filter(age == 80) |>
  transmute(year, sex = lab_sex(sex), `Modelo relacional 65+ (natural)` = mx_natural, `Registrada (todas las causas)` = mx_registered, `WPP 2024 (todas las causas)` = mx_wpp) |>
  pivot_longer(-c(year, sex), names_to = "series", values_to = "mx") |>
  ggplot(aes(year, 1000 * mx, col = series)) +
  geom_line(linewidth = 0.8) +
  facet_wrap(~sex) +
  scale_color_manual(values = c("Modelo relacional 65+ (natural)" = "#2a78d6", "Registrada (todas las causas)" = "#8a8983", "WPP 2024 (todas las causas)" = "#0b0b0b")) +
  scale_x_continuous(breaks = seq(1950, 2020, 10)) +
  labs(title = "a. Tasa de mortalidad del grupo abierto 80+ (por 1.000)", x = NULL, y = "Por 1.000", col = NULL) +
  base
pe <- summ |> filter(series != "WPP + MSE") |> mutate(sex = lab_sex(sex)) |>
  ggplot(aes(year, e60, col = series)) +
  geom_line(linewidth = 0.8) +
  facet_wrap(~sex) +
  scale_color_manual(values = c("Ajustada por componentes" = "#2a78d6", "WPP 2024" = "#0b0b0b", "Registradas" = "#8a8983")) +
  scale_x_continuous(breaks = seq(1950, 2020, 10)) +
  labs(title = "b. Esperanza de vida a los 60 años", x = NULL, y = "e60 (años)", col = NULL) +
  base
ggsave("figures/06_components/old_age_model.png", ggpubr::ggarrange(p80, pe, ncol = 1), w = 12, h = 10, bg = "white")

# adjusted series (central) against WPP
s_cols <- c("Ajustada por componentes" = "#2a78d6", "WPP 2024" = "#0b0b0b", "WPP + MSE" = "#eb6834", "Registradas" = "#8a8983")
pa <- summ |> mutate(sex = lab_sex(sex)) |>
  ggplot(aes(year, e0, col = series)) + geom_line(linewidth = 0.8) + facet_wrap(~sex) +
  scale_color_manual(values = s_cols) + scale_x_continuous(breaks = seq(1950, 2020, 10)) +
  labs(title = "a. Esperanza de vida al nacer", x = NULL, y = "e0 (años)", col = NULL) + base
pb <- summ |> mutate(sex = lab_sex(sex)) |>
  ggplot(aes(year, q45_15, col = series)) + geom_line(linewidth = 0.8) + facet_wrap(~sex) +
  scale_color_manual(values = s_cols) + scale_x_continuous(breaks = seq(1950, 2020, 10)) +
  labs(title = "b. Probabilidad de morir entre los 15 y los 60 años (45q15)", x = NULL, y = "45q15", col = NULL) + base
pc <- adj |>
  mutate(pct = 100 * (mx_total / mx_wpp - 1), sex = lab_sex(sex), age = age_lab(age)) |>
  ggplot(aes(year, age, fill = pct)) + geom_tile() + facet_wrap(~sex) +
  scale_fill_gradient2(low = "#2a78d6", mid = "#f0efec", high = "#eb6834", midpoint = 0, limits = c(-40, 40), oob = scales::squish,
                       labels = \(x) paste0(ifelse(x > 0, "+", ""), x, " %")) +
  scale_x_continuous(breaks = seq(1950, 2020, 10), expand = c(0, 0)) + scale_y_discrete(expand = c(0, 0)) +
  labs(title = "c. Tasas ajustadas por componentes (variante central) frente a WPP 2024, por edad", subtitle = "Naranja: mayor que WPP; azul: menor (escala cortada en ±40 %)",
       x = NULL, y = "Edad", fill = NULL) +
  base + theme(legend.key.width = unit(1.6, "cm"), panel.grid = element_blank())
top <- ggpubr::ggarrange(pa, pb, ncol = 2, common.legend = TRUE, legend = "bottom")
ggsave("figures/06_components/adjusted_vs_wpp.png", ggpubr::ggarrange(top, pc, ncol = 1, heights = c(1, 1.15)), w = 15, h = 11, bg = "white")

# variants, 1950-1980
v_cols <- c("central" = "#2a78d6", "anclas NRC 1982" = "#eb6834", "anclas WPP 2024" = "#1baf7a")
ref <- summ |> filter(series %in% c("WPP 2024", "Registradas"), year <= 1980)
pv1 <- completeness |> filter(year <= 1980) |> mutate(sex = lab_sex(sex)) |>
  ggplot(aes(year, c, col = variant)) + geom_line(linewidth = 0.8) +
  geom_point(data = anchors |> pivot_longer(all_of(variants), names_to = "variant", values_to = "c") |> mutate(sex = lab_sex(sex), variant = factor(variant, variants)), size = 2) +
  facet_wrap(~sex) + scale_color_manual(values = v_cols) + scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
  labs(title = "a. Completitud aplicada a las muertes naturales y otras externas de 5 años y más",
       subtitle = "Puntos: anclas de 1951 y 1964. Desde 1970, método empírico (igual en las tres variantes)", x = NULL, y = "Completitud", col = NULL) + base
pv <- function(v, title, ylab, f = identity) {
  ggplot(vsumm |> filter(year <= 1980) |> mutate(sex = lab_sex(sex)), aes(year, f(.data[[v]]))) +
    geom_line(data = ref |> mutate(sex = lab_sex(sex)), aes(linetype = series), colour = "#0b0b0b", linewidth = 0.5) +
    geom_line(aes(col = variant), linewidth = 0.8) +
    facet_wrap(~sex) + scale_color_manual(values = v_cols) + scale_linetype_manual(values = c("WPP 2024" = "solid", "Registradas" = "22")) +
    labs(title = title, x = NULL, y = ylab, col = NULL, linetype = NULL) + base
}
ggsave("figures/06_components/adjusted_variants.png",
       ggpubr::ggarrange(pv1, pv("e0", "b. Esperanza de vida al nacer", "e0 (años)"), pv("q45_15", "c. 45q15 (por mil)", "45q15", \(x) 1000 * x),
                         pv("q20_60", "d. 20q60 (por mil)", "20q60", \(x) 1000 * x), ncol = 2, nrow = 2, common.legend = FALSE),
       w = 15, h = 11, bg = "white")
