# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 80. Spain 1936-1946: violent deaths by province and year from the excess of
#     male deaths over the pre-war sex ratio, and the split of the excess
#     deaths into violent and non-violent (all ages)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Registered deaths by province and sex (INE, transcribed into
# data_input/reference/spain_ine_deaths_province_sex_*.csv). Deaths of men and
# women are non-violent deaths plus violent deaths H, of which a share pi are
# men:
#     D_M = N_M + pi H        D_F = N_F + (1 - pi) H        N_M = rho N_F
# with rho the sex ratio of the non-violent deaths. Solving for H:
#     H = (D_M - rho D_F) / (pi - rho (1 - pi))
# rho of each province is its sex ratio of all deaths in the pre-war years
# (ordinary violence included, so H is violence ABOVE the pre-war level).
# pi = 0.95, the share of men among the war-related deaths registered in
# Talavera de la Reina (Atenza and Díaz 2009: 95.7 %); 0.90 as a sensitivity.
# The range of H comes from how much the sex ratio of a province moves from one
# peace year to the next (pooled sd of the log sex ratio around the province
# mean in the pre-war years).
#
# split of the excess. The expected deaths of each province come from its
# pre-war years: its own level and the national log-linear trend (main), or
# its own trend (sensitivity). Then
#     excess = D - expected,   non-violent excess = N_M + N_F - expected
#            = excess - H
# so H does not depend on the expected deaths; the non-violent part does.
# The split assumes the non-violent deaths keep the pre-war sex ratio: an
# excess of non-violent deaths with more men than that (hunger, prison) is
# counted as violent.
#
# what H can and cannot be
#   - registered deaths by year of REGISTRATION: war deaths registered late
#     fall in later years (waves in 1939-1941 and 1943-1944), and deaths never
#     registered are absent: H is a floor of the violent deaths
#   - soldiers are registered where they died (front and hospital provinces)
#   - deaths of men that are not violent but rose more than those of women
#     (prisoners dying of hunger or disease) count as H; a fall of male deaths
#     (men away at the front) lowers H
#
# input    data_input/reference/spain_ine_deaths_province_sex_1926-1946.csv
# output   output/tables/intl_spain_excess_male_1936-1946.csv
#          output/tables/intl_spain_excess_split_1936-1946.csv
#          figures/09_international/spain_excess_male_deaths.png
#          figures/09_international/spain_excess_split.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
rm(list = ls()); gc(); source("code/00_setup.R")
options(width = 200)

f_in <- "data_input/reference/spain_ine_deaths_province_sex_1926-1946.csv"
sp <- read_csv(f_in, show_col_types = FALSE, col_types = cols(province_code = col_character()))
# 1926-1927: Canarias is one province (Las Palmas and Santa Cruz de Tenerife
# from 1928); left out, so their baseline starts in 1928
w <- sp |> filter(!is.na(province_code), !grepl("+", province_code, fixed = TRUE)) |>
  select(year, province_code, sex, deaths) |> pivot_wider(names_from = sex, values_from = deaths)
# province names as printed in the last year (spellings change between volumes)
lab <- sp |> filter(!is.na(province_code), year == max(year)) |> distinct(province_code, province)
pre <- min(w$year):1935
cat("input", f_in, "| pre-war years", min(pre), "-", max(pre), "\n")

base <- w |> filter(year %in% pre) |> mutate(lsr = log(male / female))
rho <- base |> summarise(rho = exp(mean(lsr)), .by = province_code)
sd_lsr <- base |> mutate(dev = lsr - mean(lsr), .by = province_code) |> summarise(sd = sqrt(sum(dev^2) / (n() - n_distinct(province_code)))) |> pull(sd)
cat("pooled sd of the log sex ratio in the pre-war years (year-to-year, within province):", round(sd_lsr, 4), "\n")

# expected deaths: log-linear in the pre-war years, province levels and a
# common slope (main) or a slope per province (sensitivity)
fit_c <- lm(log(total) ~ factor(province_code) + I(year - 1935), data = base)
fit_p <- lm(log(total) ~ factor(province_code) / I(year - 1935), data = base)
cat("national pre-war trend of deaths:", round(100 * (exp(coef(fit_c)[["I(year - 1935)"]]) - 1), 2), "% a year\n")
grid <- w |> filter(year >= 1936) |> select(year, province_code)
grid <- grid |> mutate(exp_common = exp(predict(fit_c, grid)), exp_own = exp(predict(fit_p, grid)))

est <- function(pi_m) {
  w |> filter(year >= 1936) |> left_join(rho, by = "province_code") |>
    mutate(pi = pi_m,
           H = (male - rho * female) / (pi - rho * (1 - pi)),
           rho_lo = rho * exp(-1.645 * sd_lsr), rho_hi = rho * exp(1.645 * sd_lsr),
           H_lo = (male - rho_hi * female) / (pi - rho_hi * (1 - pi)),
           H_hi = (male - rho_lo * female) / (pi - rho_lo * (1 - pi)))
}
res <- bind_rows(est(0.95) |> mutate(scenario = "pi = 0.95"), est(0.90) |> mutate(scenario = "pi = 0.90")) |>
  left_join(grid, by = c("year", "province_code")) |>
  mutate(excess = total - exp_common, nonviolent = excess - H, excess_own = total - exp_own, nonviolent_own = excess_own - H) |>
  left_join(lab, by = "province_code") |> relocate(province, .after = province_code)
write_csv(res, "output/tables/intl_spain_excess_male_1936-1946.csv")

