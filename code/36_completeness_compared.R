# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 36. Completeness of death registration: DDM on censuses corrected for
#     omission, the empirical method, and what WPP 2024 implies
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# The DDM of 22-23 runs on the censuses as enumerated and finds registration
# almost complete before 1990, while WPP implies 80-90 %. Differential census
# omission by age and sex is confounded with death under-registration in the
# GGB, so here the censuses are corrected before the DDM, and the result is
# set against the empirical method of Adair & Lopez (33), which needs no
# census pair.
#
# census correction (ASSUMPTION, stated per census in `refs`): the "true"
#   population at each census date is a reconstructed population, and the
#   correction factor by sex and age group is reference / enumerated:
#     1985, 1993, 2005   DANE retroprojection (DANE's own census conciliation)
#     1951, 1964, 1973,  WPP 2024 (no DANE reconstruction on disk; the UNdata
#     2018               1973 counts are already DANE's adjusted figures)
#     1938               no reference: the 1951 factors are used
#   two variants:
#     "nivel"            one factor per census and sex (total omission)
#     "edad y sexo"      factor by age, smoothed over age (loess on the log
#                        ratio, ages 0-75) so that the census age heaping is
#                        not replaced by the reference's smooth age profile;
#                        80+ takes the factor of 75-79
#   Before 1985 the corrected censuses lean on WPP, so those windows are not
#   an estimate independent of WPP; from 1985 they rest on DANE.
#
# DDM: GGB-SEG hybrid (DDM package, automatic age range), second census
#   closed for migration as in 22, numerator = registered deaths + conflict
#   deaths missing from the registry (MSE, 27), completeness expressed for
#   the registered deaths (x registered / corrected at 15+), anchored at
#   window midpoints and interpolated on the logit scale as in 23.
#
# empirical method (Adair & Lopez 2018, coefficients of 33): all-age
#   completeness of the non-violent registered deaths from the registered
#   crude death rate, the share aged 65+, the true 5q0 (WPP 2024), calendar
#   year and, in Model 1, the completeness of under-five registration. 33
#   covers 1979-2023 with the DANE population; here the same formulas run on
#   1950-2023 with the WPP population. The paper's sample is 1970-2015:
#   earlier years are an extrapolation of its year term.
#
# benchmark: registered / WPP 2024 deaths, at 15+ (for the DDM) and at all
#   ages (for the empirical method).
#
# output: output/tables/census_correction_factors.csv
#         output/tables/completeness_ddm_census_corrected.csv
#         output/tables/completeness_compared_annual.csv
#         figures/04_completeness/census_correction_factors.png
#         figures/04_completeness/completeness_compared.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
source("code/00_setup.R")
library(DDM)

logit <- \(p) log(p / (1 - p))
expit <- \(x) 1 / (1 + exp(-x))
lab_sex <- \(s) factor(s, c("m", "f"), c("Hombres", "Mujeres"))

cen <- read_rds("data_inter/census_pop_age.rds")
inp <- read_rds("data_inter/ddm_census_inputs.rds")
windows <- inp$windows
migr <- inp$migr
deaths <- read_rds("data_inter/deaths_age_annual_1938-2023.rds") |> summarise(dx = sum(dx), .by = c(year, sex, age))
exp <- read_csv("output/tables/deaths_expected_wpp_mse_1950-2023.csv", show_col_types = FALSE)
pyr <- read_csv("output/tables/pyramids_census_wpp_dane.csv", show_col_types = FALSE)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# census correction factors ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
refs <- tribble(
  ~census, ~ref,
  1951, "WPP 2024", 1964, "WPP 2024", 1973, "WPP 2024",
  1985, "DANE (retroproyección)", 1993, "DANE (retroproyección)", 2005, "DANE (retroproyección)",
  2018, "WPP 2024")

fac <-
  pyr |>
  filter(src == "Censo (enumerado)") |>
  select(census, sex, age, enumerated = pop) |>
  inner_join(refs, by = "census") |>
  inner_join(pyr |> select(census, sex, age, ref = src, reference = pop), by = c("census", "sex", "age", "ref")) |>
  arrange(census, sex, age) |>
  mutate(raw = reference / enumerated,
         nivel = sum(reference) / sum(enumerated),
         smooth = {
           i <- seq_along(age); ok <- age <= 75
           fit <- loess(log(raw[ok]) ~ i[ok], span = 0.6, degree = 1)
           s <- exp(predict(fit, i)); s[!ok] <- s[max(which(ok))]; s
         },
         # the smoothed factors keep the total of the reference population
         `edad y sexo` = smooth * sum(reference) / sum(enumerated * smooth),
         .by = c(census, sex))
