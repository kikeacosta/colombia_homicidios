# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 81. Spain: the excess-male estimate of violent deaths (script 80) against
#     the published counts by province and the national excess mortality
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Published figures collected in data_input/reference/spain_literature_deaths_province.csv
# (sources and caveats in the companion _notes.md). Used here:
#   - Salas Larrazábal (1977): registered deaths from military operations, and
#     executions and homicides in the Nationalist zone, by province of
#     registration, 1936-1939 with late registrations folded back. His
#     provincial table of Republican-zone executions (72,344) was not found.
#   - Espinosa Maestre (2008): documented victims of the Francoist repression
#     (war and postwar) and of the Republican repression, by province; several
#     provinces partly studied or missing.
#   - Ortega and Silvestre (2005): national excess deaths of men and of women
#     over the 1926-1935 trend, by year 1936-1942.
# Script 80 counts registered deaths by year of REGISTRATION, so late
# registrations of war deaths fall in 1939-1946; the sums to 1942 and to 1946
# are the fairer match to Salas.
#
# input    output/tables/intl_spain_excess_male_1936-1946.csv
#          data_input/reference/spain_literature_deaths_province.csv
#          data_input/reference/spain_ine_deaths_province_sex_1926-1946.csv
# output   output/tables/intl_spain_literature_comparison.csv
#          figures/09_international/spain_literature_comparison.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
rm(list = ls()); gc(); source("code/00_setup.R")
options(width = 200)

est <- read_csv("output/tables/intl_spain_excess_male_1936-1946.csv", show_col_types = FALSE, col_types = cols(province_code = col_character())) |>
  filter(scenario == "pi = 0.95")
ours <- est |> summarise(H_3639 = sum(H[year <= 1939]), H_3642 = sum(H[year <= 1942]), H_3646 = sum(H), .by = c(province_code, province))

lit <- read_csv("data_input/reference/spain_literature_deaths_province.csv", show_col_types = FALSE)
names(lit)[1] <- "source_short"
salas <- lit |> filter(source_short %in% c("Salas1977_military_ops", "Salas1977_exec_nationalist_zone"), province != "TOTAL") |>
  mutate(var = ifelse(source_short == "Salas1977_military_ops", "salas_military", "salas_exec_nat")) |>
  select(province, var, value) |> pivot_wider(names_from = var, values_from = value)
# Espinosa 2008: one figure per province (complete study preferred, then the largest)
esp <- lit |> filter(source_short == "Espinosa2008", province != "TOTAL", concept %in% c("francoist_repression", "republican_repression")) |>
  mutate(rank = match(value_status, c("exact", "approx", "range_low", "incomplete_research"))) |>
  arrange(province, concept, rank, -value) |> distinct(province, concept, .keep_all = TRUE) |>
  transmute(province, var = ifelse(concept == "francoist_repression", "esp_francoist", "esp_republican"), value,
            status = value_status) |>
  pivot_wider(names_from = var, values_from = c(value, status))
# names are matched without accents (spellings differ between volumes and sources)
key <- function(x) stringi::stri_trans_general(x, "Latin-ASCII")
cmp <- ours |> mutate(k = key(province)) |> left_join(salas |> mutate(k = key(province), province = NULL), by = "k") |>
  left_join(esp |> mutate(k = key(province), province = NULL), by = "k") |> select(-k) |>
  mutate(salas_total = salas_military + salas_exec_nat,
         esp_total = coalesce(value_esp_francoist, 0) + coalesce(value_esp_republican, 0),
         esp_complete = status_esp_francoist %in% c("exact", "approx") & !is.na(value_esp_republican))
write_csv(cmp, "output/tables/intl_spain_literature_comparison.csv")
stopifnot(nrow(cmp) == 50, sum(is.na(cmp$salas_military)) == 0)

cat("== national sums ==\n")
print(as.data.frame(cmp |> summarise(across(c(H_3639, H_3642, H_3646, salas_military, salas_exec_nat, salas_total), ~ round(sum(.x, na.rm = TRUE))))), row.names = FALSE)
co <- function(x, y) { ok <- x > 0 & y > 0 & !is.na(x) & !is.na(y)
  c(n = sum(ok), pearson_log = round(cor(log(x[ok]), log(y[ok])), 2), spearman = round(cor(x[ok], y[ok], method = "spearman"), 2)) }
