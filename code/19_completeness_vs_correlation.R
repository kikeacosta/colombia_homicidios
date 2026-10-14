# 19_completeness_vs_correlation.R -------------------------------------------
# how does the sex-ratio / homicide correlation vary with registration
# completeness, and is there a decreasing slope (diminishing returns)?
#
#   A. each department as an arrow from its pre-1998 point (completeness of
#      the 1985-93 DDM window, correlation 1985-97) to its post-1998 point
#      (2005-17 window, correlation 1998-2017)
#   B. smooth curves r = f(completeness) per period (GAM, 4 knots), pooled
#      with a common shape and a period shift; shaded = 95% bootstrap band
#      over departments
#   C. local slope of the curve (change in correlation per 0.1 completeness)
#
# inputs: output/tables/completeness_ddm.csv, underreg_dept_correlations.csv
# output: figures/05_underregistration_tests/completeness_vs_correlation.png

rm(list = ls())
source("code/00_setup.R")
library(patchwork)
set.seed(1)

ddm <- read_csv("output/tables/completeness_ddm.csv", show_col_types = FALSE) |>
  mutate(cod = sprintf("%02d", as.integer(cod))) |>
  summarise(c = mean(ggbseg), .by = c(window, cod))
r <- read_csv("output/tables/underreg_dept_correlations.csv", show_col_types = FALSE) |>
  mutate(cod = sprintf("%02d", as.integer(cod_dpto)))

pts <-
  bind_rows(
    ddm |> filter(window == "1985-1993") |> transmute(cod, period = "pre", c),
    ddm |> filter(window == "2005-2017") |> transmute(cod, period = "post", c)
  ) |>
  inner_join(r |> select(cod, dpto, caribe, period, r_levels), by = c("cod", "period")) |>
  mutate(post = as.numeric(period == "post"))

grid <- tibble(c = seq(0.2, 1.05, length.out = 60))
fit_curve <- function(d) {
  m <- gam(r_levels ~ s(c, k = 4) + post, data = d)
  tibble(c = grid$c,
         pre = predict(m, tibble(c = grid$c, post = 0)),
         post = predict(m, tibble(c = grid$c, post = 1)))
}
cur <- fit_curve(pts)
deps <- unique(pts$cod)
boot <- map_dfr(1:300, \(b) {
  s <- sample(deps, replace = TRUE)
  d <- map_dfr(s, \(k) pts |> filter(cod == k))
  fit_curve(d) |> mutate(b = b)
})
band <- boot |>
  pivot_longer(c(pre, post), names_to = "period", values_to = "r") |>
  summarise(lo = quantile(r, .025), hi = quantile(r, .975), .by = c(c, period))
curve <- cur |> pivot_longer(c(pre, post), names_to = "period", values_to = "r") |> left_join(band, by = c("c", "period"))

# slope per 0.1 completeness (curves share a shape, so one slope)
slope_of <- function(d) {
  d |> arrange(c) |> mutate(slope = 0.1 * (lead(pre) - lag(pre)) / (lead(c) - lag(c)))
}
sl <- slope_of(cur) |> select(c, slope)
sl_b <- boot |> group_by(b) |> group_modify(~ slope_of(.x)) |> ungroup() |>
  summarise(lo = quantile(slope, .025, na.rm = TRUE), hi = quantile(slope, .975, na.rm = TRUE), .by = c)
sl <- sl |> left_join(sl_b, by = "c") |> filter(!is.na(slope))

cat("slope of the correlation per +0.1 completeness, by level\n")
print(sl |> filter(c %in% unique(sl$c[c(5, 15, 25, 35, 45, 52)])) |> mutate(across(everything(), ~ round(.x, 3))) |> as.data.frame())
cat("mean slope below 0.6:", round(mean(sl$slope[sl$c < 0.6]), 3), " 0.6-0.85:", round(mean(sl$slope[sl$c >= 0.6 & sl$c < 0.85]), 3),
    " above 0.85:", round(mean(sl$slope[sl$c >= 0.85]), 3), "\n")

pa <-
  ggplot() +
  geom_ribbon(data = curve, aes(c, ymin = lo, ymax = hi, fill = period), alpha = 0.15) +
  geom_line(data = curve, aes(c, r, col = period), linewidth = 1) +
  geom_segment(data = pts |> select(cod, period, c, r_levels) |> pivot_wider(names_from = period, values_from = c(c, r_levels)),
               aes(x = c_pre, y = r_levels_pre, xend = c_post, yend = r_levels_post),
               col = "grey60", linewidth = 0.3, arrow = arrow(length = unit(0.12, "cm"))) +
  geom_point(data = pts, aes(c, r_levels, col = period, shape = caribe), size = 2) +
  scale_color_manual(values = c(pre = "#CA6702", post = "#1d3557"), labels = c(pre = "1985-1997", post = "1998-2017")) +
  scale_fill_manual(values = c(pre = "#CA6702", post = "#1d3557"), guide = "none") +
  scale_shape_manual(values = c("FALSE" = 16, "TRUE" = 17), labels = c("FALSE" = "other", "TRUE" = "Caribbean")) +
  coord_cartesian(ylim = c(-0.1, 1)) +
  labs(x = "registration completeness (DDM hybrid, mean of sexes)", y = "correlation, sex ratio vs homicide rate",
       col = NULL, shape = NULL, title = "A. Correlation against completeness, by department") +
  theme_minimal(base_size = 11) + theme(legend.position = "bottom")

pc <-
  ggplot(sl, aes(c, slope)) +
  geom_hline(yintercept = 0, lty = "dashed", col = "grey50") +
  geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.2) +
  geom_line(linewidth = 1) +
  labs(x = "registration completeness", y = "gain in correlation per +0.1 completeness",
       title = "B. Local slope of the curve") +
  theme_minimal(base_size = 11)

ggsave("figures/05_underregistration_tests/completeness_vs_correlation.png",
       pa + pc + plot_layout(widths = c(1.6, 1)), w = 11, h = 4.8, dpi = 150)
