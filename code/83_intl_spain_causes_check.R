# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 83. Spain 1936-1942: the excess-male estimate of violent deaths (80)
#     against the violent causes registered by province and sex
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Registered causes by province and sex, transcribed from the INE volumes
# (data_input/reference/spain_ine_deaths_province_cause_sex_1936-1942.csv):
#   1936-1940, detailed international list: homicide (by firearm, by cutting
#     instrument, other), war wounds and other war items, execution of
#     civilians by the belligerent armies, judicial execution; also violent
#     death of unknown nature, sudden death and ill-defined causes
#   1941-1942, abridged list: 41 homicide, 42 motor accidents, 43 other
#     violent or accidental deaths, 44 ill-defined causes
# Registered violence = homicide + war + executions (1936-1940) or homicide
# (1941-1942; rubric 43 mixes violence with ordinary accidents and is shown
# apart). The registry misses or hides part of the violence (deaths never
# registered, repression registered as other causes), so registered violence
# is a floor; H counts every male death above the pre-war sex ratio.
# Measured here: the share of men among registered violent deaths (pi), H
# against registered violence by year and province, H recomputed with the
# registered pi, and whether the male excess of 1940-1942 shows up in the
# ill-defined causes.
#
# input    data_input/reference/spain_ine_deaths_province_cause_sex_1936-1942.csv
#          output/tables/intl_spain_excess_male_1936-1946.csv (80)
#          data_input/reference/spain_ine_deaths_province_sex_1926-1946.csv
# output   output/tables/intl_spain_causes_check.csv
#          figures/09_international/spain_causes_check.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
rm(list = ls()); gc(); source("code/00_setup.R")
options(width = 220)

ca <- read_csv("data_input/reference/spain_ine_deaths_province_cause_sex_1936-1942.csv", show_col_types = FALSE,
               col_types = cols(province_code = col_character(), item = col_character()))
grp <- function(label, year) case_when(
  grepl("infantic", label, ignore.case = TRUE) ~ "other",
  grepl("homicid", label, ignore.case = TRUE) & !grepl("accidente, homi", label, ignore.case = TRUE) ~ "homicide",
  grepl("guerra|bombard", label, ignore.case = TRUE) ~ "war",
  grepl("ejecuci", label, ignore.case = TRUE) & grepl("civil|beliger", label, ignore.case = TRUE) ~ "execution_civilians",
  grepl("ejecuci", label, ignore.case = TRUE) ~ "execution_judicial",
  grepl("desconocida|violenta cuya", label, ignore.case = TRUE) ~ "violent_unknown",
  grepl("otras muertes violentas", label, ignore.case = TRUE) ~ "other_violent_or_accidental",
  grepl("autom", label, ignore.case = TRUE) ~ "motor_accidents",
  grepl("repentina", label, ignore.case = TRUE) ~ "sudden",
  grepl("no especificad|mal definid|no expresa", label, ignore.case = TRUE) ~ "ill_defined",
  grepl("^total", label, ignore.case = TRUE) ~ "total",
  .default = "other")
ca <- ca |> mutate(group = grp(item_label, year))
cat("== items and their group ==\n")
print(as.data.frame(ca |> filter(province == "TOTALES") |> select(year, item, item_label, group, sex, deaths) |>
                      pivot_wider(names_from = sex, values_from = deaths)), row.names = FALSE)

prov <- ca |> filter(province != "TOTALES")
g <- prov |> summarise(deaths = sum(deaths), .by = c(year, province_code, group, sex)) |>
  pivot_wider(names_from = c(group, sex), values_from = deaths, values_fill = 0)
reg <- g |> mutate(
  violent_reg_m = homicide_male + coalesce(war_male, 0) + coalesce(execution_civilians_male, 0) + coalesce(execution_judicial_male, 0),
  violent_reg_f = homicide_female + coalesce(war_female, 0) + coalesce(execution_civilians_female, 0) + coalesce(execution_judicial_female, 0))

est <- read_csv("output/tables/intl_spain_excess_male_1936-1946.csv", show_col_types = FALSE, col_types = cols(province_code = col_character())) |>
  filter(scenario == "pi = 0.95", year <= 1942) |> select(year, province_code, province, male, female, rho, H, H_lo, H_hi)
cmp <- est |> left_join(reg, by = c("year", "province_code")) |>
  mutate(violent_reg = violent_reg_m + violent_reg_f)
write_csv(cmp, "output/tables/intl_spain_causes_check.csv")

# national, by year
nat <- cmp |> summarise(H = sum(H), H_lo = sum(H_lo), H_hi = sum(H_hi), violent_reg = sum(violent_reg),
                        violent_reg_m = sum(violent_reg_m), violent_reg_f = sum(violent_reg_f),
                        homicide = sum(homicide_male + homicide_female),
                        war = sum(coalesce(war_male, 0) + coalesce(war_female, 0)),
                        executions = sum(coalesce(execution_civilians_male, 0) + coalesce(execution_civilians_female, 0) +
                                           coalesce(execution_judicial_male, 0) + coalesce(execution_judicial_female, 0)),
                        other_violent_m = sum(coalesce(other_violent_or_accidental_male, 0)), other_violent_f = sum(coalesce(other_violent_or_accidental_female, 0)),
                        violent_unknown = sum(coalesce(violent_unknown_male, 0) + coalesce(violent_unknown_female, 0)),
                        ill_defined_m = sum(coalesce(ill_defined_male, 0)), ill_defined_f = sum(coalesce(ill_defined_female, 0)), .by = year) |>
  mutate(pi_reg = violent_reg_m / violent_reg, H_over_reg = H / violent_reg)
