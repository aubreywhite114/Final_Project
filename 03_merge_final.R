# =============================================================================
# 03_merge_final.R
# PURPOSE: Merge MMG Excel, FRAC scraped, and Census API data into one
#          tidy final dataset
# INPUT:   Cleaned .rds files from 02_cleaning/
# OUTPUT:  data/final/food_insecurity_final.csv
#          data/final/food_insecurity_final.xlsx
#          data/final/food_insecurity_final.rds
#
# MERGE STRATEGY:
#   Layer 1 (primary):  MMG county data (2019-2023) + Census county (2023 ACS)
#                       Joined on FIPS code (5-digit padded string)
#   Layer 2 (context):  FRAC national/state range stats joined at state level
#                       Joined on state abbreviation
#   Final output is one row per county-year with all variables aligned.
# =============================================================================

library(dplyr)
library(stringr)
library(here)
library(writexl)
library(readr)

# ── Load all cleaned datasets ─────────────────────────────────────────────────
mmg_county    <- readRDS(here("data", "raw", "mmg_county_clean.rds"))
census_county <- readRDS(here("data", "raw", "census_county_clean.rds"))
frac_range    <- readRDS(here("data", "raw", "frac_range_clean.rds"))
frac_summary  <- readRDS(here("data", "raw", "frac_summary_clean.rds"))

# Optional: MMG state data if available
mmg_state_path <- here("data", "raw", "mmg_state_clean.rds")
mmg_state <- if (file.exists(mmg_state_path)) readRDS(mmg_state_path) else NULL

message("MMG county rows:    ", nrow(mmg_county))
message("Census county rows: ", nrow(census_county))
message("FRAC range rows:    ", nrow(frac_range))

# ── Step 1: Join MMG county ←→ Census county on FIPS ─────────────────────────
# Census data is 2023 ACS — applied to all MMG years as contextual background
message("\nStep 1: Joining MMG county + Census county on FIPS...")

mmg_census_county <- dplyr::left_join(
  mmg_county,
  census_county |> dplyr::select(
    fips,
    poverty_rate,
    unemployment_rate,
    median_income,
    total_population,
    income_invalid,
    poverty_rate_invalid,
    unemployment_rate_invalid
  ),
  by = "fips"
)

n_matched   <- sum(!is.na(mmg_census_county$poverty_rate))
n_unmatched <- sum( is.na(mmg_census_county$poverty_rate))
message(sprintf("  Matched: %d | Unmatched (no Census data): %d",
                n_matched, n_unmatched))

# Flag rows where Census join failed
mmg_census_county <- mmg_census_county |>
  dplyr::mutate(census_join_flag = is.na(poverty_rate)) |>
  dplyr::rename(state_name = state)

# ── Step 2: Attach FRAC national context as state-level columns ───────────────
# FRAC provides national range stats — broadcast to every row as reference cols
message("\nStep 2: Attaching FRAC national food insecurity context...")

frac_national <- frac_range |>
  dplyr::filter(!is.na(national_fi_pct)) |>
  dplyr::slice(1) |>
  dplyr::select(
    frac_national_fi_pct  = national_fi_pct,
    frac_state_fi_min_pct = min_rate_pct,
    frac_state_fi_max_pct = max_rate_pct,
    frac_source_url       = source_url,
    frac_scraped_date     = scraped_date
  )

# Broadcast to all rows (same national reference for every county-year row)
final_merged <- mmg_census_county |>
  dplyr::mutate(
    frac_national_fi_pct  = frac_national$frac_national_fi_pct,
    frac_state_fi_min_pct = frac_national$frac_state_fi_min_pct,
    frac_state_fi_max_pct = frac_national$frac_state_fi_max_pct,
    frac_source_url       = frac_national$frac_source_url,
    frac_scraped_date     = frac_national$frac_scraped_date
  )

message("  FRAC national FI rate attached: ",
        frac_national$frac_national_fi_pct, "%")

# ── Step 3: Add Ohio flag for state-level comparison analysis ─────────────────
message("\nStep 3: Adding Ohio comparison flag...")

final_merged <- final_merged |>
  dplyr::mutate(
    is_ohio = dplyr::case_when(
      state_name == "OH" ~ TRUE,
      TRUE               ~ FALSE
    )
  )

message("  Ohio rows:     ", sum(final_merged$is_ohio))
message("  Non-Ohio rows: ", sum(!final_merged$is_ohio))

# ── Step 4: Final tidy column selection and ordering ──────────────────────────
final_tidy <- final_merged |>
  
  dplyr::select(
    # ── Identifiers ──────────────────────────────────────────────────────────
    fips,
    county_name,
    state_name,
    year,
    is_ohio,
    
    # ── MMG food insecurity variables (primary) ───────────────────────────────
    fi_rate,
    fi_count,
    child_fi_rate,
    meal_cost,
    
    # ── Census socioeconomic variables ────────────────────────────────────────
    poverty_rate,
    unemployment_rate,
    median_income,
    total_population,
    
    # ── FRAC national context (from scrape) ──────────────────────────────────
    frac_national_fi_pct,
    frac_state_fi_min_pct,
    frac_state_fi_max_pct,
    frac_source_url,
    frac_scraped_date,
    
    # ── Data quality flags ────────────────────────────────────────────────────
    missing_fi_rate,
    missing_fi_count,
    missing_meal_cost,
    census_join_flag,
    income_invalid,
    poverty_rate_invalid,
    unemployment_rate_invalid
  ) |>
  
  dplyr::arrange(state_name, county_name, year)

message("\nFinal merged dataset: ", nrow(final_tidy), " rows x ",
        ncol(final_tidy), " columns")
message("Years covered: ",
        paste(sort(unique(final_tidy$year)), collapse = ", "))
message("States covered: ", length(unique(final_tidy$state_name)))
message("Ohio county-years: ", sum(final_tidy$is_ohio))

# ── Step 5: Save all formats ──────────────────────────────────────────────────
dir.create(here("data", "final"), showWarnings = FALSE, recursive = TRUE)

# CSV — primary shareable format
write.csv(final_tidy,
          here("data", "final", "food_insecurity_final.csv"),
          row.names = FALSE, na = "")

# Excel — for Tableau / Power BI import
writexl::write_xlsx(final_tidy,
                    here("data", "final", "food_insecurity_final.xlsx"))

# RDS — for downstream R scripts (validation, EDA)
saveRDS(final_tidy,
        here("data", "final", "food_insecurity_final.rds"))

message("\n✓ 03 complete: Final merged dataset saved to data/final/")
message("  CSV:   food_insecurity_final.csv")
message("  Excel: food_insecurity_final.xlsx")
message("  RDS:   food_insecurity_final.rds")

write_csv(census_county_clean, here("data", "final", "FinalProject.csv"))
