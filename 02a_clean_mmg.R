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

mmg_state_path <- here("data", "raw", "mmg_state_raw.rds")
mmg_state <- if (file.exists(mmg_state_path)) readRDS(mmg_state_path) else NULL

# ── Helper: standardize FIPS to 5-digit string ───────────────────────────────
pad_fips <- function(x) stringr::str_pad(as.character(x), width = 5, pad = "0")

# =============================================================================
# COUNTY-LEVEL CLEANING
# =============================================================================

mmg_county_clean <- mmg_county |>

  # 1. Standardize column names (snake_case, no spaces)
  janitor::clean_names() |>

  # 2. Rename key columns to consistent names
  #    ⚠️ Update these to match your actual column names from 01a preview
  dplyr::rename_with(~ dplyr::case_when(
    grepl("fips|county_fips|fips_code", .x, ignore.case = TRUE)           ~ "fips",
    grepl("state.*name|state_name",     .x, ignore.case = TRUE)           ~ "state_name",
    grepl("county.*name|county_name",   .x, ignore.case = TRUE)           ~ "county_name",
    grepl("year",                       .x, ignore.case = TRUE)           ~ "year",
    grepl("food_insec.*rate|fi.*rate|pct.*fi", .x, ignore.case = TRUE)    ~ "fi_rate",
    grepl("food_insec.*num|num.*fi|#.*fi",     .x, ignore.case = TRUE)    ~ "fi_count",
    grepl("child.*food|child.*fi|fi.*child",   .x, ignore.case = TRUE)    ~ "child_fi_rate",
    grepl("cost.*meal|meal.*cost|avg.*cost",   .x, ignore.case = TRUE)    ~ "meal_cost",
    TRUE ~ .x
  )) |>

  # 3. Standardize FIPS codes
  dplyr::mutate(
    fips = pad_fips(fips)
  ) |>

  # 4. Coerce numeric columns
  dplyr::mutate(
    across(c(fi_rate, fi_count, child_fi_rate, meal_cost), as.numeric)
  ) |>

  # 5. Clean state and county names
  dplyr::mutate(
    state_name  = stringr::str_trim(stringr::str_to_title(state_name)),
    county_name = stringr::str_trim(county_name)
  ) |>

  # 6. Remove fully blank rows
  dplyr::filter(!is.na(fips) & !is.na(state_name)) |>

  # 7. Remove duplicate FIPS + year combinations (keep first occurrence)
  dplyr::distinct(fips, year, .keep_all = TRUE) |>

  # 8. Flag rows with any missing key values
  dplyr::mutate(
    missing_fi_rate    = is.na(fi_rate),
    missing_fi_count   = is.na(fi_count),
    missing_meal_cost  = is.na(meal_cost)
  )

message("MMG County cleaned: ", nrow(mmg_county_clean), " rows")
message("Missing fi_rate:   ", sum(mmg_county_clean$missing_fi_rate))
message("Missing meal_cost: ", sum(mmg_county_clean$missing_meal_cost))

# =============================================================================
# STATE-LEVEL CLEANING (if available)
# =============================================================================

if (!is.null(mmg_state)) {
  mmg_state_clean <- mmg_state |>
    janitor::clean_names() |>
    dplyr::rename_with(~ dplyr::case_when(
      grepl("state.*name|state_name",          .x, ignore.case = TRUE) ~ "state_name",
      grepl("food_insec.*rate|fi.*rate",        .x, ignore.case = TRUE) ~ "fi_rate",
      grepl("food_insec.*num|num.*fi",          .x, ignore.case = TRUE) ~ "fi_count",
      grepl("child.*food|child.*fi",            .x, ignore.case = TRUE) ~ "child_fi_rate",
      grepl("cost.*meal|meal.*cost",            .x, ignore.case = TRUE) ~ "meal_cost",
      grepl("year",                             .x, ignore.case = TRUE) ~ "year",
      TRUE ~ .x
    )) |>
    dplyr::mutate(
      across(c(fi_rate, fi_count, child_fi_rate, meal_cost), as.numeric),
      state_name = stringr::str_trim(stringr::str_to_title(state_name))
    ) |>
    dplyr::filter(!is.na(state_name)) |>
    dplyr::distinct(state_name, year, .keep_all = TRUE)

  message("MMG State cleaned: ", nrow(mmg_state_clean), " rows")
  saveRDS(mmg_state_clean, here("data", "raw", "mmg_state_clean.rds"))
}

# ── Save ──────────────────────────────────────────────────────────────────────
saveRDS(mmg_county_clean, here("data", "raw", "mmg_county_clean.rds"))

message("\n✓ 02a complete: MMG data cleaned and saved.")