# 1938: no reference, 1951 factors
fac <- bind_rows(fac |> filter(census == 1951) |> mutate(census = 1938, ref = "factores de 1951", enumerated = NA, reference = NA), fac) |>
  select(census, sex, age, ref, enumerated, reference, raw, nivel, `edad y sexo`)
write_csv(fac, "output/tables/census_correction_factors.csv")

cat("omission implied by the reference population, % of the reference (1 - enumerated / reference):\n")
print(fac |> filter(census > 1938) |> summarise(omission = round(100 * (1 - sum(enumerated) / sum(reference)), 1), ref = first(ref), .by = c(census, sex)) |>
        pivot_wider(names_from = sex, values_from = omission) |> as.data.frame())

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DDM input ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# numerator: registered + conflict deaths missing from the registry (27)
add <- exp |> transmute(year, sex, age, add = hom_excess + dsp)
deaths_adj <- deaths |> left_join(add, by = c("year", "sex", "age")) |> replace_na(list(add = 0)) |> mutate(dx_c = dx + add)

avg_deaths <- function(d1, d2) {
  yrs <- floor(d1):floor(d2)
  w <- tibble(year = yrs, w = (pmin(yrs + 1, d2) - pmax(yrs, d1)) / (d2 - d1))
  deaths_adj |> inner_join(w, by = "year") |> summarise(deaths = sum(dx_c * w), registered = sum(dx * w), .by = c(sex, age))
}

variants <- c("sin corregir", "nivel", "edad y sexo")
pop_var <-
  cen |>
  select(census, sex, age, pop) |>
  left_join(fac |> select(census, sex, age, nivel, `edad y sexo`), by = c("census", "sex", "age")) |>
  mutate(`sin corregir` = 1) |>
  pivot_longer(all_of(variants), names_to = "variant", values_to = "f") |>
  mutate(pop = pop * f)

X <-
  pmap_dfr(windows, \(c1, c2, d1, d2, window) {
    pop_var |> filter(census == c1) |> select(variant, sex, age, pop1 = pop) |>
      inner_join(pop_var |> filter(census == c2) |> select(variant, sex, age, pop2 = pop), by = c("variant", "sex", "age")) |>
      inner_join(avg_deaths(d1, d2), by = c("sex", "age")) |>
      left_join(migr |> filter(cod == window) |> select(sex, age, emig, immig), by = c("sex", "age")) |>
      mutate(pop2 = pop2 + emig - immig, year1 = d1, year2 = d2, cod = window) |>
      select(-emig, -immig)
  })

res <-
  expand_grid(variant = variants, sex = c("m", "f")) |>
  pmap_dfr(\(variant, sex) {
    x <- X |> filter(variant == !!variant, sex == !!sex) |>
      select(cod, pop1, pop2, deaths, year1, year2, age, sex) |> as.data.frame()
    ddm(x) |> as_tibble() |> mutate(variant = variant, sex = sex, .before = 1)
  }) |>
  rename(window = cod) |>
  left_join(X |> filter(age >= 15) |> summarise(ratio = sum(registered) / sum(deaths), .by = c(cod, sex, variant)) |> rename(window = cod),
            by = c("window", "sex", "variant")) |>
  left_join(windows |> select(window, d1, d2), by = "window") |>
  mutate(ggbseg_reg = ggbseg * ratio, variant = factor(variant, variants))
write_csv(res, "output/tables/completeness_ddm_census_corrected.csv")

cat("\nDDM completeness of the registered deaths (GGB-SEG x registered / corrected), by census variant:\n")
print(res |> transmute(window, sex, variant, c = round(ggbseg_reg, 3)) |> pivot_wider(names_from = variant, values_from = c) |>
        arrange(sex, window) |> as.data.frame())

# check: the uncorrected variant reproduces 23
old <- read_csv("output/tables/completeness_ddm_conflict.csv", show_col_types = FALSE) |>
  filter(variant == "migration + conflict", ages == "auto 15-75") |> select(window, sex, old = ggbseg_reg)
cat("\nlargest difference between 'sin corregir' and script 23:",
    res |> filter(variant == "sin corregir") |> inner_join(old, by = c("window", "sex")) |> summarise(d = max(abs(ggbseg_reg - old))) |> pull(d) |> signif(2), "\n")

