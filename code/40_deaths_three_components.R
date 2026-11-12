# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 40. Registered deaths in three components, by sex and age, 1950-2023
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# First step of the component-wise adjustment of mortality: the registered
# deaths are split into
#
#   natural         everything that is not an external cause, including the
#                   ill-defined causes (27 % of the deaths in 1953, 8-15 % in
#                   1979-1985, 2 % from 2000), which are kept here on the
#                   usual assumption that they are natural deaths
#   other external  accidents, suicide and the rest of the external causes
#   violent         homicide, undetermined intent, legal intervention and
#                   operations of war (this project's dx_v)
#
# sources of the cause shares, by year
#   1953-1967   WHO Mortality Database, ICD-7 list A: external A138-A150,
#               violent A149, ill-defined A136-A137
#   1968-1977   WHO, ICD-8 list A: external A138-A150, violent A148-A149;
#               1970 only has list B: external B047-B050, violent B050 ("all
#               other external causes"), ill-defined B045
#   1979-2023   DANE microdata, list 105: external 90-105, violent 101-103,
#               ill-defined 89
#   1950-1952, 1971, 1973, 1978: no cause detail; the shares are interpolated
#               on the logit scale by sex and age (held at 1953 before it)
# Deaths of unknown age are spread proportionally within year, sex and
# component. The shares are applied to the registered deaths by age of 22
# (the series used everywhere else), so the three components add up to it.
#
# output: data_input/reference/who_causes_age_colombia_1953-1977.csv
#         output/tables/deaths_components_registered_1950-2023.csv
#         figures/06_components/components_shares.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
source("code/00_setup.R")
dir.create("figures/06_components", showWarnings = FALSE)

grp <- \(a) case_when(a == 0 ~ 0, a < 5 ~ 1, TRUE ~ pmin(5 * (a %/% 5), 80))
comps <- c("natural", "other_external", "violent")

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# WHO, 1953-1977 ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
f_who <- "data_input/reference/who_causes_age_colombia_1953-1977.csv"
keep <- c("A000", paste0("A", 136:150), "B000", "B045", paste0("B0", 47:50))
if (!file.exists(f_who)) {
  read_who <- function(zipf, member) {
    x <- fread(text = readLines(unz(zipf, member)), colClasses = list(character = c("Admin1", "SubDiv", "List", "Cause", "Frmat", "IM_Frmat")))
    x[Country == 2130 & Cause %in% keep]
  }
  rbind(read_who("data_input/who_mdb/morticd07.zip", "MortIcd7"), read_who("data_input/who_mdb/morticd08.zip", "Morticd8"), fill = TRUE) |>
    fwrite(f_who)
}
# age columns of the WHO formats 01 and 02 (as in 21): column -> lower age
who_cols <- c(setNames(2, 0), setNames(3:6, rep(1, 4)), setNames(7:22, seq(5, 80, 5)), setNames(23, 85), setNames(26, NA))
who <-
  read_csv(f_who, show_col_types = FALSE, col_types = cols(List = "c", Cause = "c", Frmat = "c", .default = col_guess())) |>
  filter(Sex %in% 1:2) |>
  mutate(icd = case_when(List == "07A" ~ 7, TRUE ~ 8),
         what = case_when(Cause %in% c("A000", "B000") ~ "all",
                          Cause %in% c("A136", "A137", "B045") ~ "ill_defined",
                          (icd == 7 & Cause == "A149") | (List == "08A" & Cause %in% c("A148", "A149")) | Cause == "B050" ~ "violent",
                          TRUE ~ "other_external")) |>
  select(year = Year, Sex, what, num_range("Deaths", 1:26)) |>
  pivot_longer(starts_with("Deaths"), names_to = "col", values_to = "dx", names_prefix = "Deaths", names_transform = as.integer) |>
  filter(col %in% who_cols) |>
  mutate(sex = if_else(Sex == 1, "m", "f"), age = as.numeric(names(who_cols)[match(col, who_cols)])) |>
  replace_na(list(dx = 0)) |>
  summarise(dx = sum(dx), .by = c(year, sex, what, age)) |>
  mutate(unk = sum(dx[is.na(age)]), tot = sum(dx[!is.na(age)]), .by = c(year, sex, what)) |>
  filter(!is.na(age)) |>
  mutate(dx = if_else(tot > 0, dx * (1 + unk / tot), dx), age = grp(age)) |>
  summarise(dx = sum(dx), .by = c(year, sex, what, age)) |>
  pivot_wider(names_from = what, values_from = dx, values_fill = 0) |>
  mutate(src = "WHO")

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DANE microdata, 1979-2023 ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
micro <-
  read_rds("data_inter/micro_1979_2023.rds") |>
  as_tibble() |>
  filter(sexo %in% c("m", "f")) |>
  mutate(what = case_when(cod_col %in% codes_violent ~ "violent", cod_col %in% codes_external ~ "other_external", TRUE ~ "natural_all"),
         ill = cod_col %in% codes_ill_defined) |>
  count(year = ano, sex = sexo, what, ill, age = edad, name = "dx")
