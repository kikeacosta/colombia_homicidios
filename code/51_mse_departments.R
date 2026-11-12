# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 51. MSE conflict deaths by department, sex and age, 1985-2018
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# The JEP-CEV-HRDAG multiple-systems estimates are not published by
# department. Two pieces prepared for Acosta et al. (PDR 2025, repository
# colombia_bereavement_pdr on the Drive) get close:
#
#   regional draws   LCMCR estimates by natural region (Amazon, Andean,
#                    Caribbean, Orinoco, Pacific; data_input/regions.csv of
#                    that repository maps the 33 departments), year and
#                    violation, disaggregated by sex and 5-year age with the
#                    documented pattern: 10 replicates x 1,000 draws
#                    (data_inter/mse_draws/region-year-age-sex, the same
#                    files 21 summarises nationally)
#   replicates       the 10 verdata replicates of the homicide and enforced
#                    disappearance victims (data_input/verdata, version 2),
#                    with the department of the event
#
# Department estimate = regional MSE mean (year, sex, age) x the department's
# share of the DOCUMENTED conflict victims of its region in that year
# (mean over the 10 replicates). ASSUMPTION: within a region and year the
# under-documentation is the same in every department. The alternative,
# LCMCR by department-year (33 x 34 x 10 replicates x 2 violations = 22,000
# runs), is days of computing and most strata would be too thin.
#
# Then, as nationally (23, 27): the unknown-age artefacts (0-4, 85+) are
# spread over 5-84; the excess homicides are max(MSE - EEVV violent deaths
# of the department, 0) by year, sex and age group; disappearances are
# added whole. Because the max is taken by department, the departmental
# excesses add up to more than the national one: both are CALIBRATED by
# year, sex and age group to the national hom_excess and dsp of 27, so the
# departmental series is a distribution of the national series.
#
# selection of the records, as in the source pipeline (02_stratify.R):
#   homicides        is_conflict
#   disappearances   is_conflict & is_forced_dis, not matched to a homicide
#
# The replicates and draws are read once and cached in data_input/conflict/
# (the Drive paths are only needed to rebuild the cache).
#
# output: data_input/conflict/mse_documented_dept_1985-2018.csv (cache)
#         data_input/conflict/mse_regional_age5_1985-2018.csv (cache)
#         output/tables/mse_departments_1985-2018.csv
#           (cod, year, sex, age, mse_hom, violent, hom_excess, dsp, mse_added)
#         figures/07_departments/dept_mse_allocation.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
source("code/00_setup.R")
library(arrow)
dir.create("figures/07_departments", showWarnings = FALSE)

drive <- "I:/My Drive/gits_drive/colombia_bereavement_pdr"
age_top <- 80
amazon <- c("91", "94", "95", "97", "99")
unit_of <- function(cod) if_else(cod %in% amazon, "9X", cod)
regions <- read_csv(file.path(drive, "data_input/regions.csv"), show_col_types = FALSE) |>
  transmute(cod = sprintf("%02d", dept_code_hecho), region)

# ---- documented conflict victims by department and year, 10 replicates ----
f_doc <- "data_input/conflict/mse_documented_dept_1985-2018.csv"
if (!file.exists(f_doc)) {
  reps <- read_csv(file.path(drive, "data_inter/selected-replicates.csv"), show_col_types = FALSE)$rep[1:10]
  cols <- c("replica", "match_group_id", "dept_code_hecho", "yy_hecho", "is_conflict", "is_forced_dis")
  read_rep <- function(violation, r) {
    f <- file.path(drive, "data_input/verdata", sprintf("verdata-%s-R%d.csv", violation, r))
    fread(f, select = intersect(cols, names(fread(f, nrows = 0))))
  }
  doc <- map_dfr(reps, function(r) {
    h <- read_rep("homicidio", r)[is_conflict == TRUE]
    d <- read_rep("desaparicion", r)[is_conflict == TRUE & is_forced_dis == TRUE & !match_group_id %in% h$match_group_id]
    rbind(h[, .(replica, dept_code_hecho, year = yy_hecho, violation = "hom")],
          d[, .(replica, dept_code_hecho, year = yy_hecho, violation = "dsp")])
  }) |>
    filter(year >= 1985, year <= 2018) |>
    count(replica, violation, cod = sprintf("%02d", dept_code_hecho), year, name = "n") |>
    summarise(documented = mean(n), .by = c(violation, cod, year))
  write_csv(doc, f_doc)
}
doc <- read_csv(f_doc, show_col_types = FALSE, col_types = cols(cod = "c"))
cat("documented conflict victims (mean of 10 replicates), 1985-2018:\n")
print(doc |> summarise(n = round(sum(documented)), .by = violation))

