# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 44. Life tables of the National Research Council (1982), 1950-1975
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# National Research Council (1982) Levels and Recent Trends in Fertility and
# Mortality in Colombia. Committee on Population and Demography, Report 20.
# Washington, DC: National Academy Press. doi:10.17226/19579. Appendix F,
# "Estimated Life Tables by Sex, 1950, 1955, 1960, 1965, 1970, and 1975",
# tables F.1-F.6, pp. 192-197 (read on the publisher's open online reader,
# https://www.nationalacademies.org/read/19579/chapter/13).
#
# An estimate of mortality for 1950-1975 that is independent of WPP 2024 and
# of this project's adjustment, made with the data and methods of the time.
# It bears on the stretch where our series has no adjustment of its own
# (1950-1969). The estimation methods of the report (its chapter on
# mortality, pp. 32-116) have not been reviewed here.
#
# transcription: the tables print l(x), L(x), T(x), E(x) and Q(x) = 1 - l(x)
#   for ages 0, 1, 2, 3, 4, 5, 10, ..., 80. l(x) was read by eye from the
#   page images (the dot-matrix print defeats OCR) for every age, sex and
#   year, together with E(0) and E(80). Every row was checked against the
#   printed Q(x) (l + Q = 1); three cells with handwritten corrections in the
#   original (men 50 in 1965, women 35-40 in 1965, women 40 in 1975) were
#   also checked against T(x) / E(x). This script re-checks that l(x)
#   decreases and that the life expectancy recomputed from l(x) reproduces
#   the printed E(0).
#
# output: data_input/reference/nrc1982_colombia_lifetables.csv (transcription)
#         output/tables/nrc1982_vs_series.csv
#         figures/06_components/nrc1982_comparison.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
source("code/00_setup.R")

ages <- c(0:5, seq(10, 80, 5))
lx <- list(
  `1950_m` = c(1, .838130, .801750, .785340, .774570, .766310, .746690, .733790, .713480, .687960, .660220, .630490, .598600, .561580, .515030, .463200, .400350, .325240, .240470, .154560, .080680),
  `1950_f` = c(1, .862530, .826010, .809160, .797980, .789340, .767790, .754660, .735000, .710160, .682990, .653680, .622010, .590420, .555080, .509560, .453170, .383420, .300370, .209240, .121700),
  `1955_m` = c(1, .865100, .831510, .816100, .805910, .798040, .777970, .764820, .745860, .721860, .695540, .667070, .636210, .601270, .558650, .509120, .447780, .372330, .283840, .189640, .103720),
  `1955_f` = c(1, .885550, .852650, .837220, .826910, .818900, .797910, .785360, .767700, .745250, .720480, .693540, .664130, .634410, .600990, .557400, .502380, .432580, .346680, .248430, .149360),
  `1960_m` = c(1, .890520, .860280, .846150, .836720, .829390, .809370, .796240, .778900, .756760, .732240, .705460, .676110, .643840, .606040, .559930, .501580, .427620, .337180, .235410, .135980),
  `1960_f` = c(1, .907560, .878510, .864400, .855110, .847850, .827840, .816080, .800610, .780800, .758800, .734650, .708040, .680760, .649960, .609310, .556960, .488750, .401740, .297400, .185950),
  `1965_m` = c(1, .908010, .885390, .875120, .866190, .859160, .834610, .821760, .805900, .785520, .762770, .737700, .709970, .680320, .647080, .604640, .550000, .479010, .389060, .282700, .171870),
  `1965_f` = c(1, .920370, .895490, .885490, .877120, .870540, .851670, .840720, .827120, .809630, .790090, .768490, .744560, .719650, .691520, .654030, .604970, .539600, .453550, .345890, .224490),
  `1970_m` = c(1, .920680, .901800, .893260, .885770, .879870, .860550, .848840, .834670, .816320, .795640, .772630, .746900, .718690, .687040, .646570, .593550, .523110, .431270, .318860, .197230),
  `1970_f` = c(1, .930910, .909590, .903830, .896670, .891010, .877880, .867800, .856000, .840730, .823530, .804340, .782830, .759800, .733260, .698050, .651130, .587160, .500400, .387820, .255640),
  `1975_m` = c(1, .931030, .914190, .906630, .899830, .894450, .881130, .870480, .857810, .841290, .822530, .801480, .777720, .751090, .721200, .682910, .632000, .562990, .470630, .353830, .222710),
  `1975_f` = c(1, .939750, .919580, .913640, .906440, .900690, .893160, .885960, .878720, .865360, .850210, .833200, .813960, .792800, .768000, .735230, .690880, .629140, .543100, .427540, .286380))
