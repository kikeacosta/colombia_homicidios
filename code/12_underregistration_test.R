# 12_underregistration_test.R ------------------------------------------------
# first test of the under-registration hypothesis (plan B2.4 / B5.2):
#
#   H: the all-cause sex ratio fails to track homicides before ~1998 because
#      deaths, and differentially male vs female deaths, are not registered.
#
# if H holds, then across departments
#   (a) the pre-1998 correlation between the (log) sex ratio and the (log)
#       homicide rate should rise with estimated registration completeness,
#       and fall with the male/female completeness differential's distance
#       from 1;
#   (b) after 1998, when completeness is high everywhere, the correlation
#       should not depend on completeness;
#   (c) within departments, years of higher completeness should show a
#       stronger sex ratio - homicide association.
#
# inputs: output/deaths_pop_munic_1985_2023.csv.gz (11) and
#         data_inter/completeness_deptos.rds (10)
# outputs: output/tables/underreg_dept_correlations.csv, figures/underreg_*.png
#
# caveat: completeness here is the anchored GGB index of 10, department-level
# and relative to DANE's projection. departments flagged unreliable there
# (the Amazonia micro-departments) are excluded.

rm(list = ls())
gc()
source("code/00_setup.R")

brk <- 1998 # new death certificate and ICD-10

dat <- read_csv("output/deaths_pop_munic_1985_2023.csv.gz", show_col_types = FALSE)
comp <- read_rds("data_inter/completeness_deptos.rds")

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# department series ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

dep_sx <-
  dat |>
  filter(year <= 2017, !is.na(pop)) |>
  mutate(dx_v = dx_homicide + dx_undetermined + dx_legal) |>
  summarise(
    dx_all = sum(dx_all), dx_v = sum(dx_v), pop = sum(pop),
    .by = c(year, cod_dpto, dpto, sex)
  )

dep <-
  dep_sx |>
  mutate(mx = dx_all / pop) |>
  select(year, cod_dpto, dpto, sex, mx) |>
  pivot_wider(names_from = sex, values_from = mx) |>
  mutate(log_sr = log(m / f)) |>
  left_join(
    dep_sx |>
      summarise(dx_v = sum(dx_v), pop = sum(pop), .by = c(year, cod_dpto)) |>
      mutate(log_h = log(dx_v / pop)),
    by = c("year", "cod_dpto")
  ) |>
  filter(is.finite(log_sr), is.finite(log_h))

# completeness: department x period means, both sexes, plus the M/F
# differential, restricted to reliable department-years
comp_w <-
  comp |>
  filter(reliable) |>
  select(cod_dpto, year, sex, completeness) |>
  pivot_wider(names_from = sex, values_from = completeness) |>
  drop_na(m, f) |>
  mutate(comp_mean = (m + f) / 2, comp_diff = log(m / f))

dep <-
  dep |>
  mutate(period = ifelse(year < brk, "pre", "post")) |>
  inner_join(comp_w, by = c("cod_dpto", "year"))

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# (a, b) department-level correlations by period ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

r_dept <-
  dep |>
  summarise(
    n = n(),
    r_levels = cor(log_sr, log_h),
    # first differences: does the year-to-year change in the ratio track the
    # change in the homicide rate? (removes common trends)
    r_diff = cor(diff(log_sr), diff(log_h)),
    comp_mean = mean(comp_mean),
    comp_diff = mean(comp_diff),
    .by = c(cod_dpto, dpto, period)
  ) |>
  mutate(caribe = cod_dpto %in% cod_caribe)

write_csv(r_dept, "output/tables/underreg_dept_correlations.csv")

print(r_dept |> arrange(period, r_levels), n = 80)

# rank correlation across departments: r vs completeness
tests <-
  r_dept |>
  group_by(period) |>
  summarise(
    n_dept = n(),
    rho_r_vs_comp = cor(r_levels, comp_mean, method = "spearman"),
    rho_r_vs_absdiff = cor(r_levels, abs(comp_diff), method = "spearman"),
    rho_rdiff_vs_comp = cor(r_diff, comp_mean, method = "spearman", use = "complete.obs"),
    .groups = "drop"
  )
cat("\nacross-department rank correlations (hypothesis: positive, negative, positive pre-1998; ~0 post):\n")
print(tests)