cat("\n== Spain, by year: H (excess male deaths) against the violence registered as such ==\n")
print(as.data.frame(nat |> mutate(across(where(is.numeric) & !c(pi_reg, H_over_reg), round), pi_reg = round(pi_reg, 3), H_over_reg = round(H_over_reg, 2))), row.names = FALSE)

# H with the registered share of men of each year (1936-1940)
pi_y <- nat |> filter(year <= 1940) |> select(year, pi_reg)
h2 <- cmp |> left_join(pi_y, by = "year") |> filter(!is.na(pi_reg)) |>
  mutate(H_pireg = (male - rho * female) / (pi_reg - rho * (1 - pi_reg))) |>
  summarise(H = sum(H), H_pireg = sum(H_pireg), violent_reg = sum(violent_reg), .by = year)
cat("\n== H with pi = 0.95 and with the registered share of men ==\n")
print(as.data.frame(h2 |> mutate(across(-year, round))), row.names = FALSE)

# provinces, by period
pp <- cmp |> mutate(period = ifelse(year <= 1939, "1936-1939", "1940-1942")) |>
  summarise(H = sum(H), violent_reg = sum(violent_reg), .by = c(period, province_code, province))
co <- pp |> filter(H > 0, violent_reg > 0) |> summarise(n = n(), pearson_log = round(cor(log(H), log(violent_reg)), 2),
                                                        spearman = round(cor(H, violent_reg, method = "spearman"), 2),
                                                        ratio_total = round(sum(H) / sum(violent_reg), 2), .by = period)
cat("\n== by province: H against registered violence ==\n"); print(as.data.frame(co), row.names = FALSE)
cat("\n== largest gaps, 1936-1939 ==\n")
print(as.data.frame(pp |> filter(period == "1936-1939") |> mutate(ratio = round(H / violent_reg, 2), across(c(H, violent_reg), round)) |>
                      arrange(-abs(log(pmax(ratio, 0.01)))) |> head(12)), row.names = FALSE)

# figure
fl <- nat |> mutate(other_violent = other_violent_m + other_violent_f) |>
  select(year, `excess male deaths (H)` = H, `registered: homicide` = homicide, `registered: war` = war, `registered: executions` = executions,
         `1941-1942: other violent or accidental (includes ordinary accidents)` = other_violent) |>
  pivot_longer(-year)
p1 <- ggplot() +
  geom_col(data = fl |> filter(name != "excess male deaths (H)"), aes(year, value / 1000, fill = name), width = 0.7) +
  geom_errorbar(data = nat, aes(year, ymin = H_lo / 1000, ymax = H_hi / 1000), width = 0.15, colour = "grey30") +
  geom_point(data = nat, aes(year, H / 1000), size = 2.4, colour = "black") +
  scale_fill_manual(values = c(`registered: homicide` = "#f2a541", `registered: war` = "#2a78d6", `registered: executions` = "#c0392b",
                               `1941-1942: other violent or accidental (includes ordinary accidents)` = "grey80"), name = NULL) +
  guides(fill = guide_legend(nrow = 2)) +
  scale_x_continuous(breaks = 1936:1942) +
  labs(title = "Violent deaths registered as such, and the excess of male deaths",
       subtitle = "Bars: registered causes. 1941-1942: abridged list, where violence other than homicide\nis mixed with ordinary accidents (grey). Dots: excess male deaths (80), with its range.",
       x = NULL, y = "thousand deaths") +
  theme_minimal(base_size = 10) + theme(legend.position = "bottom", panel.grid.minor = element_blank(), plot.title = element_text(face = "bold"))
p2 <- ggplot(pp |> filter(H > 0, violent_reg > 0), aes(violent_reg, H)) +
  geom_abline(slope = 1, intercept = 0, colour = "grey60", linetype = "22") +
  geom_point(colour = "#2a78d6", size = 1.6) +
  ggrepel::geom_text_repel(aes(label = province), size = 2.4, colour = "grey30", max.overlaps = 12) +
  scale_x_log10(labels = scales::comma) + scale_y_log10(labels = scales::comma) +
  facet_wrap(~period) +
  labs(title = "By province", subtitle = "Excess male deaths (H) against registered violence. Dashed: equal.", x = "registered violent deaths", y = "H") +
  theme_minimal(base_size = 10) + theme(plot.title = element_text(face = "bold"), panel.grid.minor = element_blank())
fig <- ggpubr::ggarrange(p1, p2, ncol = 2, widths = c(1, 1.3))
ggsave("figures/09_international/spain_causes_check.png", fig, w = 14, h = 6.5, bg = "white", dpi = 160)