# ---- regional MSE means by year, sex and age ----
f_reg <- "data_input/conflict/mse_regional_age5_1985-2018.csv"
if (!file.exists(f_reg)) {
  pq <- list.files(file.path(drive, "data_inter/mse_draws/region-year-age-sex"), pattern = "parquet$", full.names = TRUE)
  reg <- open_dataset(pq, format = "parquet") |>
    filter(region != "National") |>
    summarise(mean = mean(N), .by = c(violation, region, year, sex, age5y)) |>
    collect() |>
    mutate(violation = recode(violation, DESAPARICION = "dsp", HOMICIDIO = "hom"), sex = recode(sex, HOMBRE = "m", MUJER = "f"),
           age = as.integer(str_extract(age5y, "^\\d+"))) |>
    select(violation, region, year, sex, age, mean) |> arrange(violation, region, year, sex, age)
  write_csv(reg, f_reg)
}
reg <- read_csv(f_reg, show_col_types = FALSE)
# check against the national summary of 21
nat21 <- read_rds("data_input/conflict/mse_national_age5_1985-2018.rds") |> summarise(national = sum(mean), .by = violation)
print(reg |> summarise(regions = round(sum(mean)), .by = violation) |> left_join(nat21 |> mutate(national = round(national)), by = "violation"))

# unknown-age artefacts spread over 5-84, then 80+ folded, as in 27
reg <- reg |>
  mutate(known = !age %in% c(0, 85, 90, 95)) |>
  mutate(mean = if_else(known, mean * sum(mean) / sum(mean[known]), 0), .by = c(violation, region, year, sex)) |>
  filter(known) |> mutate(age = pmin(age, age_top)) |>
  summarise(mse = sum(mean), .by = c(violation, region, year, sex, age))

# ---- departments: regional MSE x documented share within the region ----
share <- doc |> left_join(regions, by = "cod") |>
  mutate(share = documented / sum(documented), .by = c(violation, region, year)) |>
  select(violation, cod, region, year, share)
stopifnot(!anyNA(share$region))
dept <- share |> inner_join(reg, by = c("violation", "region", "year"), relationship = "many-to-many") |>
  transmute(violation, cod = unit_of(cod), year, sex, age, mse = mse * share) |>
  summarise(mse = sum(mse), .by = c(violation, cod, year, sex, age))

# ---- excess over the EEVV violent deaths of the department, calibrated to 27 ----
viol <- read_parquet("output/deaths_pop_munic_age_1985_2023.parquet") |>
  filter(!is.na(age), year <= 2018) |>
  transmute(cod = unit_of(cod_dpto), year, sex, age = pmin(age, age_top), v = dx_homicide + dx_undetermined + dx_legal) |>
  summarise(violent = sum(v), .by = c(cod, year, sex, age))
nat27 <- read_csv("output/tables/deaths_expected_wpp_mse_1950-2023.csv", show_col_types = FALSE) |>
  filter(year >= 1985, year <= 2018) |> select(year, sex, age, hom_excess_nat = hom_excess, dsp_nat = dsp)
