# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 91. Spain 1939-1943: is the male excess of the postwar years at ages 15-44
#     (violence, repression) or spread over all ages (hunger, typhus)?
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# In 1940-1942 the excess of male deaths over the pre-war sex ratio (H of 80,
# ~95,000) is well above the violence registered as such (28,000-64,000).
# The rest is either hunger and typhus killing more men than women, which
# the method reads as violence, or repression registered under other causes
# (prison deaths, executions written as natural deaths). The two differ by
# age: executions and prison deaths fall mostly on men of 20-50, hunger and
# epidemics on children and the old.
# Here the same estimator runs at ages 15-44 only, with the pre-war ratio of
# those ages (1933 and 1935; 1934 is left out, the Asturias revolt), and is
# set against the estimate for all ages with the same base years:
#   H_1544 = (M - rho F) / (pi - rho (1 - pi)) at ages 15-44, pi = 0.95
#   share  = H_1544 / H_all, the part of the male excess at ages 15-44
# 1939 (the war ends in April, many war deaths registered late) and 1943
# (violence low) frame 1940-1942.
# caveat (blind test, 82): in Colombia the non-violent sex ratio at 15-44
# moved by 20-30 % in 25 years for other reasons; here the horizon is 4-10
# years, but hunger can also raise the deaths of young men (prisons,
# conscripts, forced labour), which this test counts at 15-44.
#
# input    data_input/reference/spain_ine_deaths_province_sex_age15-44_provisional.csv
#            (PROVISIONAL: digitised by the Spain data session, 2026-11-25; every
#            column adds up to its printed total; second reading pending)
#          data_input/reference/spain_ine_deaths_province_sex_1926-1946.csv
#          output/tables/intl_spain_causes_check.csv (83)
# output   output/tables/intl_spain_ages_15_44_national.csv
#          output/tables/intl_spain_ages_15_44_provinces.csv
#          figures/09_international/spain_ages_15_44.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
rm(list = ls()); gc(); source("code/00_setup.R")
options(width = 200)
pi_m <- 0.95
base_yrs <- c(1933, 1935)
H <- function(m, f, r) (m - r * f) / (pi_m - r * (1 - pi_m))

a <- read_csv("data_input/reference/spain_ine_deaths_province_sex_age15-44_provisional.csv", show_col_types = FALSE,
              col_types = cols(province_code = col_character())) |>
  summarise(d = sum(deaths), .by = c(year, province_code, sex)) |> pivot_wider(names_from = sex, values_from = d) |>
  rename(m15 = male, f15 = female)
t <- read_csv("data_input/reference/spain_ine_deaths_province_sex_1926-1946.csv", show_col_types = FALSE, col_types = cols(province_code = col_character())) |>
  filter(!is.na(province_code), !grepl("+", province_code, fixed = TRUE), year %in% unique(a$year)) |>
  select(year, province_code, province, sex, deaths) |> pivot_wider(names_from = sex, values_from = deaths) |>
  rename(m_all = male, f_all = female, d_all = total)
x <- t |> left_join(a, by = c("year", "province_code")) |>
  mutate(m_o = m_all - m15, f_o = f_all - f15)
stopifnot(!anyNA(x$m15))
rho <- x |> filter(year %in% base_yrs) |>
  summarise(r15 = sum(m15) / sum(f15), r_all = sum(m_all) / sum(f_all), r_o = sum(m_o) / sum(f_o), .by = province_code)
x <- x |> left_join(rho, by = "province_code") |>
  mutate(H15 = H(m15, f15, r15), H_all = H(m_all, f_all, r_all), H_o = H(m_o, f_o, r_o))
reg <- read_csv("output/tables/intl_spain_causes_check.csv", show_col_types = FALSE, col_types = cols(province_code = col_character())) |>
  select(year, province_code, violent_reg, homicide_m = homicide_male, homicide_f = homicide_female)
x <- x |> left_join(reg, by = c("year", "province_code"))

nat <- x |> filter(!year %in% base_yrs) |>
  summarise(deaths_15_44 = sum(m15 + f15), deaths_all = sum(d_all), H_15_44 = sum(H15), H_other_ages = sum(H_o), H_all = sum(H_all),
            registered_violent = sum(violent_reg), .by = year) |>
  mutate(share_15_44 = H_15_44 / H_all, ratio_15_44_m_f = NA)
