# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 79. Spain 1936-1942: registered deaths by province and sex (figure and
#     checks of the transcription)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Source: INE, "Movimiento natural de la población de España", one volume per
# year (D:/data/spain_mortality/ine_historia_<year>.pdf), table "Resumen de
# las defunciones por provincias" (1936-1940) and "Defunciones. Provincias"
# (1941-1942), transcribed from the page images into
# data_input/reference/spain_ine_deaths_province_sex_1926-1946.csv (1936-1942 used here).
# Registered deaths by year of REGISTRATION: war deaths registered late fall
# in later years. 1941 is the year of the hunger and typhus peak.
#
# output   figures/09_international/spain_deaths_province_sex_1936-1942.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
rm(list = ls()); gc(); source("code/00_setup.R")
options(width = 200)

sp <- read_csv("data_input/reference/spain_ine_deaths_province_sex_1926-1946.csv", show_col_types = FALSE) |> filter(year %in% 1936:1942)
w <- sp |> select(year, province, province_code, sex, deaths) |> pivot_wider(names_from = sex, values_from = deaths)
prov <- w |> filter(!is.na(province_code))
tot <- w |> filter(is.na(province_code))
stopifnot(all(prov$male + prov$female == prov$total))
chk <- prov |> summarise(male = sum(male), female = sum(female), .by = year) |> left_join(tot |> select(year, male_p = male, female_p = female), by = "year")
stopifnot(all(chk$male == chk$male_p), all(chk$female == chk$female_p))
cat("== national registered deaths ==\n")
print(as.data.frame(tot |> transmute(year, total, male, female, sex_ratio = round(male / female, 3))), row.names = FALSE)

# provinces ordered by their highest sex ratio of 1936-1939 over the mean of 1941-1942
sr <- prov |> mutate(sex_ratio = male / female)
base <- sr |> filter(year %in% 1941:1942) |> summarise(base = mean(sex_ratio), .by = province_code)
# names change spelling between volumes (Alava, Álava): the code identifies the province
lab <- prov |> arrange(year) |> distinct(province_code, province) |> slice_tail(n = 1, by = province_code)
ord <- sr |> filter(year %in% 1936:1939) |> left_join(base, by = "province_code") |>
  summarise(excess = max(sex_ratio / base), year_max = year[which.max(sex_ratio / base)], .by = province_code) |>
  left_join(lab, by = "province_code") |> arrange(-excess)
cat("\n== provinces with the largest rise of the sex ratio in 1936-1939 against 1941-1942 ==\n")
print(as.data.frame(head(ord |> mutate(excess = round(excess, 2)), 12)), row.names = FALSE)

sr <- sr |> select(-province) |> left_join(lab, by = "province_code") |>
  mutate(province = factor(province, lab$province[match(ord$province_code, lab$province_code)]))
nat <- tot |> transmute(year, nat = male / female)
fig <- ggplot(sr, aes(year, sex_ratio)) +
  annotate("rect", xmin = 1936, xmax = 1939, ymin = -Inf, ymax = Inf, fill = "grey93") +
  geom_line(data = nat, aes(year, nat), colour = "grey55", linetype = "22", linewidth = 0.4) +
  geom_line(colour = "#2a78d6", linewidth = 0.6) + geom_point(colour = "#2a78d6", size = 0.9) +
  facet_wrap(~province, ncol = 10) +
  scale_x_continuous(breaks = c(1936, 1939, 1942), labels = c("36", "39", "42")) +
  labs(title = "Spain 1936-1942: sex ratio of registered deaths (men / women) by province",
       subtitle = paste0("Provinces ordered by the largest rise of the ratio in 1936-1939 over its level in 1941-1942. ",
                         "Grey band: civil war (July 1936 - April 1939). Dashed: Spain."),
       x = NULL, y = NULL,
       caption = paste0("Source: INE, Movimiento natural de la población de España, 1936-1942, deaths by province (transcribed). ",
                        "Registered deaths by year of registration: war deaths registered late fall in later years.")) +
  theme_minimal(base_size = 9) +
  theme(panel.grid.minor = element_blank(), strip.text = element_text(face = "bold", hjust = 0, size = 7.5),
        plot.title = element_text(face = "bold"), plot.caption = element_text(colour = "grey45", hjust = 0))
ggsave("figures/09_international/spain_deaths_province_sex_1936-1942.png", fig, w = 13, h = 7.5, bg = "white", dpi = 160)
