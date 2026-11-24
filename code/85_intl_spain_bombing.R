# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# 85. Spain 1936-1940: violent deaths that kill both sexes (bombings)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# H of 80 assumes that 95 % of the victims are men in every province. A
# bombing kills men and women alike, so one death raises the male excess by
# little and H counts only a fraction of it; the rest falls in the
# non-violent excess. The registry has no bombing item, but the women among
# the registered violent deaths (war wounds, execution of civilians by the
# belligerent armies, judicial execution, homicide) show where violence hit
# both sexes.
#
# With the pre-war ratio rho, male deaths M = rho F0 + Vm and female deaths
# F = F0 + Vf, so Vm - rho Vf = M - rho F and
#     H_f = (M - rho F) + (1 + rho) Vf
# H_f takes the women killed (Vf) from the registry instead of from pi.
# Women killed but registered under other causes would be missed, so Vf is
# kept at no less than 3 % of the violent deaths (the share of women among
# registered violent deaths is 3-7 % by year):
#     H_b = max(H_f, (M - rho F) / (0.97 - 0.03 rho))
# Published bombing deaths by province check whether the registry holds the
# women those bombings killed. Where the women killed in bombings (share of
# women times deaths) exceed the registered violent deaths of women, the
# difference is added to Vf (H_ext). Years 1936-1940, the detailed list;
# 1941-1942 have no war items, and the bombings ended in 1939.
#
# input    output/tables/intl_spain_causes_check.csv (83)
#          data_input/reference/spain_bombing_deaths_province.csv
# output   output/tables/intl_spain_bombing_national.csv
#          output/tables/intl_spain_bombing_provinces.csv
#          figures/09_international/spain_bombing.png
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
rm(list = ls()); gc(); source("code/00_setup.R")
options(width = 200)
sw_default <- 0.4      # share of women among bombing deaths where the source gives none

cc <- read_csv("output/tables/intl_spain_causes_check.csv", show_col_types = FALSE, col_types = cols(province_code = col_character())) |>
  filter(year <= 1940)
x <- cc |> mutate(vf = violent_reg_f, vm = violent_reg_m, K = male - rho * female,
                  H_f = K + (1 + rho) * vf,
                  H_97 = K / (0.97 - 0.03 * rho),
                  H_b = pmax(H_f, H_97))

# provinces, 1936-1939, with the published bombing deaths
key <- function(s) stringi::stri_trans_general(s, "Latin-ASCII")
bo <- read_csv("data_input/reference/spain_bombing_deaths_province.csv", show_col_types = FALSE) |>
  mutate(k = key(province)) |> select(k, bombing = deaths, bombing_low = deaths_low, bombing_high = deaths_high, share_women)
pp <- x |> filter(year <= 1939) |>
  summarise(H = sum(H), H_f = sum(H_f), H_b = sum(H_b), women_reg = sum(vf), men_reg = sum(vm), rho = mean(rho),
            .by = c(province_code, province)) |>
  mutate(k = key(province)) |> left_join(bo, by = "k") |> select(-k) |>
  mutate(share_women_reg = women_reg / (women_reg + men_reg),
         women_bombing = coalesce(share_women, sw_default) * bombing,
         # share of each bombing death that H with pi = 0.95 counts
         H_counts_of_bombing = ((1 - coalesce(share_women, sw_default)) - rho * coalesce(share_women, sw_default)) / (0.95 - 0.05 * rho),
         H_ext = H_b + (1 + rho) * pmax(0, coalesce(women_bombing, 0) - women_reg),
         change_pct = 100 * (H_ext / H - 1))
write_csv(pp, "output/tables/intl_spain_bombing_provinces.csv")

# national
nat <- x |> summarise(H = sum(H), H_f = sum(H_f), H_b = sum(H_b), women_reg = sum(vf), women_implied_by_pi = sum(0.05 * H), .by = year) |>
  mutate(period = as.character(year), .before = 1) |> select(-year)