e_print <- tribble(
  ~year, ~sex, ~e0, ~e80,
  1950, "m", 43.709, 4.541, 1950, "f", 46.735, 5.089, 1955, "m", 46.817, 4.736, 1955, "f", 50.017, 5.242,
  1960, "m", 50.278, 4.986, 1960, "f", 53.604, 5.437, 1965, "m", 53.402, 5.247, 1965, "f", 56.748, 5.638,
  1970, "m", 56.263, 5.293, 1970, "f", 59.787, 5.664, 1975, "m", 58.742, 5.343, 1975, "f", 62.307, 5.698)

nrc <- imap_dfr(lx, \(l, k) tibble(year = as.integer(substr(k, 1, 4)), sex = substr(k, 6, 6), age = ages, lx = l)) |>
  left_join(e_print, by = c("year", "sex")) |>
  mutate(ex = case_when(age == 0 ~ e0, age == 80 ~ e80), source = "NRC 1982, Appendix F") |>
  select(year, sex, age, lx, ex, source)
write_csv(nrc, "data_input/reference/nrc1982_colombia_lifetables.csv")

# checks: l(x) decreasing, and e0 rebuilt from l(x) against the printed E(0)
stopifnot(all(nrc |> summarise(ok = all(diff(lx) < 0), .by = c(year, sex)) |> pull(ok)))
a0_q <- function(q, sex) if_else(sex == "m", case_when(q < 0.0226 ~ 0.1493 - 2.0367 * q, q < 0.0785 ~ 0.0244 + 3.4994 * q, TRUE ~ 0.2991),
                                 case_when(q < 0.0170 ~ 0.1490 - 2.0867 * q, q < 0.0658 ~ 0.0438 + 4.1075 * q, TRUE ~ 0.3141))
chk <- nrc |>
  left_join(e_print, by = c("year", "sex")) |>
  arrange(year, sex, age) |>
  mutate(n = lead(age) - age, lnext = lead(lx), ax = case_when(age == 0 ~ a0_q(1 - lnext / lx, sex), age %in% 1:4 ~ 0.45, TRUE ~ 2.5),
         Lx = if_else(age == 80, lx * e80, n * lnext + ax * (lx - lnext)), .by = c(year, sex)) |>
  summarise(e0_rebuilt = sum(Lx), e0_printed = first(e0), .by = c(year, sex)) |>
  mutate(diff = e0_rebuilt - e0_printed)
cat("e0 rebuilt from the transcribed l(x) against the printed E(0): largest absolute difference", round(max(abs(chk$diff)), 3), "years\n")
stopifnot(max(abs(chk$diff)) < 0.25)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# comparison with our series, WPP 2024 and UN IGME ====
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ind_nrc <- nrc |>
  left_join(e_print, by = c("year", "sex")) |>
  summarise(e0 = first(e0), q5 = 1 - lx[age == 5], q45_15 = 1 - lx[age == 60] / lx[age == 15], q20_60 = 1 - lx[age == 80] / lx[age == 60],
            e80 = first(e80), .by = c(year, sex)) |>
  mutate(series = "NRC 1982")
summ <- read_csv("output/tables/mortality_adjusted_summary.csv", show_col_types = FALSE)
ind <- summ |> filter(series != "WPP + MSE") |> select(series, year, sex, e0, q5, q45_15, q20_60, e80) |>
  bind_rows(ind_nrc) |>
  mutate(series = factor(series, c("NRC 1982", "WPP 2024", "Ajustada por componentes", "Registradas")))
