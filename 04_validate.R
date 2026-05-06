# =============================================================================
# 04_validate.R
# PURPOSE: Run data quality checks and produce a validation table
# INPUT:   data/final/food_insecurity_final.rds
# OUTPUT:  Printed validation table + data/final/validation_table.csv
# =============================================================================

library(dplyr)
library(tidyr)
library(stringr)
library(tibble)
library(here)

# ── Load final merged dataset ─────────────────────────────────────────────────
df <- readRDS(here("data", "final", "food_insecurity_final.rds"))

message("Validating dataset: ", nrow(df), " rows x ", ncol(df), " cols\n")

# =============================================================================
# CHECK FUNCTIONS
# Each returns a tidy data frame: check_name | n_violations | pct | examples
# =============================================================================

run_check <- function(check_name, condition_vec, df, id_cols = c("fips", "county_name", "state_name", "year")) {
  violations <- df[condition_vec, ]
  n   <- nrow(violations)
  pct <- round(100 * n / nrow(df), 2)
  
  examples <- if (n > 0) {
    violations |>
      dplyr::select(dplyr::any_of(id_cols)) |>
      head(3) |>
      apply(1, paste, collapse = " | ") |>
      paste(collapse = " ;; ")
  } else {
    "—"
  }
  
  data.frame(
    check_name   = check_name,
    n_violations = n,
    pct_of_data  = pct,
    examples     = examples,
    stringsAsFactors = FALSE
  )
}

# =============================================================================
# DEFINE CHECKS
# =============================================================================

checks <- list(
  
  # 1. Duplicate FIPS + year combinations
  run_check(
    "Duplicate FIPS + year",
    duplicated(df[, c("fips", "year")]),
    df
  ),
  
  # 2. Missing food insecurity rate
  run_check(
    "Missing fi_rate",
    is.na(df$fi_rate),
    df
  ),
  
  # 3. Food insecurity rate out of range (0–100%)
  run_check(
    "fi_rate out of range (0–100)",
    !is.na(df$fi_rate) & (df$fi_rate < 0 | df$fi_rate > 100),
    df
  ),
  
  # 4. Missing food insecure count
  run_check(
    "Missing fi_count",
    is.na(df$fi_count),
    df
  ),
  
  # 5. Negative food insecure count
  run_check(
    "Negative fi_count",
    !is.na(df$fi_count) & df$fi_count < 0,
    df
  ),
  
  # 6. Meal cost implausibly low (< $1) or high (> $25)
  run_check(
    "meal_cost outside $1–$25 range",
    !is.na(df$meal_cost) & (df$meal_cost < 1 | df$meal_cost > 25),
    df
  ),
  
  # 7. Missing meal cost
  run_check(
    "Missing meal_cost",
    is.na(df$meal_cost),
    df
  ),
  
  # 8. Poverty rate out of range
  run_check(
    "poverty_rate out of range (0–100)",
    !is.na(df$poverty_rate) & (df$poverty_rate < 0 | df$poverty_rate > 100),
    df
  ),
  
  # 9. Unemployment rate out of range
  run_check(
    "unemployment_rate out of range (0–100)",
    !is.na(df$unemployment_rate) & (df$unemployment_rate < 0 | df$unemployment_rate > 100),
    df
  ),
  
  # 10. Invalid median income (zero or negative)
  run_check(
    "median_income <= 0",
    !is.na(df$median_income) & df$median_income <= 0,
    df
  ),
  
  # 11. Missing FIPS code
  run_check(
    "Missing FIPS",
    is.na(df$fips) | nchar(df$fips) != 5,
    df
  ),
  
  # 12. Failed Census join (no Census data matched)
  run_check(
    "No Census data joined (census_join_flag)",
    isTRUE(df$census_join_flag),
    df
  ),
  
  # 13. Child food insecurity rate exceeds total fi_rate
  run_check(
    "child_fi_rate > fi_rate (impossible)",
    !is.na(df$child_fi_rate) & !is.na(df$fi_rate) & df$child_fi_rate > df$fi_rate,
    df
  ),
  
  # 14. Year outside expected range (2019–2023)
  run_check(
    "year outside 2019–2023",
    !is.na(df$year) & (df$year < 2019 | df$year > 2023),
    df
  ),
  
  # 15. Missing state name
  run_check(
    "Missing state_name",
    is.na(df$state_name) | df$state_name == "",
    df
  )
)

# =============================================================================
# COMBINE AND PRINT
# =============================================================================

validation_table <- dplyr::bind_rows(checks) |> tibble::as_tibble()

message("=" |> strrep(70))
message("DATA VALIDATION TABLE")
message("=" |> strrep(70))
print(validation_table |> dplyr::select(check_name, n_violations, pct_of_data),
      n = Inf, right = FALSE)

# Flag overall pass/fail
total_violations <- sum(validation_table$n_violations)
message("\nTotal rule violations found: ", total_violations)

if (total_violations == 0) {
  message("✓ All checks passed — dataset is clean.")
} else {
  message("⚠ Review violations above before finalizing analysis.")
}

# ── Save validation table ─────────────────────────────────────────────────────
write.csv(validation_table,
          here("data", "final", "validation_table.csv"),
          row.names = FALSE, na = "")

message("\n✓ 04 complete: Validation table saved to data/final/validation_table.csv")