tot <- pp |> summarise(H = sum(H), H_f = sum(H_f), H_b = sum(H_b), H_ext = sum(H_ext), women_reg = sum(women_reg),
                       women_implied_by_pi = sum(0.05 * H), bombing = sum(bombing, na.rm = TRUE),
                       women_bombing = sum(women_bombing, na.rm = TRUE)) |> mutate(period = "1936-1939", .before = 1)
nat <- bind_rows(nat, tot)
write_csv(nat, "output/tables/intl_spain_bombing_national.csv")
cat("== Spain: H with pi = 0.95 (H), anchored on the registered women (H_f), with a floor of 3 % women (H_b),",
    "and with the women killed in published bombings (H_ext) ==\n")
print(as.data.frame(nat |> mutate(across(-period, round))), row.names = FALSE)
cat("\nshare of a bombing death that H with pi = 0.95 counts, median over provinces:",
    round(median(pp$H_counts_of_bombing, na.rm = TRUE), 2), "\n")

cat("\n== provinces with published bombing deaths, 1936-1939 ==\n")
print(as.data.frame(pp |> filter(!is.na(bombing)) |> arrange(-bombing) |>
                      transmute(province, bombing, women_bombing = round(women_bombing), women_reg,
                                share_women_reg = round(share_women_reg, 3), H = round(H), H_b = round(H_b), H_ext = round(H_ext),
                                change_pct = round(change_pct, 1))), row.names = FALSE)
cat("\n== largest changes against pi = 0.95 ==\n")
print(as.data.frame(pp |> arrange(-abs(H_ext - H)) |> head(12) |>
                      transmute(province, H = round(H), H_ext = round(H_ext), change = round(H_ext - H), change_pct = round(change_pct, 1),
                                share_women_reg = round(share_women_reg, 3))), row.names = FALSE)

# figure: provinces with the largest changes, and the published bombing deaths
top <- pp |> arrange(-abs(H_ext - H)) |> head(20) |> mutate(province = forcats::fct_reorder(province, H_ext - H))
p1 <- ggplot(top) +
  geom_segment(aes(x = H / 1000, xend = H_ext / 1000, y = province, yend = province), colour = "grey60") +
  geom_point(aes(H / 1000, province, colour = "pi = 0.95 (80)"), size = 2) +
  geom_point(aes(H_ext / 1000, province, colour = "women from the registry and the bombings"), size = 2) +
  scale_colour_manual(values = c(`pi = 0.95 (80)` = "grey50", `women from the registry and the bombings` = "#2a78d6"), name = NULL) +
  labs(title = "Violent deaths 1936-1939, the 20 provinces that change most",
       subtitle = "Grey: 95 % men among victims in every province. Blue: the women killed taken from the registry\n(at least 3 %) and from the published bombing deaths.",
       x = "thousand violent deaths", y = NULL) +
  theme_minimal(base_size = 10) + theme(legend.position = "bottom", panel.grid.minor = element_blank(), plot.title = element_text(face = "bold"))
pb <- pp |> filter(!is.na(bombing), bombing > 0)
p2 <- ggplot(pb, aes(women_bombing, pmax(women_reg, 1))) +
  geom_abline(slope = 1, intercept = 0, colour = "grey60", linetype = "22") +
  geom_point(colour = "#c0392b", size = 2) +
  ggrepel::geom_text_repel(aes(label = province), size = 2.6, colour = "grey30") +
  scale_x_log10(labels = scales::comma) + scale_y_log10(labels = scales::comma) +
  labs(title = "Women killed in bombings and women registered as violent deaths",
       subtitle = paste0("1936-1939, by province. Women killed in bombings: published deaths times\ntheir share of women (", sw_default,
                         " where not given). Above the dashed line the registry holds them."),
       x = "women killed in bombings (published)", y = "registered violent deaths of women") +
  theme_minimal(base_size = 10) + theme(plot.title = element_text(face = "bold"), panel.grid.minor = element_blank())
fig <- ggpubr::ggarrange(p1, p2, ncol = 2, widths = c(1.1, 1))
ggsave("figures/09_international/spain_bombing.png", fig, w = 14, h = 6.5, bg = "white", dpi = 160)
