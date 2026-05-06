# =============================================================================
# 05_eda_summaries.R
# PURPOSE: Produce descriptive summaries and exploratory visuals for the
#          final merged food insecurity dataset
# INPUT:   data/final/food_insecurity_final.rds
# OUTPUT:  Printed summary tables + plots saved to data/final/plots/
#
# COVERS (per project requirements):
#   - Summary statistics for all key variables
#   - Data quality / missingness overview
#   - Ohio vs. U.S. comparison visuals
#   - County-level distribution within Ohio
#   - Trend analysis 2019–2023
# =============================================================================

library(dplyr)
library(ggplot2)
library(tidyr)
library(stringr)
library(scales)
library(here)

# ── Setup ─────────────────────────────────────────────────────────────────────
df <- readRDS(here("data", "final", "food_insecurity_final.rds"))

plot_dir <- here("data", "final", "plots")
dir.create(plot_dir, showWarnings = FALSE, recursive = TRUE)

message("Dataset loaded: ", nrow(df), " rows x ", ncol(df), " cols")
message("Years: ", paste(sort(unique(df$year)), collapse = ", "))
message("States: ", length(unique(df$state_name)))

# =============================================================================
# 1. OVERALL SUMMARY STATISTICS
# =============================================================================

message("\n", strrep("=", 60))
message("1. OVERALL SUMMARY STATISTICS")
message(strrep("=", 60))

key_vars <- c("fi_rate", "child_fi_rate", "meal_cost",
              "poverty_rate", "unemployment_rate", "median_income")

summary_stats <- df |>
  dplyr::filter(year == 2023) |>     # use most recent year for snapshot
  dplyr::summarise(
    dplyr::across(
      dplyr::all_of(key_vars),
      list(
        n       = ~ sum(!is.na(.)),
        mean    = ~ round(mean(., na.rm = TRUE), 3),
        median  = ~ round(median(., na.rm = TRUE), 3),
        sd      = ~ round(sd(., na.rm = TRUE), 3),
        min     = ~ round(min(., na.rm = TRUE), 3),
        max     = ~ round(max(., na.rm = TRUE), 3),
        missing = ~ sum(is.na(.))
      ),
      .names = "{.col}__{.fn}"
    )
  ) |>
  tidyr::pivot_longer(everything(),
                      names_to  = c("variable", "stat"),
                      names_sep = "__") |>
  tidyr::pivot_wider(names_from = stat, values_from = value)

message("\nSummary statistics (2023 snapshot):")
print(summary_stats, n = Inf)

# =============================================================================
# 2. MISSINGNESS OVERVIEW
# =============================================================================

message("\n", strrep("=", 60))
message("2. MISSINGNESS OVERVIEW")
message(strrep("=", 60))

missing_overview <- df |>
  dplyr::summarise(
    dplyr::across(
      dplyr::all_of(key_vars),
      ~ round(100 * mean(is.na(.)), 1),
      .names = "{.col}_pct_missing"
    )
  ) |>
  tidyr::pivot_longer(everything(),
                      names_to  = "variable",
                      values_to = "pct_missing") |>
  dplyr::mutate(variable = stringr::str_remove(variable, "_pct_missing")) |>
  dplyr::arrange(desc(pct_missing))

message("\nMissingness by variable (all years):")
print(missing_overview)

# =============================================================================
# 3. OHIO vs. U.S. SUMMARY (2023)
# =============================================================================

message("\n", strrep("=", 60))
message("3. OHIO vs. U.S. COMPARISON (2023)")
message(strrep("=", 60))

comparison_2023 <- df |>
  dplyr::filter(year == 2023) |>
  dplyr::group_by(is_ohio) |>
  dplyr::summarise(
    n_counties           = dplyr::n(),
    avg_fi_rate          = round(mean(fi_rate,        na.rm = TRUE), 3),
    avg_child_fi_rate    = round(mean(child_fi_rate,  na.rm = TRUE), 3),
    avg_meal_cost        = round(mean(meal_cost,      na.rm = TRUE), 2),
    avg_poverty_rate     = round(mean(poverty_rate,   na.rm = TRUE), 3),
    avg_unemployment     = round(mean(unemployment_rate, na.rm = TRUE), 3),
    avg_median_income    = round(mean(median_income,  na.rm = TRUE), 0),
    .groups = "drop"
  ) |>
  dplyr::mutate(group = ifelse(is_ohio, "Ohio", "Rest of U.S.")) |>
  dplyr::select(group, everything(), -is_ohio)

