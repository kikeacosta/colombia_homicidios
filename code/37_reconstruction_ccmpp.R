# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 37. National cohort-component reconstruction, 1950-2023: engine, WPP net
#     migration by age and sex, and mortality scenarios against the censuses
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# First step of the population and mortality reconstruction. Single ages
# (0-100+), single years, both sexes, population at 1 January.
#
# 1. Engine. One-year closed projection with the conventions of
#    conflict_world_r/code/02_adding_age_specific_net_migration_1950_2100.R:
#      P(x, t+1)   = P(x-1, t) * L(x, t) / L(x-1, t)            x = 1..99
#      P(100+,t+1) = [P(99,t) + P(100+,t)] * L(100+) / [L(99) + L(100+)]
#      births(t)   = sum_x f(x,t) * [P_f(x,t) + P_f(x,t+1 closed)] / 2
#      P(0, t+1)   = births by sex * L(0,t) / l(0)
#    Life tables come from mx with WPP's own ax, so the WPP tables are
#    reproduced and a scenario only has to supply mx.
#
# 2. WPP net migration by age and sex = WPP population at 1 January of t+1
#    minus the closed projection of the WPP population of t with WPP
#    fertility and mortality (a residual: it also absorbs any difference
#    between these conventions and the UN's own projection). The sex ratio
#    at birth is the one implied by the WPP population aged 0.
#
# 3. Mortality scenarios. The projection is rerun from the WPP population of
#    1 January 1950 with WPP fertility and the WPP net migrants (counts), and
#    the mortality replaced by each of our series. Scenario rates at single
#    ages are the WPP rates times the ratio scenario / WPP of the age group
#    (0, 1-4, ..., 80+), year and sex:
#      WPP 2024            ratio 1 (must reproduce the WPP population)
#      Registradas         registered deaths
#      Ajuste DDM          registered / DDM completeness (23)
#      Adair-Lopez + MSE   ages 5+: non-violent registered / empirical
#                          completeness (36, model 1) + violent deaths, with
#                          the MSE correction in 1985-2018; under five: WPP
#                          (placeholder until UN IGME is added)
#      WPP + MSE           WPP with its conflict replaced by the MSE (27)
#
# 4. Check against the censuses. Each scenario's population is interpolated
#    to the census dates and compared with the enumerated population by sex
#    and age. With fertility, migration and the 1950 base fixed, a mortality
#    series that is too low piles up survivors at older ages, so the ratio
#    enumerated / projected falls with age. The level of the ratio is the
#    census coverage each scenario implies.
#
# What this does not do yet: estimate anything. Fertility, migration and the
# base population are WPP's, and WPP's migration is itself a residual of its
# own reconstruction, so the WPP scenario fits by construction. The next step
# is to let the censuses inform mortality, with migration given a prior
# instead of being fixed.
#
# input:  WPP 2024 population at 1 January by single age (Colombia rows are
#         extracted once from the csv.gz kept in conflict_world_r/data_input)
# output: data_input/reference/wpp2024_colombia_pop_1jan_single_age_1950-2024.csv
#         output/tables/wpp_net_migration_age_sex_1950-2023.csv
#         output/tables/reconstruction_scenarios_pop_1950-2024.csv
#         output/tables/reconstruction_census_check.csv
#         figures/05_reconstruction/wpp_net_migration.png
#         figures/05_reconstruction/scenarios_vs_censuses.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
source("code/00_setup.R")
dir.create("figures/05_reconstruction", showWarnings = FALSE)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# inputs ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
f_jan <- "data_input/reference/wpp2024_colombia_pop_1jan_single_age_1950-2024.csv"
if (!file.exists(f_jan)) {
  src <- "I:/My Drive/gits_drive/conflict_world_r/data_input/"
  slice <- function(file, keep) {
    cat("  extracting", file, "\n")
    read_csv_chunked(paste0(src, file), DataFrameCallback$new(\(x, pos) filter(x, LocID == 170, Time %in% keep)),
                     chunk_size = 5e5, show_col_types = FALSE, progress = FALSE,
                     col_types = cols(Notes = col_character(), .default = col_guess()))
  }
  bind_rows(slice("WPP2024_Population1JanuaryBySingleAgeSex_Medium_1950-2023.csv.gz", 1950:2023),
            slice("WPP2024_Population1JanuaryBySingleAgeSex_Medium_2024-2100.csv.gz", 2024)) |>
    select(LocID, Location, Variant, Time, AgeGrp, AgeGrpStart, AgeGrpSpan, PopMale, PopFemale, PopTotal) |>
    write_csv(f_jan)
}