eevv <-
  bind_rows(micro |> summarise(dx = sum(dx), .by = c(year, sex, what, age)),
            micro |> filter(ill) |> summarise(dx = sum(dx), .by = c(year, sex, age)) |> mutate(what = "ill_defined")) |>
  mutate(unk = sum(dx[is.na(age)]), tot = sum(dx[!is.na(age)]), .by = c(year, sex, what)) |>
  filter(!is.na(age)) |>
  mutate(dx = if_else(tot > 0, dx * (1 + unk / tot), dx), age = grp(age)) |>
  summarise(dx = sum(dx), .by = c(year, sex, what, age)) |>
  pivot_wider(names_from = what, values_from = dx, values_fill = 0) |>
  mutate(all = natural_all + other_external + violent, src = "DANE") |>
  select(-natural_all)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# shares, interpolation and application to the registered series ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
reg <- read_csv("output/tables/deaths_expected_wpp_mse_1950-2023.csv", show_col_types = FALSE) |> select(year, sex, age, pop, registered)

lg <- \(p) qlogis(pmin(pmax(p, 1e-5), 1 - 1e-5))
fill <- \(year, p) if (all(is.na(p))) p else plogis(approx(year[!is.na(p)], lg(p[!is.na(p)]), xout = year, rule = 2)$y)
shares <-
  bind_rows(who, eevv) |>
  transmute(year, sex, age, src, p_ext = (other_external + violent) / all, p_viol_ext = if_else(other_external + violent > 0, violent / (other_external + violent), NA),
            p_ill = ill_defined / all) |>
  right_join(reg, by = c("year", "sex", "age")) |>
  arrange(sex, age, year) |>
  mutate(src = replace_na(src, "interpolado"),
         p_ext = fill(year, p_ext), p_viol_ext = fill(year, p_viol_ext), p_ill = fill(year, p_ill), .by = c(sex, age))

out <-
  shares |>
  transmute(year, sex, age, pop, registered,
            natural = registered * (1 - p_ext),
            other_external = registered * p_ext * (1 - p_viol_ext),
            violent = registered * p_ext * p_viol_ext,
            ill_defined = registered * p_ill, shares_source = src) |>
  arrange(year, sex, age)
stopifnot(all(abs(out$natural + out$other_external + out$violent - out$registered) < 1e-6))
write_csv(out, "output/tables/deaths_components_registered_1950-2023.csv")

cat("registered deaths by component, thousands (both sexes), and share of ill-defined in all deaths:\n")
print(out |> filter(year %in% c(1950, 1953, 1960, 1970, 1975, 1980, 1985, 1990, 2000, 2010, 2018, 2021)) |>
        summarise(ill_pct = round(100 * sum(ill_defined) / sum(registered), 1), across(c(registered, natural, other_external, violent), \(v) round(sum(v) / 1e3, 1)),
                  source = first(shares_source), .by = year) |> relocate(ill_pct, .after = violent) |> as.data.frame())

# check against the violent deaths already used by 30 (WHO A149 / A148-A149 and dx_v)
v30 <- read_csv("output/tables/deaths_by_cause_sex_age_1953-2023.csv", show_col_types = FALSE) |> summarise(v30 = sum(violent_reg), .by = year)
cmp30 <- out |> filter(shares_source != "interpolado") |> summarise(v = sum(violent), .by = year) |> inner_join(v30, by = "year") |>
  mutate(rel = v / v30 - 1)
cat("\nviolent deaths here against script 30 (which interpolates 1970 and scales nothing): years differing by more than 1 %:\n")
print(cmp30 |> filter(abs(rel) > 0.01) |> mutate(v = round(v), v30 = round(v30), rel = round(rel, 3)) |> as.data.frame())

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# figure ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
lab_sex <- \(s) factor(s, c("m", "f"), c("Hombres", "Mujeres"))
band <- \(a) cut(a, c(-1, 4, 14, 44, 64, Inf), c("0-4", "5-14", "15-44", "45-64", "65+"))
comp_cols <- c("Natural" = "#2a78d6", "Otras externas" = "#eda100", "Violenta" = "#eb6834")
nodata <- tibble(xmin = c(1949.5, 1970.5, 1972.5, 1977.5), xmax = c(1952.5, 1971.5, 1973.5, 1978.5))
out |>
  mutate(band = band(age), sex = lab_sex(sex)) |>
  summarise(Natural = sum(natural), `Otras externas` = sum(other_external), Violenta = sum(violent), .by = c(year, sex, band)) |>
  pivot_longer(c(Natural, `Otras externas`, Violenta), names_to = "comp", values_to = "dx") |>
  mutate(share = dx / sum(dx), .by = c(year, sex, band)) |>
  filter(comp != "Natural") |>
  ggplot() +
  geom_rect(data = nodata, aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf), fill = "grey50", alpha = 0.12) +
  geom_line(aes(year, share, col = comp), linewidth = 0.8) +
  facet_grid(sex ~ band) +
  scale_color_manual(values = comp_cols[-1]) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
  scale_x_continuous(breaks = seq(1960, 2020, 20)) +
  labs(title = "Defunciones registradas por causas externas como proporción del total, por sexo y edad, Colombia 1950-2023",
       subtitle = "El resto son muertes naturales (incluidas las mal definidas). Franjas grises: años sin detalle de causa, proporciones interpoladas",
       x = NULL, y = "% de las defunciones registradas", col = NULL) +
  theme_bw(base_size = 11) +
  theme(panel.grid.minor = element_blank(), panel.grid.major = element_line(colour = "grey92"), legend.position = "bottom",
        strip.background = element_rect(fill = "grey96", colour = NA), plot.title = element_text(size = 12, face = "bold"),
        plot.subtitle = element_text(size = 9.5, colour = "#52514e"))
ggsave("figures/06_components/components_shares.png", w = 14, h = 7, bg = "white")