message("\nOhio vs. Rest of U.S. (2023 county averages):")
print(comparison_2023)

# =============================================================================
# 4. OHIO STATE-LEVEL TREND 2019–2023
# =============================================================================

message("\n", strrep("=", 60))
message("4. OHIO FOOD INSECURITY TREND 2019-2023")
message(strrep("=", 60))

ohio_trend <- df |>
  dplyr::filter(is_ohio) |>
  dplyr::group_by(year) |>
  dplyr::summarise(
    avg_fi_rate       = round(mean(fi_rate,       na.rm = TRUE), 3),
    avg_child_fi_rate = round(mean(child_fi_rate, na.rm = TRUE), 3),
    total_fi_persons  = sum(fi_count,             na.rm = TRUE),
    .groups = "drop"
  )

message("\nOhio trend:")
print(ohio_trend)

us_trend <- df |>
  dplyr::filter(!is_ohio) |>
  dplyr::group_by(year) |>
  dplyr::summarise(
    avg_fi_rate = round(mean(fi_rate, na.rm = TRUE), 3),
    .groups = "drop"
  ) |>
  dplyr::rename(us_avg_fi_rate = avg_fi_rate)

trend_compare <- dplyr::left_join(ohio_trend, us_trend, by = "year") |>
  dplyr::mutate(
    ohio_vs_us_diff = round(avg_fi_rate - us_avg_fi_rate, 3)
  )

message("\nOhio vs. U.S. trend comparison:")
print(trend_compare)

# =============================================================================
# 5. TOP / BOTTOM OHIO COUNTIES (2023)
# =============================================================================

message("\n", strrep("=", 60))
message("5. OHIO COUNTY RANKINGS (2023)")
message(strrep("=", 60))

ohio_counties_2023 <- df |>
  dplyr::filter(is_ohio, year == 2023) |>
  dplyr::arrange(desc(fi_rate))

message("\nTop 10 Ohio counties by food insecurity (2023):")
print(ohio_counties_2023 |>
        dplyr::select(county_name, fi_rate, child_fi_rate, poverty_rate, median_income) |>
        head(10))

message("\nBottom 10 Ohio counties by food insecurity (2023):")
print(ohio_counties_2023 |>
        dplyr::select(county_name, fi_rate, child_fi_rate, poverty_rate, median_income) |>
        tail(10))

# =============================================================================
# 6. VISUALIZATIONS
# =============================================================================

message("\n", strrep("=", 60))
message("6. SAVING EXPLORATORY PLOTS")
message(strrep("=", 60))

# ── Plot 1: Ohio vs. U.S. food insecurity rate trend ─────────────────────────
trend_long <- trend_compare |>
  dplyr::select(year, Ohio = avg_fi_rate, `U.S. Average` = us_avg_fi_rate) |>
  tidyr::pivot_longer(-year, names_to = "group", values_to = "fi_rate")

p1 <- ggplot2::ggplot(trend_long,
                      ggplot2::aes(x = year, y = fi_rate,
                                   color = group, group = group)) +
  ggplot2::geom_line(linewidth = 1.2) +
  ggplot2::geom_point(size = 3) +
  ggplot2::scale_y_continuous(labels = scales::percent_format(accuracy = 0.1),
                               limits = c(0, NA)) +
  ggplot2::scale_color_manual(values = c("Ohio" = "#C8102E", "U.S. Average" = "#003087")) +
  ggplot2::labs(
    title    = "Food Insecurity Rate: Ohio vs. U.S. Average (2019–2023)",
    subtitle = "County-level averages from Feeding America Map the Meal Gap",
    x        = "Year",
    y        = "Food Insecurity Rate",
    color    = NULL,
    caption  = "Source: Feeding America MMG2025; U.S. Census Bureau ACS"
  ) +
  ggplot2::theme_minimal(base_size = 13) +
  ggplot2::theme(legend.position = "top")

ggplot2::ggsave(file.path(plot_dir, "01_ohio_vs_us_trend.png"),
                p1, width = 9, height = 5.5, dpi = 150)
message("  Saved: 01_ohio_vs_us_trend.png")