years <- 1950:2023
ages <- 0:100
pop_wpp <-
  read_csv(f_jan, show_col_types = FALSE) |>
  transmute(year = Time, age = AgeGrpStart, m = PopMale * 1000, f = PopFemale * 1000) |>
  pivot_longer(c(m, f), names_to = "sex", values_to = "pop") |>
  arrange(sex, year, age)

lt_wpp <-
  read_csv("data_input/reference/wpp2024_colombia_lt_complete_1950-2100.csv", show_col_types = FALSE) |>
  filter(Time %in% years, Sex != "Total") |>
  transmute(year = Time, sex = unname(c(Female = "f", Male = "m")[Sex]), age = AgeGrpStart, mx, ax, Lx_wpp = Lx / 1e5) |>
  arrange(sex, year, age)

fert <-
  read_csv("data_input/reference/wpp2024_colombia_fertility_age1.csv", show_col_types = FALSE) |>
  filter(Variant == "Medium", Time %in% years) |>
  transmute(year = Time, age = AgeGrpStart, fx = ASFR / 1000, births_wpp = Births * 1000)

# person-years lived (radix 1) from mx and ax, single ages, open last group
Lx_from_mx <- function(mx, ax) {
  k <- length(mx)
  ax[k] <- 1 / mx[k]
  qx <- mx / (1 + (1 - ax) * mx); qx[k] <- 1
  lx <- c(1, cumprod(1 - qx))[1:k]
  dx <- lx * qx
  Lx <- c(lx[-1], 0) + ax * dx
  Lx[k] <- lx[k] / mx[k]
  Lx
}
lt_wpp <- lt_wpp |> mutate(Lx = Lx_from_mx(mx, ax), .by = c(sex, year))
cat("life tables rebuilt from mx: largest relative difference from WPP's Lx:",
    signif(max(abs(lt_wpp$Lx / lt_wpp$Lx_wpp - 1)), 2), "\n")

