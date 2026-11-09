# data coverage

rm(list = ls())
gc()
source("code/00_setup.R")

# loading data from historical series (col_gap_analysis transcriptions of the
# DANE anuarios; the v01/v02 files they replace are in
# data_input/historical/archive_v01_v02/). Columns are renamed to the names
# of the old files so the rest of the script is unchanged. Departmental
# deaths use the territories_aggregated variant (25 units, intendencias and
# comisarias summed into their department of origin). Its yearly totals match
# the national file except in 1926, 1931, 1932 and 1934 (national total
# lower than the departmental sum) and 1956-1961 (Bogota appears as its own
# row while still included in Cundinamarca, so the sum double counts it).
hist_dir <- "data_input/historical/"
read_hist <- function(file, prefix, delim = ",") {
  read_delim(paste0(hist_dir, "col_gap_analysis_1920_1985_", file), delim = delim,
             show_col_types = FALSE, guess_max = 1e5) |>
    mutate(department = str_to_upper(department)) |>
    rename_with(~ paste0(prefix, "_", .x), any_of(c("total", "male", "female")))
}

hms_dto <- read_hist("department_homicides_clean_v02.csv", "homicide")
hms_nal <-
  hms_dto |>
  summarise(across(c(homicide_total, homicide_male, homicide_female), ~ sum(.x, na.rm = TRUE)),
            n_dept_with_data = sum(!is.na(homicide_total)), .by = year) |>
  mutate(across(c(homicide_total, homicide_male, homicide_female), ~ if_else(n_dept_with_data > 0, .x, NA))) |>
  filter(n_dept_with_data > 0) |>
  arrange(year)

dts_mun <- read_hist("municipal_deaths_clean_v03.csv", "deaths")
dts_dto <- read_hist("department_deaths_clean_v06_territories_aggregated.csv", "deaths", delim = ";")

pop_mun <- read_hist("municipal_population_clean_v03.csv", "pop")
pop_dto <- read_hist("department_population_clean_v03.csv", "pop", delim = ";")

# loading WHO data for Colombia
hms_who <- read_csv("data_input/reference/who/who_homicide_colombia.csv")
dts_who <- read_csv("data_input/reference/who/who_all_cause_colombia.csv")

hms_who2 <-
  hms_who |>
  bind_rows(
    hms_who |>
      summarise(hms = sum(hms), .by = year) |>
      mutate(sex = "t")
  ) |>
  arrange(year, sex)

hms_nal2 <-
  hms_nal |>
  select(year, homicide_total, homicide_male, homicide_female) |>
  gather(-year, key = "sex", value = "hms") |>
  mutate(sex = str_remove(sex, "homicide_") |> str_sub(1, 1)) |>
  arrange(year, sex)

unique(hms_nal2$year)
unique(hms_who2$year)

# merging historical series and WHO (WHO starting in 1966)
hms_nal3 <-
  hms_nal2 |>
  bind_rows(
    hms_who2 |>
      filter(year >= 1966)
  ) |>
  arrange(year, sex)

unique(hms_nal2$year)
unique(hms_who2$year)

# plotting
hms_nal3 |>
  ggplot() +
  geom_point(aes(year, hms, color = sex)) +
  geom_line(aes(year, hms, color = sex)) +
  scale_x_continuous(breaks = seq(1920, 2020, by = 10)) +
  scale_y_continuous(breaks = seq(0, 30e3, by = 5e3)) +
  labs(x = "Year", y = "Homicides", color = "Sex") +
  theme_minimal()
ggsave("figures/historical/homicides_colombia.png", width = 10, height = 6)

hms_nal3 |>
  select(year) |>
  unique() |>
  pull()

# years with missing all information
yrs_mss <-
  tibble(year = 1923:2023) |>
  left_join(
    hms_nal3 |>
      filter(sex == "t"),
    by = join_by(year)
  ) |>
  filter(is.na(hms)) |>
  pull(year)

yrs_mss

# verifying, using WHO data since 1953
hms_nal3 <-
  hms_nal2 |>
  filter(year <= 1952) |>
  bind_rows(
    hms_who2
  ) |>
  arrange(year, sex)

unique(hms_nal2$year)
unique(hms_who2$year)