# ── Plot 2: Distribution of county food insecurity rates (2023) ───────────────
p2 <- df |>
  dplyr::filter(year == 2023, !is.na(fi_rate)) |>
  dplyr::mutate(group = ifelse(is_ohio, "Ohio Counties", "All Other U.S. Counties")) |>
  ggplot2::ggplot(ggplot2::aes(x = fi_rate, fill = group)) +
  ggplot2::geom_histogram(bins = 40, alpha = 0.7, position = "identity") +
  ggplot2::scale_x_continuous(labels = scales::percent_format(accuracy = 1)) +
  ggplot2::scale_fill_manual(values = c("Ohio Counties" = "#C8102E",
                                        "All Other U.S. Counties" = "#A8B5C1")) +
  ggplot2::labs(
    title   = "Distribution of County Food Insecurity Rates (2023)",
    x       = "Food Insecurity Rate",
    y       = "Number of Counties",
    fill    = NULL,
    caption = "Source: Feeding America Map the Meal Gap 2025"
  ) +
  ggplot2::theme_minimal(base_size = 13) +
  ggplot2::theme(legend.position = "top")

ggplot2::ggsave(file.path(plot_dir, "02_county_fi_distribution.png"),
                p2, width = 9, height = 5.5, dpi = 150)
message("  Saved: 02_county_fi_distribution.png")

# ── Plot 3: Ohio counties — food insecurity vs. poverty rate (2023) ───────────
p3 <- df |>
  dplyr::filter(is_ohio, year == 2023, !is.na(fi_rate), !is.na(poverty_rate)) |>
  ggplot2::ggplot(ggplot2::aes(x = poverty_rate, y = fi_rate,
                               label = county_name)) +
  ggplot2::geom_point(color = "#C8102E", alpha = 0.7, size = 2.5) +
  ggplot2::geom_smooth(method = "lm", se = TRUE, color = "#003087",
                       linewidth = 1) +
  ggplot2::scale_x_continuous(labels = scales::percent_format(accuracy = 1)) +
  ggplot2::scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
  ggplot2::labs(
    title   = "Food Insecurity vs. Poverty Rate — Ohio Counties (2023)",
    x       = "Poverty Rate (ACS 2023)",
    y       = "Food Insecurity Rate (MMG)",
    caption = "Source: Feeding America MMG2025; U.S. Census Bureau ACS 2023"
  ) +
  ggplot2::theme_minimal(base_size = 13)

ggplot2::ggsave(file.path(plot_dir, "03_ohio_fi_vs_poverty.png"),
                p3, width = 9, height = 5.5, dpi = 150)
message("  Saved: 03_ohio_fi_vs_poverty.png")

# ── Plot 4: Top 15 Ohio counties by food insecurity rate (2023) ───────────────
p4 <- ohio_counties_2023 |>
  head(15) |>
  dplyr::mutate(county_name = stringr::str_remove(county_name, ",.*")) |>
  ggplot2::ggplot(ggplot2::aes(x = fi_rate,
                               y = reorder(county_name, fi_rate))) +
  ggplot2::geom_col(fill = "#C8102E", alpha = 0.85) +
  ggplot2::geom_vline(
    xintercept = mean(df$fi_rate[df$year == 2023], na.rm = TRUE),
    linetype = "dashed", color = "#003087", linewidth = 0.8
  ) +
  ggplot2::scale_x_continuous(labels = scales::percent_format(accuracy = 1)) +
  ggplot2::labs(
    title    = "Top 15 Ohio Counties by Food Insecurity Rate (2023)",
    subtitle = "Dashed line = U.S. county average",
    x        = "Food Insecurity Rate",
    y        = NULL,
    caption  = "Source: Feeding America Map the Meal Gap 2025"
  ) +
  ggplot2::theme_minimal(base_size = 12)

ggplot2::ggsave(file.path(plot_dir, "04_ohio_top15_counties.png"),
                p4, width = 9, height = 6, dpi = 150)
message("  Saved: 04_ohio_top15_counties.png")

# =============================================================================
# 7. SAVE SUMMARY TABLES AS CSV
# =============================================================================

write.csv(summary_stats,    here("data", "final", "eda_summary_stats.csv"),
          row.names = FALSE)
write.csv(comparison_2023,  here("data", "final", "eda_ohio_vs_us_2023.csv"),
          row.names = FALSE)
write.csv(trend_compare,    here("data", "final", "eda_trend_2019_2023.csv"),
          row.names = FALSE)

message("\n✓ 05 complete: EDA summaries and plots saved.")
message("  Plots in:  data/final/plots/")
message("  Tables in: data/final/")