annual_ddm <-
  res |>
  filter(!window %in% c("1964-1973", "1973-1985")) |>
  mutate(mid = (d1 + d2) / 2, comp = pmin(ggbseg_reg, 0.995)) |>
  group_by(variant, sex) |>
  reframe(year = 1950:2023, completeness = expit(approx(mid, logit(comp), xout = year + 0.5, rule = 2)$y)) |>
  mutate(method = paste0("DDM, censo ", variant), scope = "15+")

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# empirical method, 1950-2023 ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
coefs <- tribble(
  ~model, ~sex, ~cdr2,   ~cdr,   ~p65,     ~lnq5,   ~c5q0,  ~year,   ~const,
  1,      "m",  -0.0174, 0.5957, -12.9528, -1.1266, 2.0030, -0.0188, 32.3442,
  1,      "f",  -0.0198, 0.6959, -17.4154, -1.1720, 1.9387, -0.0144, 23.5542,
  2,      "m",  -0.0227, 0.7620, -17.3543, -1.4798, 0,      -0.0265, 47.3778,
  2,      "f",  -0.0255, 0.8841, -22.1099, -1.5262, 0,      -0.0217, 37.7887)

q5_wpp <-
  read_csv("data_input/reference/wpp2024_colombia_lt_complete_1950-2100.csv", show_col_types = FALSE) |>
  filter(Time %in% 1950:2023, Sex != "Total") |>
  summarise(q5 = 1 - lx[AgeGrpStart == 5] / lx[AgeGrpStart == 0], .by = c(Time, Sex)) |>
  transmute(year = Time, sex = unname(c(Female = "f", Male = "m")[Sex]), q5)

violent <- read_csv("output/tables/deaths_by_cause_sex_age_1953-2023.csv", show_col_types = FALSE) |> select(year, sex, age, violent_reg)

al <-
  exp |>
  left_join(violent, by = c("year", "sex", "age")) |>
  mutate(nv = registered - replace_na(violent_reg, 0)) |>
  summarise(reg_cdr = 1000 * sum(nv) / sum(pop), p65 = sum(pop[age >= 65]) / sum(pop),
            c5q0 = pmin(sum(nv[age < 5]) / sum(wpp_total[age < 5]), 1.2), .by = c(year, sex)) |>
  inner_join(q5_wpp, by = c("year", "sex")) |>
  inner_join(coefs, by = "sex", suffix = c("", "_b"), relationship = "many-to-many") |>
  mutate(completeness = plogis(const + cdr2 * reg_cdr^2 + cdr * reg_cdr + p65_b * p65 + lnq5 * log(q5) + c5q0_b * c5q0 + year_b * year),
         method = paste("Adair-Lopez, modelo", model), scope = "todas las edades") |>
  select(year, sex, method, scope, completeness, reg_cdr, p65, q5, c5q0)

s33 <- read_csv("output/tables/completeness_empirical_national_1979-2023.csv", show_col_types = FALSE) |>
  filter(variant == "non_violent", sex != "t") |> transmute(year, sex, method = paste("Adair-Lopez, modelo", model), c33 = completeness)
cat("\nempirical method here (WPP population) against script 33 (DANE population from 1985), mean absolute difference 1979-2023:",
    al |> inner_join(s33, by = c("year", "sex", "method")) |> summarise(d = mean(abs(completeness - c33))) |> pull(d) |> round(4), "\n")

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# benchmark and comparison ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
bench <-
  bind_rows(
    exp |> filter(age >= 15) |> summarise(completeness = sum(registered) / sum(wpp_total), .by = c(year, sex)) |> mutate(scope = "15+"),
    exp |> summarise(completeness = sum(registered) / sum(wpp_total), .by = c(year, sex)) |> mutate(scope = "todas las edades")) |>
  mutate(method = "Implícita en WPP 2024")

methods <- c("Implícita en WPP 2024", paste0("DDM, censo ", variants), paste("Adair-Lopez, modelo", 1:2))
annual <-
  bind_rows(bench, annual_ddm |> select(year, sex, method, scope, completeness), al |> select(year, sex, method, scope, completeness)) |>
  mutate(method = factor(method, methods)) |>
  arrange(method, scope, sex, year)
write_csv(annual, "output/tables/completeness_compared_annual.csv")

period <- \(y) cut(y, c(1949, 1969, 1984, 1999, 2019), c("1950-69", "1970-84", "1985-99", "2000-19"))
err <-
  annual |>
  filter(method != "Implícita en WPP 2024", year <= 2019) |>
  inner_join(bench |> select(year, sex, scope, wpp = completeness), by = c("year", "sex", "scope")) |>
  mutate(period = period(year)) |>
  summarise(bias = mean(completeness - wpp), mae = mean(abs(completeness - wpp)), .by = c(method, scope, sex, period))