hms_nal3 |>
  ggplot() +
  geom_point(aes(year, hms, color = sex)) +
  geom_line(aes(year, hms, color = sex)) +
  scale_x_continuous(breaks = seq(1920, 2020, by = 10)) +
  scale_y_continuous(breaks = seq(0, 30e3, by = 5e3)) +
  labs(x = "Year", y = "Homicides", color = "Sex") +
  theme_minimal()

# data availability for departments (historical series)
tst <-
  hms_dto |>
  select(department, year, starts_with("homicide")) |>
  gather(-year, -department, key = "sex", value = "hms") |>
  mutate(sex = str_remove(sex, "homicide_") |> str_sub(1, 1)) |>
  arrange(year, sex)

tst |>
  filter(sex == "t") |>
  drop_na() |>
  ggplot() +
  # facet_grid(~sex)+
  geom_tile(aes(year, department, fill = hms)) +
  scale_fill_viridis_c() +
  scale_x_continuous(breaks = seq(1920, 2020, by = 5)) +
  labs(x = "Year", y = "Department", fill = "Homicides") +
  theme_minimal()

ggsave("figures/historical/homicides_department.png", width = 10, height = 6)

# municipality
tst_mun <-
  dts_mun |>
  select(department, municipality, year, starts_with("deaths")) |>
  gather(-year, -department, -municipality, key = "sex", value = "hms") |>
  mutate(sex = str_remove(sex, "deaths_") |> str_sub(1, 1)) |>
  arrange(year, sex)

tst_mun |>
  filter(sex == "t") |>
  drop_na() |>
  ggplot() +
  facet_grid(department ~ ., scales = "free_y", space = "free") +
  geom_tile(aes(year, municipality, fill = hms)) +
  scale_fill_viridis_c() +
  scale_x_continuous(breaks = seq(1920, 2020, by = 5)) +
  labs(x = "Year", y = "Municipality", fill = "Homicides") +
  theme_minimal()

ggsave(
  "figures/historical/homicides_municipal.png",
  width = 10,
  height = 100,
  limitsize = FALSE
)

# proportions of municipalities at the department level reporting data by year
muns_dto <-
  tst_mun |>
  filter(sex == "t") |>
  select(department, municipality) |>
  unique() |>
  summarise(n = n(), .by = department)

tsttst <-
  tst_mun |>
  filter(sex == "t") |>
  drop_na() |>
  summarise(n_info = n(), .by = c(year, department)) |>
  left_join(muns_dto) |>
  mutate(prop = n_info / n)


tsttst |>
  ggplot() +
  # facet_grid(department ~ ., scales = "free_y", space = "free") +
  geom_tile(aes(year, department, fill = prop)) +
  scale_fill_viridis_c() +
  scale_x_continuous(breaks = seq(1920, 2020, by = 5)) +
  labs(x = "Year", y = "Municipality", fill = "Homicides") +
  theme_minimal()
ggsave(
  "figures/historical/homicides_department_props.png",
  width = 10,
  height = 6
)


# plotting nacional and municipal data availability
props_nal <-
  tsttst |>
  summarise(n_info = sum(n_info), n = sum(n), .by = c(year)) |>
  mutate(prop = 30000 * (n_info / n))

hms_nal3 |>
  ggplot() +
  geom_point(aes(year, hms, color = sex)) +
  geom_line(aes(year, hms, color = sex)) +
  geom_point(data = props_nal, aes(year, prop), col = "black") +
  geom_vline(xintercept = 1979, linetype = 2) +
  geom_vline(xintercept = 1936, linetype = 2) +
  geom_vline(xintercept = 1958, linetype = 2) +
  geom_vline(xintercept = min(props_nal$year), linetype = 2) +
  geom_vline(xintercept = max(props_nal$year), linetype = 2) +
  annotate(
    "rect",
    xmin = 1937,
    xmax = 1957,
    ymin = -Inf,
    ymax = Inf,
    fill = "skyblue",
    alpha = 0.4
  ) +
  annotate(
    "rect",
    xmin = 1961,
    xmax = 1978,
    ymin = -Inf,
    ymax = Inf,
    fill = "skyblue",
    alpha = 0.4
  ) +
  scale_x_continuous(breaks = seq(1920, 2020, by = 10)) +
  scale_y_continuous(breaks = seq(0, 30e3, by = 5e3)) +
  labs(x = "Year", y = "Homicides", color = "Sex") +
  theme_minimal()
ggsave(
  "figures/historical/homicides_colombia_vdata.png",
  width = 10,
  height = 6
)
