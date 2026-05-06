# =============================================================================
# 02b_clean_scraped.R
# PURPOSE: Clean and parse FRAC scraped food insecurity summary data
# INPUT:   data/raw/frac_summary_raw.rds
#          data/raw/frac_state_range_raw.rds
# OUTPUT:  data/raw/frac_clean.rds
# =============================================================================

library(dplyr)
library(stringr)
library(here)

# ── Load ──────────────────────────────────────────────────────────────────────
frac_summary <- readRDS(here("data", "raw", "frac_summary_raw.rds"))
frac_range   <- readRDS(here("data", "raw", "frac_state_range_raw.rds"))

# ── Helper: parse percent string to numeric ───────────────────────────────────
parse_pct <- function(x) {
  stringr::str_extract(x, "[0-9]+\\.?[0-9]*") |> as.numeric()
}

# ── Clean summary text extracts ───────────────────────────────────────────────
frac_summary_clean <- frac_summary |>

  # Remove rows with no useful text
  dplyr::filter(!is.na(text_extract), nchar(text_extract) > 20) |>

  # Standardize category labels
  dplyr::mutate(
    category = dplyr::case_when(
      category == "food_insecurity_range" ~ "food_insecurity",
      category == "poverty"               ~ "poverty",
      category == "snap"                  ~ "snap_assistance",
      TRUE                                ~ category
    )
  ) |>

  # Extract any percentage values embedded in text
  dplyr::mutate(
    extracted_pct = parse_pct(
      stringr::str_extract(text_extract, "[0-9]+\\.?[0-9]*\\s*(%|percent)")
    )
  ) |>

  # Flag implausible percentages (must be 0–100)
  dplyr::mutate(
    pct_invalid = !is.na(extracted_pct) & (extracted_pct < 0 | extracted_pct > 100)
  ) |>

  # Remove exact duplicate text rows
  dplyr::distinct(text_extract, .keep_all = TRUE) |>

  dplyr::select(
    category,
    text_extract,
    extracted_pct,
    pct_invalid,
    source_url,
    scraped_date
  )

# ── Clean state range data ────────────────────────────────────────────────────
frac_range_clean <- frac_range |>

  dplyr::mutate(
    # Validate range values
    range_valid = !is.na(min_rate_pct) & !is.na(max_rate_pct) &
      min_rate_pct >= 0 & max_rate_pct <= 100 &
      min_rate_pct < max_rate_pct,

    national_fi_valid = !is.na(national_fi_pct) &
      national_fi_pct >= 0 & national_fi_pct <= 100
  )

# ── Diagnostics ───────────────────────────────────────────────────────────────
message("FRAC summary records cleaned: ", nrow(frac_summary_clean))
message("  Food insecurity rows: ",
        sum(frac_summary_clean$category == "food_insecurity"))
message("  Poverty rows:         ",
        sum(frac_summary_clean$category == "poverty"))
message("  SNAP rows:            ",
        sum(frac_summary_clean$category == "snap_assistance"))
message("  Invalid pct values:   ",
        sum(frac_summary_clean$pct_invalid, na.rm = TRUE))

message("\nFRAC state range:")
print(frac_range_clean |>
        dplyr::select(min_rate_pct, max_rate_pct, national_fi_pct, range_valid))

# ── Save ──────────────────────────────────────────────────────────────────────
saveRDS(frac_summary_clean, here("data", "raw", "frac_summary_clean.rds"))
saveRDS(frac_range_clean,   here("data", "raw", "frac_range_clean.rds"))

message("\n✓ 02b complete: FRAC data cleaned and saved.")

