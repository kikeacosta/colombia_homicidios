# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 80. Spain 1936-1946: violent deaths by province and year from the excess of
#     male deaths over the pre-war sex ratio (first, all-ages estimate)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Registered deaths by province and sex, 1933-1946 (INE, transcribed into
# data_input/reference/spain_ine_deaths_province_sex_1933-1946.csv). Deaths of
# men and women are non-violent deaths plus violent deaths H, of which a share
# pi are men:
#     D_M = rho N_F + pi H        D_F = N_F + (1 - pi) H
# with rho the sex ratio of the non-violent deaths. Solving for H:
#     H = (D_M - rho D_F) / (pi - rho (1 - pi))
# rho of each province is its sex ratio of all deaths in 1933-1935, the years
# before the war (they include the ordinary violence of those years, so H is
# violence ABOVE the pre-war level). pi = 0.95, the share of men among the
# war-related deaths registered in Talavera de la Reina (Atenza and Díaz
# 2009: 95.7 %); 0.90 as a sensitivity.
# The interval comes from how much the sex ratio of a province moves from one
# peace year to the next: the standard deviation of the log sex ratio around
# the province mean in 1933-1935, pooled over provinces.
#
# what H can and cannot be
#   - registered deaths by year of REGISTRATION: war deaths registered late
#     fall in later years (waves in 1939-1941 and 1943-1944), and deaths never
#     registered are absent
#   - soldiers are registered where they died (front and hospital provinces)
#   - deaths of men that are not violent but rose more than those of women
#     (prisoners dying of hunger or disease, soldiers' illnesses) count as H;
#     a fall of male deaths (men away at the front) lowers H
#   - the non-violent sex ratio is held at its pre-war level
#
# input    data_input/reference/spain_ine_deaths_province_sex_1933-1946.csv
# output   output/tables/intl_spain_excess_male_1936-1946.csv
#          figures/09_international/spain_excess_male_deaths.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
rm(list = ls()); gc(); source("code/00_setup.R")
options(width = 200)

sp <- read_csv("data_input/reference/spain_ine_deaths_province_sex_1933-1946.csv", show_col_types = FALSE, col_types = cols(province_code = col_character()))
w <- sp |> filter(!is.na(province_code)) |> select(year, province_code, sex, deaths) |> pivot_wider(names_from = sex, values_from = deaths)
lab <- sp |> filter(!is.na(province_code)) |> arrange(year) |> distinct(province_code, province) |> slice_tail(n = 1, by = province_code)

base <- w |> filter(year %in% 1933:1935) |> mutate(lsr = log(male / female))
rho <- base |> summarise(rho = exp(mean(lsr)), .by = province_code)
sd_lsr <- base |> mutate(dev = lsr - mean(lsr), .by = province_code) |> summarise(sd = sqrt(sum(dev^2) / (n() - n_distinct(province_code)))) |> pull(sd)
cat("pooled sd of the log sex ratio in 1933-1935 (year-to-year, within province):", round(sd_lsr, 4), "\n")

est <- function(pi_m) {
  w |> filter(year >= 1936) |> left_join(rho, by = "province_code") |>
    mutate(pi = pi_m,
           H = (male - rho * female) / (pi - rho * (1 - pi)),
           rho_lo = rho * exp(-1.645 * sd_lsr), rho_hi = rho * exp(1.645 * sd_lsr),
           H_lo = (male - rho_hi * female) / (pi - rho_hi * (1 - pi)),
           H_hi = (male - rho_lo * female) / (pi - rho_lo * (1 - pi)))
}
res <- bind_rows(est(0.95) |> mutate(scenario = "pi = 0.95"), est(0.90) |> mutate(scenario = "pi = 0.90")) |>
  left_join(lab, by = "province_code") |> relocate(province, .after = province_code)
write_csv(res, "output/tables/intl_spain_excess_male_1936-1946.csv")

main <- res |> filter(scenario == "pi = 0.95")
cat("\n== Spain: excess male deaths H by year (pi = 0.95; 90 % range from the peace-year variation) ==\n")
nat <- main |> summarise(deaths = sum(total), H = sum(H), H_lo = sum(H_lo), H_hi = sum(H_hi), .by = year)
print(as.data.frame(nat |> mutate(across(c(H, H_lo, H_hi), round), share_pct = round(100 * H / deaths, 1))), row.names = FALSE)
p <- res |> mutate(period = ifelse(year <= 1939, "1936-1939", ifelse(year <= 1942, "1940-1942", "1943-1946"))) |>
  summarise(H = sum(H), .by = c(scenario, period))
cat("\n== by period ==\n"); print(as.data.frame(p |> mutate(H = round(H)) |> pivot_wider(names_from = scenario, values_from = H)), row.names = FALSE)
cat("\n== provinces with the largest excess, 1936-1939 (pi = 0.95) ==\n")
print(as.data.frame(main |> filter(year <= 1939) |> summarise(H = round(sum(H)), deaths = sum(total), .by = c(province)) |>
                      mutate(share_pct = round(100 * H / deaths, 1)) |> arrange(-H) |> head(15)), row.names = FALSE)

# figure: H by year, national and for the twelve provinces with the largest 1936-1939 excess
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
       subtitle = paste0("Twelve provinces with the largest excess in 1936-1939. Band: range from the year-to-year variation of the sex ratio in 1933-1935. ",
                         "Grey: civil war.\nShare of men among the excess deaths: 0.95."),
       x = NULL, y = "deaths",
       caption = "Source: INE, Movimiento natural de la población de España, 1933-1946 (transcribed). Deaths by year of registration; never-registered deaths are not seen.") +
  theme_minimal(base_size = 10) +
  theme(panel.grid.minor = element_blank(), strip.text = element_text(face = "bold", hjust = 0),
        plot.title = element_text(face = "bold"), plot.caption = element_text(colour = "grey45", hjust = 0))
ggsave("figures/09_international/spain_excess_male_deaths.png", fig, w = 12, h = 8, bg = "white", dpi = 160)
