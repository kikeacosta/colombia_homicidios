# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 52. Does the registered sex ratio of mortality see the conflict deaths the
#     registry does not classify as violent? Calibration against the
#     departmental MSE, 1985-2018
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# The municipal model (07, 20) distributes the registered violent deaths of
# a department across its municipalities with the all-cause sex ratio; its
# department level is the registry's. To estimate homicides where the
# registry fails, the sex ratio has to carry information on the deaths the
# registry did not classify as violent. The departmental MSE (51) says how
# many conflict deaths are missing from the violent component in each
# department and year, so this is testable:
#
#   if the missing conflict deaths were registered under another cause
#   (natural, ill-defined, accident), the sex ratio of the NON-VIOLENT
#   registered deaths at the conflict ages rises with them; if they never
#   entered the registry, it does not.
#
# panel: department x year, 1985-2018, men and women aged 15-49 (where the
# MSE deaths concentrate), from the EEVV parquet (11b), the departmental MSE
# (51) and the completeness applied by department and sex (50).
#   nv   registered non-violent deaths (residual + suicide + accident)
#   v    registered violent deaths (homicide, undetermined, legal)
#   m    MSE deaths missing from the violent component (hom_excess + dsp)
#   SR   age-standardised ratio of male to female death rates (standard:
#        national population of 2000, both sexes), for all causes and for
#        the non-violent deaths
#   hidden male deaths implied by the ratio: H = nv_m - SR0 x nv_f x pop_m / pop_f
#        with SR0 the baseline non-violent ratio of the department (its
#        median over the years with the lowest registered violence)
#
# models (lme4), department random intercept and year fixed effects:
#   A  log SR_nv  ~ m_rate + v_rate + log(c_m / c_f)
#   B  log SR_all ~ m_rate + v_rate + log(c_m / c_f)
#   C  H / pop    ~ m_rate (+ v_rate)                 [slope 1 = all inside]
# m_rate and v_rate per 1,000 persons aged 15-49, both sexes.
#
# output: output/tables/sexratio_mse_panel_1985-2018.csv
#         output/tables/sexratio_mse_models.csv
#         figures/07_departments/sexratio_mse_scatter.png
#         figures/07_departments/sexratio_mse_series.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
source("code/00_setup.R")
library(arrow); library(lme4)
dir.create("figures/07_departments", showWarnings = FALSE)

amazon <- c("91", "94", "95", "97", "99")
unit_of <- function(cod) if_else(cod %in% amazon, "9X", cod)
ages <- seq(15, 45, 5)
years <- 1985:2018

raw <- read_parquet("output/deaths_pop_munic_age_1985_2023.parquet") |>
  filter(!is.na(age), age %in% ages, year %in% years) |>
  transmute(cod = unit_of(cod_dpto), year, sex, age, pop, nv = dx_residual + dx_suicide + dx_accident, v = dx_homicide + dx_undetermined + dx_legal, all = dx_all) |>
  summarise(pop = sum(pop, na.rm = TRUE), across(c(nv, v, all), sum), .by = c(cod, year, sex, age))
names_tab <- read_csv("output/tables/dept_mortality_adjusted_summary.csv", show_col_types = FALSE, col_types = cols(cod = "c")) |> distinct(cod, unit)
mse <- read_csv("output/tables/mse_departments_1985-2018.csv", show_col_types = FALSE, col_types = cols(cod = "c")) |>
  filter(age %in% ages) |> select(cod, year, sex, age, m = mse_added, mse_hom)
comp <- read_csv("output/tables/dept_completeness_applied_1985-2023.csv", show_col_types = FALSE, col_types = cols(cod = "c")) |>
  select(cod, year, sex, c = completeness)

# standard population: national 2000, both sexes, ages 15-49
std <- raw |> filter(year == 2000) |> summarise(w = sum(pop), .by = age) |> mutate(w = w / sum(w))
d <- raw |> left_join(mse, by = c("cod", "year", "sex", "age")) |> mutate(m = replace_na(m, 0), mse_hom = replace_na(mse_hom, 0)) |>
  left_join(std, by = "age") |>
  summarise(pop = sum(pop), nv = sum(nv), v = sum(v), all = sum(all), m = sum(m), mse_hom = sum(mse_hom),
            r_nv = sum(w * nv / pop), r_all = sum(w * all / pop), .by = c(cod, year, sex)) |>
  left_join(comp, by = c("cod", "year", "sex"))
panel <- d |> pivot_wider(names_from = sex, values_from = c(pop, nv, v, all, m, mse_hom, r_nv, r_all, c)) |>
  mutate(pop = pop_m + pop_f, v = v_m + v_f, m = m_m + m_f,
         sr_nv = r_nv_m / r_nv_f, sr_all = r_all_m / r_all_f,
         v_rate = 1000 * v / pop, m_rate = 1000 * m / pop, lc = log(c_m / c_f)) |>
  left_join(names_tab, by = "cod")
# baseline non-violent ratio per department: median over its 8 years of lowest registered violence
panel <- panel |>
  mutate(sr0 = median(sr_nv[rank(v_rate, ties.method = "first") <= 8]), .by = cod) |>
  mutate(H = nv_m - sr0 * nv_f * pop_m / pop_f, h_rate = 1000 * H / pop)
write_csv(panel |> select(cod, unit, year, pop_m, pop_f, nv_m, nv_f, v_m, v_f, m_m, m_f, mse_hom_m, mse_hom_f, sr_nv, sr_all, sr0, H, v_rate, m_rate, h_rate, c_m, c_f),
          "output/tables/sexratio_mse_panel_1985-2018.csv")
