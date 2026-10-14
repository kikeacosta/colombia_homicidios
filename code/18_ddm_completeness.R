# 18_ddm_completeness.R ------------------------------------------------------
# registration completeness of adult deaths with the DDM package (Riffe, Lima,
# Queiroz): generalized growth balance (GGB), synthetic extinct generations
# (SEG) and their hybrid (GGB-SEG), by department and sex, on three
# intercensal windows: 1985-1993, 1993-2005, 2005-2017.
#
# install (DDM left CRAN in 2017; last release from the archive):
#   install.packages("https://cran.r-project.org/src/contrib/Archive/DDM/DDM_1.0-0.tar.gz",
#                    repos = NULL, type = "source")
#
# inputs per department x sex x age (0, 1, 5, ..., 75, 80+):
#   pop1, pop2: DANE population at the window's two ends (the 2018-census
#               retroprojections used throughout; dates are 30 June, so
#               year + 0.5)
#   deaths:     registered deaths, annual average over the window (half
#               weight on the two end years)
# the coverage estimates are relative to DANE's own population series; DDM
# estimates the coverage ratio delta between the two population counts and
# corrects for it in the hybrid.
#
# 91, 94, 95, 97, 99 (the Amazonia / Orinoquia micro-departments) are pooled as
# "91"; San Andres (88) is dropped (too few deaths).
#
# outputs: output/tables/completeness_ddm.csv, figures/completeness_ddm_vs_ggb.png

rm(list = ls())
gc()
source("code/00_setup.R")
library(DDM)

pop <- read_rds("data_inter/pop_munic_1985-2017.rds")
dx <- read_rds("data_inter/deaths_munic_age_1979-2023.rds")

windows <- tribble(~window, ~y1, ~y2, "1985-1993", 1985, 1993, "1993-2005", 1993, 2005, "2005-2017", 2005, 2017)

pool <- function(cod) ifelse(cod %in% c("91", "94", "95", "97", "99"), "91", cod)
age80 <- function(a) ifelse(a >= 80, 80, a)

p <-
  pop |>
  filter(sex %in% c("m", "f"), !is.na(age)) |>
  mutate(cod = pool(sprintf("%02d", as.integer(cod_dpto))), age = age80(age)) |>
  filter(cod != "88") |>
  summarise(pop = sum(pop), .by = c(cod, year, sex, age))

# deaths, unknown ages distributed pro rata within department x year x sex
d_all <-
  dx |>
  filter(year %in% 1985:2017, !is.na(sex)) |>
  mutate(cod = pool(sprintf("%02d", cod_dpto))) |>
  filter(cod != "88", cod %in% p$cod) |>
  mutate(age = age80(age)) |>
  summarise(dx = sum(dx_tot), .by = c(cod, year, sex, age))
unk <- d_all |> filter(is.na(age)) |> select(cod, year, sex, unk = dx)
d <-
  d_all |>
  filter(!is.na(age)) |>
  mutate(tot = sum(dx), .by = c(cod, year, sex)) |>
  left_join(unk, by = c("cod", "year", "sex")) |>
  replace_na(list(unk = 0)) |>
  mutate(dx = dx * (1 + unk / tot)) |>
  select(cod, year, sex, age, dx)

build <- function(y1, y2, w) {
  wts <- tibble(year = y1:y2, w = c(0.5, rep(1, y2 - y1 - 1), 0.5))
  dd <- d |> inner_join(wts, by = "year") |> summarise(deaths = sum(dx * w) / (y2 - y1), .by = c(cod, sex, age))
  p1 <- p |> filter(year == y1) |> select(cod, sex, age, pop1 = pop)
  p2 <- p |> filter(year == y2) |> select(cod, sex, age, pop2 = pop)
  p1 |>
    inner_join(p2, by = c("cod", "sex", "age")) |>
    inner_join(dd, by = c("cod", "sex", "age")) |>
    mutate(year1 = y1 + 0.5, year2 = y2 + 0.5, window = w)
}