main <- res |> filter(scenario == "pi = 0.95")
cat("\n== Spain: excess male deaths H by year (pi = 0.95; 90 % range from the peace-year variation) ==\n")
nat <- main |> summarise(deaths = sum(total), expected = sum(exp_common), excess = sum(excess), H = sum(H), H_lo = sum(H_lo), H_hi = sum(H_hi),
                         nonviolent = sum(nonviolent), excess_own = sum(excess_own), nonviolent_own = sum(nonviolent_own), .by = year)
print(as.data.frame(nat |> mutate(across(-year, round), share_pct = round(100 * H / deaths, 1))), row.names = FALSE)
per <- function(y) ifelse(y <= 1939, "1936-1939", ifelse(y <= 1942, "1940-1942", "1943-1946"))
p <- res |> mutate(period = per(year)) |>
  summarise(excess = sum(excess), H = sum(H), nonviolent = sum(nonviolent), nonviolent_own = sum(nonviolent_own), .by = c(scenario, period))
cat("\n== split of the excess by period (expected: province level and national trend; _own: province trend) ==\n")
print(as.data.frame(p |> mutate(across(where(is.numeric), round))), row.names = FALSE)
split <- main |> mutate(period = per(year)) |>
  summarise(deaths = sum(total), expected = sum(exp_common), excess = sum(excess), violent = sum(H), nonviolent = sum(nonviolent), .by = c(province_code, province, period))
write_csv(split, "output/tables/intl_spain_excess_split_1936-1946.csv")
cat("\n== provinces with the largest excess, 1936-1939 (pi = 0.95) ==\n")
print(as.data.frame(split |> filter(period == "1936-1939") |> mutate(across(where(is.numeric), round), violent_pct = round(100 * violent / excess)) |>
                      arrange(-excess) |> head(15)), row.names = FALSE)

# figure 1: H by year, twelve provinces with the largest 1936-1939 excess
top <- main |> filter(year <= 1939) |> summarise(H = sum(H), .by = province) |> arrange(-H) |> head(12) |> pull(province)
fd <- main |> filter(province %in% top) |> mutate(province = factor(province, top))
fig <- ggplot(fd, aes(year, H)) +
  annotate("rect", xmin = 1936, xmax = 1939, ymin = -Inf, ymax = Inf, fill = "grey93") +
  geom_hline(yintercept = 0, colour = "grey60", linewidth = 0.3) +
  geom_ribbon(aes(ymin = H_lo, ymax = H_hi), fill = "#2a78d6", alpha = 0.18) +
  geom_line(colour = "#2a78d6", linewidth = 0.7) + geom_point(colour = "#2a78d6", size = 1) +
  facet_wrap(~province, ncol = 4, scales = "free_y") +
  scale_x_continuous(breaks = seq(1936, 1946, 2)) +
  labs(title = "Spain: male deaths above the pre-war sex ratio, by province and year of registration",
       subtitle = paste0("Twelve provinces with the largest excess in 1936-1939. Band: range from the year-to-year variation of the sex ratio in ",
                         min(pre), "-1935. Grey: civil war.\nShare of men among the excess deaths: 0.95."),
       x = NULL, y = "deaths",
       caption = paste0("Source: INE, Movimiento natural de la población de España, ", min(pre), "-1946 (transcribed). Deaths by year of registration; never-registered deaths are not seen.")) +
  theme_minimal(base_size = 10) +
  theme(panel.grid.minor = element_blank(), strip.text = element_text(face = "bold", hjust = 0),
        plot.title = element_text(face = "bold"), plot.caption = element_text(colour = "grey45", hjust = 0))
ggsave("figures/09_international/spain_excess_male_deaths.png", fig, w = 12, h = 8, bg = "white", dpi = 160)

# figure 2: national deaths against the expected, and the excess split
nl <- nat |> select(year, violent = H, nonviolent) |> pivot_longer(-year) |>
  mutate(name = factor(name, c("nonviolent", "violent"), c("non-violent excess", "violent (excess male deaths)")))
fig2 <- ggplot(nl, aes(year, value / 1000, fill = name)) +
  geom_col(width = 0.75) +
  geom_point(data = nat, aes(year, excess / 1000), inherit.aes = FALSE, size = 1.8) +
  geom_point(data = nat, aes(year, excess_own / 1000), inherit.aes = FALSE, size = 1.8, shape = 1) +
  geom_hline(yintercept = 0, colour = "grey40", linewidth = 0.3) +
  scale_fill_manual(values = c("#f2a541", "#2a78d6"), name = NULL) +
  scale_x_continuous(breaks = 1936:1946) +
  labs(title = "Spain: excess deaths split into violent and non-violent, by year of registration",
       subtitle = paste0("Expected deaths: each province's ", min(pre), "-1935 level and the national trend. Dots: total excess ",
                         "(filled: national trend; open: each province's own trend).\nViolent: male deaths above the pre-war sex ratio, ",
                         "with 95 % of the victims men. The split assumes non-violent deaths keep the pre-war sex ratio."),
       x = NULL, y = "thousand deaths",
       caption = "Source: INE, Movimiento natural de la población de España (transcribed). Never-registered deaths are not seen.") +
  theme_minimal(base_size = 10) +
  theme(panel.grid.minor = element_blank(), legend.position = "bottom", plot.title = element_text(face = "bold"),
        plot.caption = element_text(colour = "grey45", hjust = 0))
ggsave("figures/09_international/spain_excess_split.png", fig2, w = 10, h = 6, bg = "white", dpi = 160)