cat(sprintf("panel: %d department-years; MSE missing deaths at 15-49: %s (%.0f %% of the registered violent deaths at those ages)\n",
            nrow(panel), format(round(sum(panel$m)), big.mark = ","), 100 * sum(panel$m) / sum(panel$v)))

# ---- models ----
fit <- function(f, data) lmer(f, data = data, REML = FALSE)
mods <- list(
  A_sr_nv       = fit(log(sr_nv) ~ m_rate + v_rate + lc + factor(year) + (1 | cod), panel),
  A_sr_nv_noc   = fit(log(sr_nv) ~ m_rate + v_rate + factor(year) + (1 | cod), panel),
  B_sr_all      = fit(log(sr_all) ~ m_rate + v_rate + lc + factor(year) + (1 | cod), panel),
  C_hidden      = fit(h_rate ~ m_rate + factor(year) + (1 | cod), panel),
  C_hidden_v    = fit(h_rate ~ m_rate + v_rate + factor(year) + (1 | cod), panel)
)
tab <- imap_dfr(mods, function(mo, nm) {
  co <- summary(mo)$coefficients
  as_tibble(co, rownames = "term") |> filter(term %in% c("m_rate", "v_rate", "lc")) |>
    transmute(model = nm, term, estimate = Estimate, se = `Std. Error`, t = `t value`)
})
# within-department R2 contribution: compare with the model without m_rate
r2 <- imap_dfr(mods, function(mo, nm) {
  f0 <- update(formula(mo), . ~ . - m_rate)
  m0 <- fit(f0, panel)
  tibble(model = nm, loglik = as.numeric(logLik(mo)), loglik_without_m = as.numeric(logLik(m0)), lr_chisq = 2 * (as.numeric(logLik(mo)) - as.numeric(logLik(m0))))
})
tab <- tab |> left_join(r2, by = "model")
write_csv(tab, "output/tables/sexratio_mse_models.csv")
cat("\ncoefficients (per missing or registered violent death per 1,000 persons aged 15-49), department random intercept, year fixed effects:\n")
print(tab |> mutate(across(c(estimate, se, t, lr_chisq), function(x) signif(x, 3))) |> select(model, term, estimate, se, t, lr_chisq) |> as.data.frame())
cat("\nreading: in A, the coefficient of v_rate is what one registered violent death per 1,000 does to the NON-violent ratio (should be ~0);\n",
    "the coefficient of m_rate is what one MISSING conflict death per 1,000 does to it. In B both act on the all-cause ratio: a registered\n",
    "violent death raises it by construction; a missing one only if it is in the registry under another cause.\n",
    "In C the slope of m_rate is the share of the missing deaths that the hidden-male-deaths measure recovers (1 = all of them).\n")

# the all-cause effect of a registered violent death, as the yardstick for B
cat(sprintf("\nyardstick: mean male share of registered violent deaths 15-49 = %.2f; mean SR_all = %.2f, mean male all-cause rate = %.1f per 1,000\n",
            sum(panel$v_m) / sum(panel$v), mean(panel$sr_all), 1000 * sum(panel$all_m) / sum(panel$pop_m)))

# ---- figures ----
p <- panel |> ggplot(aes(m_rate, h_rate)) +
  geom_hline(yintercept = 0, colour = "grey60") + geom_abline(slope = 1, intercept = 0, linetype = "22", colour = "grey40") +
  geom_point(aes(colour = year), size = 1.2, alpha = 0.8) +
  geom_smooth(method = "lm", se = TRUE, colour = "#d6641a", linewidth = 0.7) +
  scale_colour_viridis_c(name = NULL) +
  labs(x = "Muertes del conflicto que faltan en la componente violenta (MSE), por 1.000 personas de 15-49",
       y = "Muertes masculinas ocultas implícitas en el cociente de sexo no violento, por 1.000",
       title = "¿El cociente de sexo de las muertes no violentas ve las muertes del conflicto que faltan?",
       subtitle = "Departamento-año 1985-2018; la diagonal punteada es 'todas las faltantes están en el registro bajo otra causa'") +
  theme_minimal(base_size = 10) + theme(legend.position = "right")
ggsave("figures/07_departments/sexratio_mse_scatter.png", p, width = 9, height = 6, bg = "white", dpi = 150)

sel <- c("Antioquia", "Meta", "Putumayo", "Caquetá", "Cesar", "Bogotá", "Valle del Cauca", "Chocó")
p <- panel |> filter(unit %in% sel) |>
  select(unit, year, `MSE faltantes` = m_rate, `Ocultas por el cociente` = h_rate, `Violentas registradas` = v_rate) |>
  pivot_longer(-c(unit, year), names_to = "what", values_to = "rate") |>
  mutate(unit = factor(unit, sel)) |>
  ggplot(aes(year, rate, colour = what)) +
  geom_hline(yintercept = 0, colour = "grey70") + geom_line(linewidth = 0.7) +
  facet_wrap(~ unit, ncol = 4, scales = "free_y") +
  scale_colour_manual(values = c("#d6641a", "#1f5fa6", "#7a7a7a"), name = NULL) +
  labs(x = NULL, y = "Por 1.000 personas de 15-49", title = "Violentas registradas, faltantes del MSE y muertes ocultas implícitas en el cociente de sexo") +
  theme_minimal(base_size = 10) + theme(legend.position = "bottom", panel.grid.minor = element_blank())
ggsave("figures/07_departments/sexratio_mse_series.png", p, width = 12, height = 6, bg = "white", dpi = 150)
cat("written: output/tables/sexratio_mse_*.csv, figures/07_departments/sexratio_mse_*.png\n")