cat("\n== correlation across provinces ==\n")
cr <- rbind(
  "ours 1936-39 vs Salas military"        = co(cmp$H_3639, cmp$salas_military),
  "ours 1936-46 vs Salas military"        = co(cmp$H_3646, cmp$salas_military),
  "ours 1936-39 vs Salas mil + exec (nat)" = co(cmp$H_3639, cmp$salas_total),
  "ours 1936-46 vs Salas mil + exec (nat)" = co(cmp$H_3646, cmp$salas_total),
  "ours 1936-46 vs Espinosa (complete)"   = with(cmp[cmp$esp_complete, ], co(H_3646, esp_total)),
  "Salas mil + exec vs Espinosa (complete)" = with(cmp[cmp$esp_complete, ], co(salas_total, esp_total)))
print(cr)
cat("\n== largest gaps, ours 1936-46 against Salas military + Nationalist-zone executions ==\n")
print(as.data.frame(cmp |> transmute(province, H_3646 = round(H_3646), salas_total, ratio = round(H_3646 / salas_total, 2)) |> arrange(-abs(log(ratio))) |> head(14)), row.names = FALSE)

# national, by year: our H against Ortega and Silvestre, and their male and
# female excess passed through the same formula (national pre-war sex ratio)
os <- lit |> filter(source_short == "OrtegaSilvestre2005", province == "TOTAL", period %in% as.character(1936:1942)) |>
  mutate(year = as.integer(period), sex = ifelse(seq_along(value) <= 7, "male", "female")) |> select(year, sex, value) |>
  pivot_wider(names_from = sex, values_from = value, names_prefix = "os_")
sp <- read_csv("data_input/reference/spain_ine_deaths_province_sex_1926-1946.csv", show_col_types = FALSE) |> filter(is.na(province_code))
rho_nat <- sp |> filter(year %in% 1926:1935) |> select(year, sex, deaths) |> pivot_wider(names_from = sex, values_from = deaths) |>
  summarise(rho = exp(mean(log(male / female)))) |> pull(rho)
nat <- est |> summarise(H = sum(H), .by = year) |> left_join(os, by = "year") |>
  mutate(os_H = (os_male - rho_nat * os_female) / (0.95 - rho_nat * 0.05))
cat("\n== national by year: ours and Ortega-Silvestre (their excess passed through our formula) ==\n")
print(as.data.frame(nat |> mutate(across(-year, round))), row.names = FALSE)

# figure
lab <- cmp |> mutate(r = rank(-H_3646)) |> filter(r <= 12 | abs(log(H_3646 / salas_total)) > log(2.5))
p1 <- ggplot(cmp |> filter(H_3646 > 0), aes(salas_total, H_3646)) +
  geom_abline(slope = 1, intercept = 0, colour = "grey60", linetype = "22") +
  geom_point(colour = "#2a78d6", size = 1.8) +
  ggrepel::geom_text_repel(data = lab |> filter(H_3646 > 0), aes(label = province), size = 2.6, colour = "grey25", max.overlaps = 30) +
  scale_x_log10(labels = scales::comma, expand = expansion(mult = 0.08)) + scale_y_log10(labels = scales::comma) +
  labs(title = "By province", subtitle = "Ours (excess male deaths registered 1936-1946) against Salas (registered war deaths\nand Nationalist-zone executions, 1936-1939 with late registrations). Dashed: equal.",
       x = "Salas (1977)", y = "this estimate")
p2 <- ggplot(nat |> pivot_longer(c(H, os_H), names_to = "series") |> filter(!is.na(value)) |>
               mutate(series = ifelse(series == "H", "this estimate (by year of registration)", "Ortega and Silvestre's excess of men and women,\nthrough the same formula")),
             aes(year, value, colour = series)) +
  geom_line(linewidth = 0.8) + geom_point(size = 1.6) +
  scale_colour_manual(values = c("#d95f02", "#2a78d6"), name = NULL) + scale_y_continuous(labels = scales::comma) +
  scale_x_continuous(breaks = 1936:1946) +
  labs(title = "Spain, by year", subtitle = "Violent deaths implied by the excess of male deaths", x = NULL, y = NULL) +
  theme(legend.position = "bottom")
fig <- ggpubr::ggarrange(p1 + theme_minimal(base_size = 10) + theme(plot.title = element_text(face = "bold")),
                         p2 + theme_minimal(base_size = 10) + theme(plot.title = element_text(face = "bold"), legend.position = "bottom", panel.grid.minor = element_blank()),
                         ncol = 2, widths = c(1.1, 1))
ggsave("figures/09_international/spain_literature_comparison.png", fig, w = 13, h = 6.5, bg = "white", dpi = 160)
