# =============================================================================
# 02a_clean_mmg.R
# PURPOSE: Clean and standardize the MMG county and state data
# INPUT:   data/raw/mmg_county_raw.rds, data/raw/mmg_state_raw.rds
# OUTPUT:  data/raw/mmg_county_clean.rds, data/raw/mmg_state_clean.rds
# =============================================================================

library(dplyr)
library(janitor)
library(stringr)
library(here)

# ── Load raw data ─────────────────────────────────────────────────────────────
mmg_county <- readRDS(here("data", "raw", "mmg_county_raw.rds"))
mmg_state  <- readRDS(here("data", "raw", "mmg_state_raw.rds"))

# ── Diagnostic: print exact column names before any cleaning ─────────────────
message("Raw county column names:")
print(names(mmg_county))

message("\nRaw state column names:")
print(names(mmg_state))

# ── Helper: standardize FIPS to 5-digit string ───────────────────────────────
pad_fips <- function(x) stringr::str_pad(as.character(x), width = 5, pad = "0")

# =============================================================================
# COUNTY-LEVEL CLEANING
# Uses exact column names from MMG2025 file after clean_names()
# =============================================================================

mmg_county_clean <- mmg_county |>
  
  # 1. Standardize to snake_case
  janitor::clean_names() |>
  
  # 2. Rename using exact post-clean_names() column names
  #    If you get an "unknown column" error here, run:
  #    mmg_county |> janitor::clean_names() |> names()
  #    and update the RIGHT side of each rename to match what you see
  dplyr::rename(
    fips          = fips,
    state         = state,
    county_name   = county_state,
    year          = year,
    fi_rate       = overall_food_insecurity_rate,
    fi_count      = number_of_food_insecure_persons_overall,
    child_fi_rate = child_food_insecurity_rate,
    fi_count_child = number_of_food_insecure_children,
    meal_cost     = cost_per_meal,
    fi_below_snap = percent_fi_snap_threshold,
    fi_above_snap = percent_fi_snap_threshold_2,
    rural_urban_2013 = rural_urban_continuum_code_2013,
    rural_urban_2023 = rural_urban_continuum_code_2023
  ) |>
  
  # 3. Standardize FIPS codes to 5-digit zero-padded string
  dplyr::mutate(
    fips = pad_fips(fips)
  ) |>
  
  # 4. Coerce key columns to numeric
  dplyr::mutate(
    across(c(fi_rate, fi_count, child_fi_rate, meal_cost), as.numeric)
  ) |>
  
  # 5. Clean county name string
  dplyr::mutate(
    county_name = stringr::str_trim(county_name)
  ) |>
  
  # 6. Remove fully blank rows
  dplyr::filter(!is.na(fips) & !is.na(state)) |>
  
  # 7. Remove duplicate FIPS + year combinations (keep first occurrence)
  dplyr::distinct(fips, year, .keep_all = TRUE) |>
  
  # 8. Flag rows with missing key values
  dplyr::mutate(
    missing_fi_rate   = is.na(fi_rate),
    missing_fi_count  = is.na(fi_count),
    missing_meal_cost = is.na(meal_cost)
  )

message("MMG County cleaned: ", nrow(mmg_county_clean), " rows")
message("Missing fi_rate:    ", sum(mmg_county_clean$missing_fi_rate))
message("Missing meal_cost:  ", sum(mmg_county_clean$missing_meal_cost))
message("Column names after cleaning:")
print(names(mmg_county_clean))

# =============================================================================
# STATE-LEVEL CLEANING
# =============================================================================

mmg_state_clean <- mmg_state |>
  
  janitor::clean_names() |>
  
  dplyr::rename(
    fips              = fips,
    state_name        = state_name,
    state             = state,
    year              = year,
    fi_rate           = overall_food_insecurity_rate,
    fi_count          = number_of_food_insecure_persons_overall,
    child_fi_rate     = child_food_insecurity_rate,
    fi_count_child    = number_of_food_insecure_children,
    senior_fi_rate    = senior_food_insecurity_rate,
    fi_count_senior   = number_of_food_insecure_seniors,
    older_adult_fi_rate = older_adult_food_insecurity_rate,
    meal_cost         = cost_per_meal,
    annual_shortfall  = weighted_annual_food_budget_shortfall,
    snap_threshold    = snap_threshold_in_state,
    fi_below_snap     = percent_fi_snap_threshold,
    fi_above_snap     = percent_fi_snap_threshold_2,
    child_fi_below_185fpl = percent_food_insecure_children_in_hh_w_hh_incomes_below_185_fpl,
    child_fi_above_185fpl = percent_food_insecure_children_in_hh_w_hh_incomes_above_185_fpl,
    black_fi_rate     = food_insecurity_rate_among_black_persons_all_ethnicities,
    hispanic_fi_rate  = food_insecurity_rate_among_hispanic_persons_any_race,
    white_fi_rate     = food_insecurity_rate_among_white_non_hispanic_persons
  ) |>
  
  dplyr::mutate(
    across(c(fi_rate, fi_count, child_fi_rate, senior_fi_rate, meal_cost), as.numeric),
    state_name = stringr::str_trim(state_name)
  ) |>
  
  dplyr::filter(!is.na(state_name)) |>
  dplyr::distinct(state, year, .keep_all = TRUE)

message("\nMMG State cleaned: ", nrow(mmg_state_clean), " rows")

# ── Save ──────────────────────────────────────────────────────────────────────
saveRDS(mmg_county_clean, here("data", "raw", "mmg_county_clean.rds"))
saveRDS(mmg_state_clean,  here("data", "raw", "mmg_state_clean.rds"))

message("\n✓ 02a complete: MMG data cleaned and saved.")

