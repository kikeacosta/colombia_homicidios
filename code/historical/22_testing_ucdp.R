rm(list = ls())
source("code/00_setup.R")

# UCDP Georeferenced Event Dataset (GED)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 1989 - 2024
dt1 <- read_csv("data_input/ucdp/GEDEvent_v25_1.csv")
# january - December 2025
dt2 <- read_csv("data_input/ucdp/GEDEvent_v25_01_25_12.csv")

in1 <-
  dt1 %>%
  select(
    year,
    type_of_violence,
    conflict_name,
    side_a,
    side_b,
    country,
    deaths_a,
    deaths_b,
    deaths_civilians,
    deaths_unknown,
    best
  )

in2 <-
  dt2 %>%
  select(
    year,
    type_of_violence,
    conflict_name,
    side_a,
    side_b,
    country,
    deaths_a,
    deaths_b,
    deaths_civilians,
    deaths_unknown,
    best
  )

all <-
  bind_rows(
    in1,
    in2,
  )

# imputing unknown status (comb a, comb b, or civilians)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

all2 <-
  all %>%
  select(
    year,
    country,
    type_of_violence,
    side_a,
    side_b,
    a = deaths_a,
    b = deaths_b,
    c = deaths_civilians,
    u = deaths_unknown,
    t = best
  ) %>%
  replace_na(list(a = 0, b = 0, c = 0, t = 0)) %>%
  filter(t > 0)


# Colombia ====
# ~~~~~~~~~~~~~
ucdp_col <-
  all2 |>
  filter(country == "Colombia") |>
  summarise(
    hms = sum(t),
    .by = c(year)
  ) |>
  mutate(source = "ucdp")

ucdp_col |>
  print(n = 40)

ucdp_col |>
  summarise(
    hms = sum(hms)
  )


# WHO data
hms_who <- read_csv("data_input/reference/who/who_homicide_colombia.csv")

unique(hms_who$sex)

hms <-
  hms_who |>
  summarise(hms = sum(hms), .by = year) |>
  mutate(source = "who") |>
  bind_rows(
    ucdp_col
  )

hms |>
  ggplot() +
  geom_line(aes(year, hms, col = source)) +
  scale_color_manual(values = c("black", "red")) +
  theme_bw()
ggsave("figures/homicides_ucdp_vs_who.png", w = 10, h = 6)