# arrays [age, year] by sex
arr <- \(d, v) d |> select(year, age, all_of(v)) |> pivot_wider(names_from = year, values_from = all_of(v)) |> arrange(age) |> select(-age) |> as.matrix()
P_w <- list(m = arr(filter(pop_wpp, sex == "m"), "pop"), f = arr(filter(pop_wpp, sex == "f"), "pop"))
L_w <- list(m = arr(filter(lt_wpp, sex == "m"), "Lx"), f = arr(filter(lt_wpp, sex == "f"), "Lx"))
F_w <- fert |> complete(year = years, age = ages, fill = list(fx = 0)) |> arr("fx")

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# engine ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
survive <- function(p, L) {
  k <- length(p)
  out <- numeric(k)
  out[2:(k - 1)] <- p[1:(k - 2)] * L[2:(k - 1)] / L[1:(k - 2)]
  out[k] <- (p[k - 1] + p[k]) * L[k] / (L[k - 1] + L[k])
  out
}
# one year, closed: returns the populations of 1 January of t + 1 and the births
step <- function(pm, pf, Lm, Lf, fx, srb) {
  m2 <- survive(pm, Lm); f2 <- survive(pf, Lf)
  births <- sum(fx * (pf + f2) / 2)
  f2[1] <- births / (1 + srb) * Lf[1]
  m2[1] <- births * srb / (1 + srb) * Lm[1]
  list(m = m2, f = f2, births = births)
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# WPP net migration by age and sex (residual) ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ny <- length(years)
# sex ratio at birth implied by the WPP population aged 0 at the end of each year
srb <- (P_w$m[1, 2:(ny + 1)] / L_w$m[1, ]) / (P_w$f[1, 2:(ny + 1)] / L_w$f[1, ])
cat("implied sex ratio at birth: range", paste(round(range(srb), 4), collapse = " - "), "\n")

M <- list(m = matrix(0, length(ages), ny), f = matrix(0, length(ages), ny))
births <- numeric(ny)
for (j in seq_len(ny)) {
  s <- step(P_w$m[, j], P_w$f[, j], L_w$m[, j], L_w$f[, j], F_w[, j], srb[j])
  M$m[, j] <- P_w$m[, j + 1] - s$m
  M$f[, j] <- P_w$f[, j + 1] - s$f
  births[j] <- s$births
}
b_wpp <- fert |> summarise(b = sum(births_wpp), .by = year) |> arrange(year) |> pull(b)
cat("births of the closed projection against WPP births: mean absolute difference",
    round(100 * mean(abs(births / b_wpp - 1)), 2), "%\n")

long <- \(mat, name) as_tibble(mat, .name_repair = ~ as.character(years)) |> mutate(age = ages) |>
  pivot_longer(-age, names_to = "year", values_to = name, names_transform = as.integer)
mig <- bind_rows(long(M$m, "net_mig") |> mutate(sex = "m"), long(M$f, "net_mig") |> mutate(sex = "f")) |>
  left_join(pop_wpp, by = c("year", "sex", "age")) |>
  select(year, sex, age, pop_1jan = pop, net_mig) |> arrange(year, sex, age)
write_csv(mig, "output/tables/wpp_net_migration_age_sex_1950-2023.csv")

cat("\nnet migration implied by WPP, thousands per year, by decade and sex:\n")
print(mig |> mutate(decade = 10 * (year %/% 10)) |> summarise(net = sum(net_mig) / n_distinct(year) / 1e3, .by = c(decade, sex)) |>
        mutate(net = round(net, 1)) |> pivot_wider(names_from = sex, values_from = net) |> as.data.frame())

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# mortality scenarios ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
grp <- \(a) case_when(a == 0 ~ 0, a < 5 ~ 1, TRUE ~ pmin(5 * (a %/% 5), 80))
exp <- read_csv("output/tables/deaths_expected_wpp_mse_1950-2023.csv", show_col_types = FALSE)
c_ddm <- read_csv("output/tables/completeness_ddm_conflict_annual.csv", show_col_types = FALSE) |>
  filter(variant == "migration + conflict") |> select(year, sex, c_ddm = completeness)
c_al <- read_csv("output/tables/completeness_compared_annual.csv", show_col_types = FALSE) |>
  filter(method == "Adair-Lopez, modelo 1") |> select(year, sex, c_al = completeness)
violent <- read_csv("output/tables/deaths_by_cause_sex_age_1953-2023.csv", show_col_types = FALSE) |> select(year, sex, age, violent_reg)

scen_names <- c("WPP 2024", "Registradas", "Ajuste DDM", "Adair-Lopez + MSE", "WPP + MSE")
ratios <-
  exp |>
  left_join(c_ddm, by = c("year", "sex")) |> left_join(c_al, by = c("year", "sex")) |>
  left_join(violent, by = c("year", "sex", "age")) |>
  mutate(v = replace_na(violent_reg, 0),
         v_adj = if_else(year %in% 1985:2018, v + hom_excess + dsp, v / c_al),
         `WPP 2024` = 1,
         Registradas = registered / wpp_total,
         `Ajuste DDM` = registered / c_ddm / wpp_total,
         `Adair-Lopez + MSE` = if_else(age < 5, 1, ((registered - v) / c_al + v_adj) / wpp_total),
         `WPP + MSE` = expected / wpp_total) |>
  select(year, sex, grp = age, all_of(scen_names)) |>
  pivot_longer(all_of(scen_names), names_to = "scenario", values_to = "ratio")
stopifnot(all(is.finite(ratios$ratio)), all(ratios$ratio > 0))

project <- function(sc) {
  lt <- lt_wpp |> mutate(grp = grp(age)) |>
    left_join(ratios |> filter(scenario == sc), by = c("year", "sex", "grp")) |>
    mutate(Lx = Lx_from_mx(mx * ratio, ax), .by = c(sex, year))
  L <- list(m = arr(filter(lt, sex == "m"), "Lx"), f = arr(filter(lt, sex == "f"), "Lx"))
  Pm <- Pf <- matrix(0, length(ages), ny + 1)
  Pm[, 1] <- P_w$m[, 1]; Pf[, 1] <- P_w$f[, 1]
  for (j in seq_len(ny)) {
    s <- step(Pm[, j], Pf[, j], L$m[, j], L$f[, j], F_w[, j], srb[j])
    Pm[, j + 1] <- pmax(s$m + M$m[, j], 0)
    Pf[, j + 1] <- pmax(s$f + M$f[, j], 0)
  }
  yy <- c(years, max(years) + 1)
  lg <- \(mat) as_tibble(mat, .name_repair = ~ as.character(yy)) |> mutate(age = ages) |>
    pivot_longer(-age, names_to = "year", values_to = "pop", names_transform = as.integer)
  bind_rows(lg(Pm) |> mutate(sex = "m"), lg(Pf) |> mutate(sex = "f")) |> mutate(scenario = sc)
}
proj <- map_dfr(scen_names, project) |> mutate(scenario = factor(scenario, scen_names))
write_csv(proj |> mutate(pop = round(pop, 1)), "output/tables/reconstruction_scenarios_pop_1950-2024.csv")

cat("\nvalidation: the WPP scenario against the WPP population, largest absolute difference (persons):",
    proj |> filter(scenario == "WPP 2024") |> inner_join(pop_wpp, by = c("year", "sex", "age"), suffix = c("", "_w")) |>
      summarise(d = max(abs(pop - pop_w))) |> pull(d) |> signif(3), "\n")

cat("\npopulation at 1 January, millions, by scenario:\n")
print(proj |> filter(year %in% c(1964, 1973, 1985, 1993, 2005, 2018)) |> summarise(pop = round(sum(pop) / 1e6, 2), .by = c(scenario, year)) |>
        pivot_wider(names_from = year, values_from = pop) |> as.data.frame())
cat("\npopulation aged 60+ relative to the WPP scenario, %:\n")
print(proj |> filter(age >= 60, year %in% c(1964, 1973, 1985, 1993, 2005, 2018)) |> summarise(pop = sum(pop), .by = c(scenario, year)) |>
        mutate(rel = round(100 * (pop / pop[scenario == "WPP 2024"] - 1), 1), .by = year) |> select(-pop) |>
        pivot_wider(names_from = year, values_from = rel) |> as.data.frame())

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# check against the censuses ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
cen <- read_rds("data_inter/census_pop_age.rds") |> filter(census >= 1951) |> select(census, dec, sex, age, enumerated = pop)
at_census <-
  cen |> distinct(census, dec) |>
  pmap_dfr(\(census, dec) {
    y <- floor(dec); w <- dec - y
    proj |> filter(year %in% c(y, y + 1)) |>
      summarise(pop = sum(pop * if_else(year == y, 1 - w, w)), .by = c(scenario, sex, age)) |>
      mutate(census = census, age = grp(age)) |>
      summarise(projected = sum(pop), .by = c(census, scenario, sex, age))
  })
chk <- at_census |> inner_join(cen, by = c("census", "sex", "age")) |> mutate(ratio = enumerated / projected)
write_csv(chk, "output/tables/reconstruction_census_check.csv")

band <- \(a) cut(a, c(-1, 14, 59, Inf), c("0-14", "15-59", "60+"))
cat("\nenumerated / projected by census, scenario and age band (both sexes):\n")
print(chk |> mutate(band = band(age)) |>
        summarise(r = sum(enumerated) / sum(projected), .by = c(census, scenario, band)) |>
        mutate(r = round(r, 3)) |> pivot_wider(names_from = census, values_from = r) |> arrange(band, scenario) |> as.data.frame())

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# figures ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ink <- "#52514e"
lab_sex <- \(s) factor(s, c("m", "f"), c("Hombres", "Mujeres"))
sex_cols <- c(Hombres = "#2a78d6", Mujeres = "#eb6834")
base <- theme_bw(base_size = 11) +
  theme(panel.grid.minor = element_blank(), panel.grid.major = element_line(colour = "grey92"),
        legend.position = "bottom", strip.background = element_rect(fill = "grey96", colour = NA),
        plot.title = element_text(size = 12, face = "bold"), plot.subtitle = element_text(size = 9.5, colour = ink))

p1 <-
  mig |> summarise(net = sum(net_mig) / 1e3, .by = c(year, sex)) |> mutate(sex = lab_sex(sex)) |>
  ggplot(aes(year, net, col = sex)) +
  geom_hline(yintercept = 0, colour = "grey55", linewidth = 0.3) +
  geom_line(linewidth = 0.8) +
  scale_color_manual(values = sex_cols) +
  scale_x_continuous(breaks = seq(1950, 2020, 10)) +
  labs(title = "a. Migración neta anual implícita en WPP 2024", subtitle = "Miles de personas; negativo: salidas netas",
       x = NULL, y = "Miles", col = NULL) +
  base
p2 <-
  mig |> mutate(decade = paste0(10 * (year %/% 10), "s")) |>
  summarise(net = sum(net_mig) / n_distinct(year) / 1e3, .by = c(decade, sex, age)) |>
  filter(age < 100) |> mutate(sex = lab_sex(sex)) |>
  ggplot(aes(age, net, col = sex)) +
  geom_hline(yintercept = 0, colour = "grey55", linewidth = 0.3) +
  geom_line(linewidth = 0.6) +
  facet_wrap(~decade, nrow = 2) +
  scale_color_manual(values = sex_cols) +
  labs(title = "b. Perfil por edad de la migración neta, promedio anual por década", subtitle = "Miles de personas por edad simple",
       x = "Edad", y = "Miles", col = NULL) +
  base
ggpubr::ggarrange(p1, p2, ncol = 1, heights = c(1, 1.5), common.legend = TRUE, legend = "bottom") |>
  ggsave(filename = "figures/05_reconstruction/wpp_net_migration.png", width = 13, height = 10, bg = "white")

scen_cols <- c("WPP 2024" = "#0b0b0b", "Registradas" = "#8a8983", "Ajuste DDM" = "#1baf7a", "Adair-Lopez + MSE" = "#2a78d6", "WPP + MSE" = "#eb6834")
age_mid <- \(a) case_when(a == 0 ~ 0.5, a == 1 ~ 3, TRUE ~ a + 2.5)
chk |>
  mutate(sex = lab_sex(sex), x = age_mid(age)) |>
  ggplot(aes(x, ratio, col = scenario)) +
  geom_hline(yintercept = 1, colour = "grey55", linewidth = 0.3) +
  geom_line(aes(linewidth = scenario == "WPP 2024")) +
  facet_grid(sex ~ census) +
  scale_color_manual(values = scen_cols) +
  scale_linewidth_manual(values = c(`TRUE` = 0.9, `FALSE` = 0.6), guide = "none") +
  scale_x_continuous(breaks = seq(0, 80, 20)) +
  coord_cartesian(ylim = c(0.5, 1.5)) +
  labs(title = "Población enumerada en cada censo frente a la proyectada con cada serie de mortalidad",
       subtitle = "Razón enumerada / proyectada por edad. Base 1950, fecundidad y migración neta de WPP 2024 en todos los escenarios; solo cambia la mortalidad.\nUna razón que cae con la edad indica mortalidad demasiado baja: sobran supervivientes",
       x = "Edad", y = "Enumerada / proyectada", col = NULL) +
  base
ggsave("figures/05_reconstruction/scenarios_vs_censuses.png", w = 15, h = 7.5, bg = "white")