for (p in c("pre", "post")) {
  d <- r_dept |> filter(period == p)
  m <- lm(r_levels ~ comp_mean, data = d)
  cat(sprintf(
    "\n%s-1998: r = %.2f + %.2f * completeness   (slope p = %.3f, R2 = %.2f, n = %d)\n",
    p, coef(m)[1], coef(m)[2], summary(m)$coefficients[2, 4], summary(m)$r.squared, nrow(d)
  ))
}

r_dept |>
  ggplot(aes(comp_mean, r_levels, col = caribe)) +
  geom_point(size = 2) +
  geom_smooth(method = "lm", se = FALSE, col = "grey30", linewidth = 0.5) +
  facet_wrap(~ factor(period, c("pre", "post"), c("1985-1997", "1998-2017"))) +
  scale_color_manual(values = c("TRUE" = "#CA6702", "FALSE" = "grey50"), labels = c("TRUE" = "Caribe", "FALSE" = "resto")) +
  labs(
    title = "Correlation of log sex ratio with log homicide rate vs registration completeness",
    subtitle = "one point per department; completeness = mean of male and female GGB-anchored index",
    x = "mean completeness", y = "correlation (levels)", col = NULL
  ) +
  theme_bw() +
  theme(legend.position = "bottom")
ggsave("figures/underreg_corr_vs_completeness.png", w = 9, h = 4.5)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# (c) within-department, across years: pooled regression ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# log homicide rate on log sex ratio with department fixed effects, slope
# allowed to vary with completeness. the interaction is the test: if
# under-registration is what degrades the signal, the slope on the sex ratio
# increases with completeness.

dep2 <- dep |> mutate(comp_c = comp_mean - mean(comp_mean))

m0 <- lm(log_h ~ log_sr + factor(cod_dpto), data = dep2)
m1 <- lm(log_h ~ log_sr * comp_c + comp_diff + factor(cod_dpto), data = dep2)
m2 <- lm(log_h ~ log_sr * comp_c + comp_diff + factor(cod_dpto), data = dep2 |> filter(year < brk))

cat("\nfixed-effects models (department dummies not shown)\n")
cat("all years, no completeness:      slope(log_sr) =", round(coef(m0)["log_sr"], 2), " R2 =", round(summary(m0)$r.squared, 3), "\n")
print(round(summary(m1)$coefficients[c("log_sr", "comp_c", "comp_diff", "log_sr:comp_c"), ], 3))
cat("R2 =", round(summary(m1)$r.squared, 3), "\n")
cat("\nbefore 1998 only\n")
print(round(summary(m2)$coefficients[c("log_sr", "comp_c", "comp_diff", "log_sr:comp_c"), ], 3))
cat("R2 =", round(summary(m2)$r.squared, 3), "\n")

# the deficit in a picture: department-year residuals of log homicide rate
# from the national post-1998 relationship, by completeness bin
cal <- lm(log_h ~ log_sr, data = dep |> filter(year >= brk))
dep$res_cal <- dep$log_h - predict(cal, dep)

dep |>
  mutate(comp_bin = cut(comp_mean, c(0, .4, .6, .8, 1.01), labels = c("<0.4", "0.4-0.6", "0.6-0.8", ">0.8"))) |>
  filter(year < brk) |>
  ggplot(aes(comp_bin, res_cal)) +
  geom_hline(yintercept = 0, lty = "dashed") +
  geom_boxplot(outlier.size = 0.8) +
  labs(
    title = "Pre-1998 prediction error of the post-1998 sex ratio relationship",
    subtitle = "residual of log homicide rate, by department-year completeness",
    x = "completeness (mean of m and f)", y = "log observed - log predicted"
  ) +
  theme_bw()
ggsave("figures/underreg_residual_by_completeness.png", w = 6, h = 4.5)

cat("\nmedian pre-1998 residual by completeness bin:\n")
print(
  dep |>
    filter(year < brk) |>
    mutate(comp_bin = cut(comp_mean, c(0, .4, .6, .8, 1.01))) |>
    summarise(n = n(), median_res = median(res_cal), mean_res = mean(res_cal), .by = comp_bin) |>
    arrange(comp_bin)
)