X <- pmap_dfr(windows, \(window, y1, y2) build(y1, y2, window))
cat("input rows:", nrow(X), " areas:", n_distinct(X$cod), "\n")

run_one <- function(w, s) {
  x <- X |> filter(window == w, sex == s) |>
    select(cod, pop1, pop2, deaths, year1, year2, age, sex) |> as.data.frame()
  out <- tryCatch(ddm(x), error = function(e) { message(w, " ", s, ": ", conditionMessage(e)); NULL })
  if (is.null(out)) return(NULL)
  as_tibble(out) |> mutate(window = w, sex = s, .before = 1)
}

res <- bind_rows(lapply(split(expand_grid(w = windows$window, s = c("m", "f")), seq_len(6)), \(r) run_one(r$w, r$s)))
print(names(res))
res <- res |> mutate(caribe = cod %in% cod_caribe)

write_csv(res, "output/tables/completeness_ddm.csv")

cat("\nDDM completeness, distribution across departments (median, [min-max]) by window and sex\n")
print(
  res |>
    summarise(ggb_med = round(median(ggb, na.rm = TRUE), 2), seg_med = round(median(seg, na.rm = TRUE), 2),
              hyb_med = round(median(ggbseg, na.rm = TRUE), 2), hyb_min = round(min(ggbseg, na.rm = TRUE), 2),
              hyb_max = round(max(ggbseg, na.rm = TRUE), 2), n = n(), .by = c(window, sex)) |>
    arrange(window, sex)
)

cat("\nCaribbean departments, hybrid GGB-SEG\n")
print(
  res |> filter(caribe) |> select(window, cod, sex, ggbseg) |>
    pivot_wider(names_from = c(window, sex), values_from = ggbseg) |>
    mutate(across(where(is.numeric), ~ round(.x, 2))) |> arrange(cod) |> as.data.frame()
)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# comparison with the hand-rolled GGB (10) and DANE-implied completeness (14)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# windows differ, so compare on the closest period of each:
#   DDM 1985-1993 vs 10's 1985-1995 / 14's 1985-1990 + 1990-1995
#   DDM 1993-2005 vs 10's 1995-2005 / 14's 1995-2000 + 2000-2005
ggb10 <- read_rds("data_inter/completeness_ggb.rds") |>
  mutate(cod = pool(cod_dpto)) |>
  summarise(c10 = mean(completeness, na.rm = TRUE), .by = c(cod, sex, period))
dane <- read_csv("output/tables/completeness_dane.csv", show_col_types = FALSE)

map_w <- tribble(~window, ~period10, "1985-1993", "1985-1995", "1993-2005", "1995-2005", "2005-2017", "2005-2015")
cmp <-
  res |>
  left_join(map_w, by = "window") |>
  left_join(ggb10, by = c("cod", "sex", "period10" = "period"))

cat("\ncorrelation of DDM hybrid with the hand-rolled GGB, across departments\n")
print(cmp |> summarise(r = round(cor(ggbseg, c10, use = "complete.obs"), 2),
                       mean_ddm = round(mean(ggbseg, na.rm = TRUE), 2), mean_c10 = round(mean(c10, na.rm = TRUE), 2),
                       .by = c(window, sex)) |> arrange(window, sex))

cmp |>
  filter(is.finite(c10), is.finite(ggbseg)) |>
  ggplot(aes(c10, ggbseg, col = caribe)) +
  geom_abline(lty = "dashed") +
  geom_point(alpha = 0.8) +
  facet_grid(sex ~ window) +
  coord_equal(xlim = c(0, 1.5), ylim = c(0, 1.5)) +
  scale_color_manual(values = c("TRUE" = "#CA6702", "FALSE" = "grey50"), labels = c("TRUE" = "Caribe", "FALSE" = "resto")) +
  labs(title = "Adult death registration completeness: DDM hybrid vs the hand-rolled GGB",
       x = "GGB (10)", y = "GGB-SEG hybrid (DDM)", col = NULL) +
  theme_bw() + theme(legend.position = "bottom")
ggsave("figures/completeness_ddm_vs_ggb.png", w = 9, h = 6)