# the sex ratio itself, national, to show the shift
sr <- x |> summarise(sr15 = sum(m15) / sum(f15), sr_o = sum(m_o) / sum(f_o), .by = year)
nat <- nat |> select(-ratio_15_44_m_f) |> left_join(sr, by = "year")
write_csv(nat, "output/tables/intl_spain_ages_15_44_national.csv")
cat("== Spain: male excess (violent deaths by the estimator) at ages 15-44 and at the other ages, base 1933 + 1935 ==\n")
print(as.data.frame(nat |> mutate(across(c(H_15_44, H_other_ages, H_all, registered_violent), round), share_15_44 = round(share_15_44, 2),
                                  sr15 = round(sr15, 3), sr_o = round(sr_o, 3))), row.names = FALSE)
cat("pre-war (1933, 1935) national sex ratio of deaths: 15-44", round(with(x |> filter(year %in% base_yrs), sum(m15) / sum(f15)), 3),
    "| other ages", round(with(x |> filter(year %in% base_yrs), sum(m_o) / sum(f_o)), 3), "\n")

# provinces, 1940-1942
pp <- x |> filter(year %in% 1940:1942) |>
  summarise(H15 = sum(H15), H_o = sum(H_o), H_all = sum(H_all), d = sum(d_all), .by = c(province_code, province)) |>
  mutate(share = H15 / H_all)
write_csv(pp, "output/tables/intl_spain_ages_15_44_provinces.csv")
cat("\n== provinces 1940-1942: male excess at 15-44 and at other ages ==\n")
print(as.data.frame(pp |> arrange(-H_all) |> mutate(across(c(H15, H_o, H_all), round), share = round(share, 2)) |> head(15)), row.names = FALSE)
cat("provinces where the excess at other ages exceeds the one at 15-44, 1940-1942:", sum(pp$H_o > pp$H15), "of", nrow(pp), "\n")

# figure: national by year, the excess at 15-44 and at the other ages
fy <- nat |> select(year, `15-44 años` = H_15_44, `Otras edades` = H_other_ages) |> pivot_longer(-year) |>
  mutate(name = factor(name, c("Otras edades", "15-44 años")))
p1 <- ggplot(fy, aes(factor(year), value / 1000, fill = name)) +
  geom_col(width = 0.65) +
  geom_point(data = nat, aes(factor(year), registered_violent / 1000), inherit.aes = FALSE, shape = 23, size = 3, fill = "white") +
  geom_hline(yintercept = 0, colour = "grey50") +
  scale_fill_manual(values = c(`15-44 años` = "#c0392b", `Otras edades` = "#f2a541"), name = "Exceso de muertes de hombres") +
  labs(title = "España: exceso de muertes de hombres por edad, 1939-1943",
       subtitle = paste0("Muertes de hombres por encima de la razón de sexos de 1933 y 1935, en violentas equivalentes (π = 0,95).\n",
                         "Rombos: violencia registrada como tal
(1941-1942: solo homicidios; la lista abreviada no separa el resto)."),
       x = NULL, y = "miles") +
  theme_minimal(base_size = 10) + theme(legend.position = "bottom", panel.grid.minor = element_blank(), plot.title = element_text(face = "bold"))
p2 <- ggplot(pp, aes(pmax(H15, 10), pmax(H_o, 10))) +
  geom_abline(slope = 1, intercept = 0, colour = "grey60", linetype = "22") +
  geom_point(colour = "#2a78d6", size = 1.6) +
  ggrepel::geom_text_repel(aes(label = province), size = 2.4, colour = "grey30", max.overlaps = 15) +
  scale_x_log10(labels = scales::comma) + scale_y_log10(labels = scales::comma) +
  labs(title = "Por provincia, 1940-1942", subtitle = "Exceso de hombres a 15-44 años frente al de las demás edades.\nValores negativos o menores que 10 se dibujan en 10.",
       x = "15-44 años", y = "otras edades") +
  theme_minimal(base_size = 10) + theme(panel.grid.minor = element_blank(), plot.title = element_text(face = "bold"))
fig <- ggpubr::ggarrange(p1, p2, ncol = 2, widths = c(1.1, 1))
ggsave("figures/09_international/spain_ages_15_44.png", fig, w = 13, h = 6, bg = "white", dpi = 160)