write_csv(ind |> filter(year <= 1980), "output/tables/nrc1982_vs_series.csv")
# range of the adjusted series across the completeness variants of 42 (they differ before 1970)
vrange <- read_csv("output/tables/mortality_adjusted_variants_summary.csv", show_col_types = FALSE) |>
  summarise(across(c(e0, q5, q45_15, q20_60), list(lo = min, hi = max)), .by = c(year, sex))

cat("\nNRC 1982 against WPP 2024, the component-adjusted series and the registered deaths:\n")
print(ind |> filter(year %in% seq(1950, 1975, 5)) |>
        transmute(sex, year, series, e0 = round(e0, 1), q5 = round(1000 * q5), q45_15 = round(1000 * q45_15), q20_60 = round(1000 * q20_60)) |>
        pivot_wider(names_from = series, values_from = c(e0, q5, q45_15, q20_60), names_sort = TRUE) |> arrange(sex, year) |> as.data.frame())

lab_sex <- \(s) factor(s, c("m", "f"), c("Hombres", "Mujeres"))
cols <- c("NRC 1982" = "#eb6834", "WPP 2024" = "#0b0b0b", "Ajustada por componentes" = "#2a78d6", "Registradas" = "#8a8983")
ind_labs <- c(e0 = "Esperanza de vida al nacer (años)", q5 = "5q0 (por mil)", q45_15 = "45q15 (por mil)", q20_60 = "20q60 (por mil)")
band <- vrange |> filter(year <= 1985) |>
  pivot_longer(-c(year, sex), names_to = c("ind", ".value"), names_pattern = "(.*)_(lo|hi)") |>
  mutate(across(c(lo, hi), ~ if_else(ind == "e0", .x, 1000 * .x)), sex = lab_sex(sex), ind = factor(ind_labs[ind], ind_labs))
ind |>
  filter(year <= 1985) |>
  select(series, year, sex, `Esperanza de vida al nacer (años)` = e0, `5q0 (por mil)` = q5, `45q15 (por mil)` = q45_15, `20q60 (por mil)` = q20_60) |>
  mutate(across(c(`5q0 (por mil)`, `45q15 (por mil)`, `20q60 (por mil)`), ~ 1000 * .x)) |>
  pivot_longer(-c(series, year, sex), names_to = "ind", values_to = "v") |>
  mutate(sex = lab_sex(sex), ind = factor(ind, c("Esperanza de vida al nacer (años)", "5q0 (por mil)", "45q15 (por mil)", "20q60 (por mil)"))) |>
  ggplot(aes(year, v, col = series)) +
  geom_ribbon(data = band, aes(year, ymin = lo, ymax = hi), inherit.aes = FALSE, fill = "#2a78d6", alpha = 0.2) +
  geom_line(data = \(d) filter(d, series != "NRC 1982"), linewidth = 0.7) +
  geom_point(data = \(d) filter(d, series == "NRC 1982"), size = 2.4) +
  geom_line(data = \(d) filter(d, series == "NRC 1982"), linewidth = 0.4, linetype = "22") +
  facet_grid(ind ~ sex, scales = "free_y", switch = "y") +
  scale_color_manual(values = cols) +
  scale_x_continuous(breaks = seq(1950, 1985, 5)) +
  labs(title = "Tablas de vida del National Research Council (1982) frente a WPP 2024, la serie ajustada por componentes y las registradas",
       subtitle = "Colombia 1950-1985. NRC: tablas estimadas para 1950, 1955, 1960, 1965, 1970 y 1975 (Apéndice F). Banda azul: rango de la serie ajustada entre las variantes de completitud de 1950-1969",
       x = NULL, y = NULL, col = NULL) +
  theme_bw(base_size = 11) +
  theme(panel.grid.minor = element_blank(), panel.grid.major = element_line(colour = "grey92"), legend.position = "bottom",
        strip.background = element_rect(fill = "grey96", colour = NA), strip.placement = "outside",
        plot.title = element_text(size = 12, face = "bold"), plot.subtitle = element_text(size = 9.5, colour = "#52514e"))
ggsave("figures/06_components/nrc1982_comparison.png", w = 12, h = 12, bg = "white")
