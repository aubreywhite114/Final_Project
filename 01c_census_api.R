# =============================================================================
# 01c_census_api.R
# PURPOSE: Pull county- and state-level socioeconomic variables from the
#          U.S. Census Bureau ACS 5-Year Estimates (2019–2023)
# API:     Census Bureau via tidycensus
# SETUP:   Store your key in .Renviron as CENSUS_API_KEY=your_key_here
#          Get a key at: https://api.census.gov/data/key_signup.html
# =============================================================================

library(tidycensus)
library(dplyr)
library(here)

# ── Load API key from environment (NEVER hard-code) ───────────────────────────
census_key <- Sys.getenv("CENSUS_API_KEY")

if (census_key == "") {
  stop(
    "Census API key not found.\n",
    "Add CENSUS_API_KEY=your_key to your .Renviron file and restart R.\n",
    "Run: usethis::edit_r_environ()"
  )
}

tidycensus::census_api_key(census_key, install = FALSE)

# ── Variables to pull from ACS 5-Year ────────────────────────────────────────
# B17001_002: Population below poverty level
# B17001_001: Total population for poverty universe
# B19013_001: Median household income
# B23025_005: Unemployed (in labor force)
# B23025_002: Total in labor force

acs_vars <- c(
  pop_below_poverty  = "B17001_002",
  pop_poverty_total  = "B17001_001",
  median_income      = "B19013_001",
  unemployed         = "B23025_005",
  labor_force_total  = "B23025_002",
  total_population   = "B01003_001"
)

# ── Pull COUNTY-level data (most recent 5-year: 2023) ────────────────────────
message("Pulling ACS county-level data for 2023...")

census_county_raw <- tidycensus::get_acs(
  geography = "county",
  variables = acs_vars,
  year      = 2023,
  survey    = "acs5",
  output    = "wide",   # one row per county
  geometry  = FALSE
)

message("County records pulled: ", nrow(census_county_raw))

# ── Pull STATE-level data ─────────────────────────────────────────────────────
message("Pulling ACS state-level data for 2023...")

census_state_raw <- tidycensus::get_acs(
  geography = "state",
  variables = acs_vars,
  year      = 2023,
  survey    = "acs5",
  output    = "wide",
  geometry  = FALSE
)

message("State records pulled: ", nrow(census_state_raw))

# ── Preview ───────────────────────────────────────────────────────────────────
message("\n--- Census County Columns ---")
print(names(census_county_raw))
print(head(census_county_raw, 3))

# ── Save ──────────────────────────────────────────────────────────────────────
saveRDS(census_county_raw, here("data", "raw", "census_county_raw.rds"))
saveRDS(census_state_raw,  here("data", "raw", "census_state_raw.rds"))

message("\n✓ 01c complete: Census data saved to data/raw/")