out <- expand_grid(cod = unique(viol$cod), year = 1985:2018, sex = c("m", "f"), age = c(5 * (1:16))) |>
  left_join(dept |> filter(violation == "hom") |> select(cod, year, sex, age, mse_hom = mse), by = c("cod", "year", "sex", "age")) |>
  left_join(dept |> filter(violation == "dsp") |> select(cod, year, sex, age, dsp_raw = mse), by = c("cod", "year", "sex", "age")) |>
  left_join(viol, by = c("cod", "year", "sex", "age")) |>
  mutate(across(c(mse_hom, dsp_raw, violent), function(v) replace_na(v, 0)), excess_raw = pmax(mse_hom - violent, 0)) |>
  left_join(nat27, by = c("year", "sex", "age")) |>
  mutate(k_hom = replace(hom_excess_nat / sum(excess_raw), !is.finite(hom_excess_nat / sum(excess_raw)), 0),
         k_dsp = replace(dsp_nat / sum(dsp_raw), !is.finite(dsp_nat / sum(dsp_raw)), 0), .by = c(year, sex, age)) |>
  mutate(hom_excess = excess_raw * k_hom, dsp = dsp_raw * k_dsp, mse_added = hom_excess + dsp) |>
  select(cod, year, sex, age, mse_hom, violent, excess_raw, k_hom, hom_excess, dsp, mse_added) |>
  arrange(cod, year, sex, age)
chk <- out |> summarise(hom_excess = sum(hom_excess), dsp = sum(dsp), .by = c(year, sex, age)) |> inner_join(nat27, by = c("year", "sex", "age"))
stopifnot(max(abs(chk$hom_excess - chk$hom_excess_nat)) < 1e-6, max(abs(chk$dsp - chk$dsp_nat)) < 1e-6)
write_csv(out, "output/tables/mse_departments_1985-2018.csv")

cat("\ncalibration of the departmental excess homicides to the national series (sum of departmental max / national), by year:\n")
print(out |> summarise(k = sum(hom_excess) / sum(excess_raw), .by = year) |> mutate(k = round(k, 2)) |> filter(year %% 3 == 0) |> as.data.frame())

# ---- the allocation against the EEVV key used before ----
tot <- out |> summarise(mse_added = sum(mse_added), violent = sum(violent), .by = cod)
eevv_key <- out |> mutate(w = violent / sum(violent), .by = c(year)) |>
  left_join(out |> summarise(nat_added = sum(mse_added), .by = year), by = "year") |>
  summarise(eevv_alloc = sum(w * nat_added), .by = cod)
names_tab <- read_parquet("output/deaths_pop_munic_age_1985_2023.parquet") |> distinct(cod_dpto, dpto) |>
  transmute(cod = unit_of(cod_dpto), unit = if_else(cod == "9X", "Amazonía (5 deptos)", dpto)) |> distinct() |>
  mutate(unit = sub("Archipiélago de San Andrés.*", "San Andrés", unit), unit = sub("Bogotá, D.C.", "Bogotá", unit, fixed = TRUE))
cmp <- tot |> left_join(eevv_key, by = "cod") |> left_join(names_tab, by = "cod") |>
  mutate(pct_of_violent = 100 * mse_added / violent)
cat("\nMSE deaths added 1985-2018 by department: regional MSE x documented share, against the EEVV-proportional key (thousands), and as % of the EEVV violent deaths:\n")
print(cmp |> transmute(unit, mse = round(mse_added / 1e3, 1), eevv_key = round(eevv_alloc / 1e3, 1), pct_of_violent = round(pct_of_violent)) |> arrange(-mse) |> as.data.frame())
p <- cmp |> select(unit, `MSE regional x documentados` = mse_added, `Proporcional a las violentas EEVV` = eevv_alloc) |>
  pivot_longer(-unit, names_to = "key", values_to = "deaths") |>
  mutate(unit = factor(unit, cmp$unit[order(cmp$mse_added)])) |>
  ggplot(aes(deaths / 1e3, unit, fill = key)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.75) +
  scale_fill_manual(values = c("#1f5fa6", "#9ecae1"), name = NULL) +
  labs(x = "Muertes del conflicto añadidas al registro, 1985-2018 (miles)", y = NULL,
       title = "Muertes del conflicto que faltan en el registro, por departamento",
       subtitle = "MSE regional (JEP-CEV-HRDAG) por la participación documentada de cada departamento,
frente al reparto proporcional a las violentas registradas") +
  theme_minimal(base_size = 10) + theme(legend.position = "bottom", panel.grid.minor = element_blank())
ggsave("figures/07_departments/dept_mse_allocation.png", p, width = 9, height = 7, bg = "white", dpi = 150)
cat("written: output/tables/mse_departments_1985-2018.csv, figures/07_departments/dept_mse_allocation.png\n")
