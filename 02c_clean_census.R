# =============================================================================
# 02c_clean_census.R
# PURPOSE: Clean and derive variables from ACS Census data
# INPUT:   data/raw/census_county_raw.rds, data/raw/census_state_raw.rds
# OUTPUT:  data/raw/census_county_clean.rds, data/raw/census_state_clean.rds
# =============================================================================

library(dplyr)
library(stringr)
library(janitor)
library(here)

# ── Load ──────────────────────────────────────────────────────────────────────
census_county <- readRDS(here("data", "raw", "census_county_raw.rds"))
census_state  <- readRDS(here("data", "raw", "census_state_raw.rds"))

# ── Helper: pad FIPS ──────────────────────────────────────────────────────────
pad_fips <- function(x) stringr::str_pad(as.character(x), width = 5, pad = "0")

# ── Clean column names from tidycensus wide output ────────────────────────────
# tidycensus appends E (estimate) and M (margin of error) suffixes
# We keep only estimate columns (ending in E)

clean_census <- function(df, geo_type = "county") {

  df_clean <- df |>
    janitor::clean_names() |>

    # Rename GEOID and NAME
    dplyr::rename(
      geoid     = geoid,
      geo_name  = name
    ) |>

    # Keep only estimate columns (drop margin of error "_m" columns)
    dplyr::select(geoid, geo_name, dplyr::ends_with("_e")) |>

    # Rename estimate columns to remove the trailing _e
    dplyr::rename_with(~ stringr::str_remove(.x, "_e$"),
                       dplyr::ends_with("_e")) |>

    # Derive computed variables
    dplyr::mutate(
      # Poverty rate = (below poverty / total poverty universe) * 100
      poverty_rate = dplyr::case_when(
        pop_poverty_total > 0 ~ (pop_below_poverty / pop_poverty_total) * 100,
        TRUE                  ~ NA_real_
      ),
      # Unemployment rate = (unemployed / labor force total) * 100
      unemployment_rate = dplyr::case_when(
        labor_force_total > 0 ~ (unemployed / labor_force_total) * 100,
        TRUE                  ~ NA_real_
      ),
      # Median income: keep as-is; flag negatives or zero as invalid
      income_invalid = !is.na(median_income) & median_income <= 0
    )

  if (geo_type == "county") {
    df_clean <- df_clean |>
      dplyr::mutate(
        fips       = pad_fips(geoid),
        state_fips = stringr::str_sub(fips, 1, 2),
        # Parse county name (Census format: "County Name, State")
        county_name = stringr::str_extract(geo_name, "^[^,]+"),
        state_name  = stringr::str_extract(geo_name, "(?<=, ).+") |>
          stringr::str_trim()
      )
  } else {
    df_clean <- df_clean |>
      dplyr::mutate(
        state_fips = pad_fips(geoid),
        state_name = stringr::str_trim(geo_name)
      )
  }

  # Flag implausible values
  df_clean <- df_clean |>
    dplyr::mutate(
      poverty_rate_invalid      = !is.na(poverty_rate)      & (poverty_rate < 0 | poverty_rate > 100),
      unemployment_rate_invalid = !is.na(unemployment_rate) & (unemployment_rate < 0 | unemployment_rate > 100)
    )

  df_clean
}

# ── Apply cleaning ────────────────────────────────────────────────────────────
census_county_clean <- clean_census(census_county, geo_type = "county")
census_state_clean  <- clean_census(census_state,  geo_type = "state")

message("Census county cleaned: ", nrow(census_county_clean), " rows")
message("Census state cleaned:  ", nrow(census_state_clean), " rows")
message("Counties with invalid income: ",
        sum(census_county_clean$income_invalid, na.rm = TRUE))

print(head(census_county_clean |>
             dplyr::select(fips, county_name, state_name,
                           poverty_rate, unemployment_rate, median_income), 5))

# ── Save ──────────────────────────────────────────────────────────────────────
saveRDS(census_county_clean, here("data", "raw", "census_county_clean.rds"))
saveRDS(census_state_clean,  here("data", "raw", "census_state_clean.rds"))

message("\n✓ 02c complete: Census data cleaned and saved.")

