rm(list = ls())
gc()
source("code/00_setup.R")

pop1 <- read_xlsx(
  "data_input/DANEpop/DCD-area-sexo-edad-proypoblacion-Mun-1985-1994.xlsx",
  skip = 11
)
pop2 <- read_xlsx(
  "data_input/DANEpop/DCD-area-sexo-edad-proypoblacion-Mun-1995-2004.xlsx",
  skip = 11
)
pop3 <- read_xlsx(
  "data_input/DANEpop/DCD-area-sexo-edad-proypoblacion-Mun-2005-2017_VP.xlsx",
  skip = 11
)

# pop4 <- read_xlsx(
#   "data_input/DANEpop/PPED-AreaSexoEdadMun-2018-2042_VP.xlsx",
#   sheet = "PobMunicipalxÁreaSexoEdad",
#   skip = 8
# )

pop <-
  bind_rows(pop1, pop2, pop3 |> rename(MPIO = DPMP, DPMP = MPIO)) |>
  rename(
    cod_dpto = DP,
    dpto = DPNOM,
    cod_munic = DPMP,
    munic = MPIO,
    year = AÑO,
    area = `ÁREA GEOGRÁFICA`
  ) |>
  filter(area == "Total") |>
  select(-area) |>
  gather(-(1:5), key = sex_age, value = pop)

unique(pop$sex_age)
unique(pop$munic)

pop4 <-
  pop |>
  filter(!sex_age %in% c("Total Hombres", "Total Mujeres", "Total General")) |>
  mutate(sex_age2 = sex_age) |>
  separate(sex_age, c("sex", "age"), sep = "_")

unique(pop4$sex_age2)
unique(pop4$sex)
unique(pop4$age)

table(pop4$sex_age2, pop4$sex)

pop5 <-
  pop4 |>
  mutate(
    sex = case_when(
      sex == "Hombres" ~ "m",
      sex == "Mujeres" ~ "f",
      sex == "Total" ~ "t"
    ),
    age = ifelse(age == "85 y más", 85, as.integer(age))
  )

unique(pop5$sex)
unique(pop5$age)

pop5y <-
  pop5 |>
  mutate(
    age = case_when(age == 0 ~ 0, age %in% 1:4 ~ 1, age >= 5 ~ age - age %% 5)
  ) |>
  summarise(
    pop = sum(pop),
    .by = c(cod_dpto, dpto, cod_munic, munic, year, sex, age)
  )
unique(pop5y$age)

write_rds(pop5y, "data_inter/pop_munic_1985-2017.rds", compress = "xz")