cat("\nmean difference from the completeness implied by WPP (same age scope), percentage points; positive = method finds registration more complete than WPP:\n")
print(err |> transmute(method, scope, sex, period, bias = round(100 * bias, 1)) |> pivot_wider(names_from = period, values_from = bias) |>
        arrange(sex, method) |> as.data.frame())
cat("\nmean absolute difference, percentage points:\n")
print(err |> transmute(method, sex, period, mae = round(100 * mae, 1)) |> pivot_wider(names_from = period, values_from = mae) |>
        arrange(sex, method) |> as.data.frame())

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# figures ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ink <- "#52514e"
base <- theme_bw(base_size = 11) +
  theme(panel.grid.minor = element_blank(), panel.grid.major = element_line(colour = "grey92"),
        legend.position = "bottom", strip.background = element_rect(fill = "grey96", colour = NA),
        plot.title = element_text(size = 12, face = "bold"), plot.subtitle = element_text(size = 9.5, colour = ink))
age_top <- max(cen$age)
age_mid <- \(a) case_when(a == 0 ~ 0.5, a == 1 ~ 3, TRUE ~ a + 2.5)

# correction factors by age: raw and smoothed
fac |>
  filter(census > 1938) |>
  mutate(sex = lab_sex(sex), x = age_mid(age), panel = paste0(census, " (", if_else(str_detect(ref, "DANE"), "DANE", "WPP"), ")")) |>
  ggplot(aes(x)) +
  geom_hline(yintercept = 1, colour = "grey55", linewidth = 0.3) +
  geom_point(aes(y = raw, col = sex), size = 1, alpha = 0.55) +
  geom_line(aes(y = `edad y sexo`, col = sex), linewidth = 0.8) +
  geom_line(aes(y = nivel, col = sex), linewidth = 0.4, linetype = "22") +
  facet_wrap(~panel, nrow = 2) +
  scale_color_manual(values = c(Hombres = "#2a78d6", Mujeres = "#eb6834")) +
  scale_x_continuous(breaks = seq(0, 80, 20)) +
  coord_cartesian(ylim = c(0.6, 1.45)) +
  labs(title = "Factores de corrección de los censos por omisión: población de referencia / población enumerada",
       subtitle = "Puntos: razón por grupo de edad. Línea continua: factor suavizado (variante edad y sexo). Línea punteada: factor único por censo (variante nivel). Más de 1: el censo omite población",
       x = "Edad", y = "Factor", col = NULL) +
  base
ggsave("figures/04_completeness/census_correction_factors.png", w = 14, h = 7.5, bg = "white")

cols <- c("Implícita en WPP 2024" = "#0b0b0b", "DDM, censo sin corregir" = "#8a8983", "DDM, censo nivel" = "#1baf7a",
          "DDM, censo edad y sexo" = "#2a78d6", "Adair-Lopez, modelo 1" = "#eb6834", "Adair-Lopez, modelo 2" = "#e87ba4")
annual |>
  mutate(sex = lab_sex(sex),
         scope = factor(scope, c("15+", "todas las edades"), c("Adultos (15+): DDM", "Todas las edades: método empírico"))) |>
  ggplot(aes(year, completeness, col = method)) +
  annotate("rect", xmin = 1949.5, xmax = 1969.5, ymin = -Inf, ymax = Inf, fill = "grey50", alpha = 0.06) +
  geom_line(aes(linewidth = method == "Implícita en WPP 2024")) +
  geom_point(data = res |> filter(!window %in% c("1964-1973", "1973-1985")) |>
               transmute(year = (d1 + d2) / 2, completeness = pmin(ggbseg_reg, 0.995), method = factor(paste0("DDM, censo ", variant), methods),
                         sex = lab_sex(sex), scope = factor("Adultos (15+): DDM", c("Adultos (15+): DDM", "Todas las edades: método empírico"))),
             size = 1.8) +
  facet_grid(sex ~ scope) +
  scale_color_manual(values = cols, drop = FALSE) +
  scale_linewidth_manual(values = c(`TRUE` = 1, `FALSE` = 0.75), guide = "none") +
  scale_x_continuous(breaks = seq(1950, 2020, 10)) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1), breaks = seq(0.5, 1, 0.1)) +
  labs(title = "Completitud del registro de defunciones según el método, frente a la implícita en WPP 2024",
       subtitle = "Puntos: ventanas intercensales del DDM. Franja gris: años anteriores al periodo de calibración del método empírico (1970-2015)",
       x = NULL, y = "Completitud de las defunciones registradas", col = NULL) +
  base + guides(col = guide_legend(nrow = 2))
ggsave("figures/04_completeness/completeness_compared.png", w = 14, h = 9, bg = "white")
