# =============================================================================
# 01a_load_mmg_excel.R
# PURPOSE: Load and preview the MMG2025 Excel data (2019-2023)
# SOURCE:  MMG2025_2019-2023_Data_To_Share.xlsx (provided dataset)
# =============================================================================

library(readxl)
library(dplyr)
library(here)

# ── File path ─────────────────────────────────────────────────────────────────
mmg_path <- "M:\\ISA401\\data\\MMG2025_2019-2023_Data_To_Share.xlsx"

if (!file.exists(mmg_path)) {
  stop("MMG Excel file not found. Please place it at: ", mmg_path)
}

# ── Inspect sheet names ───────────────────────────────────────────────────────
sheet_names <- readxl::excel_sheets(mmg_path)
message("Sheets found in MMG file:")
print(sheet_names)

# ── Helper: auto-detect which row contains the real headers ──────────────────
# MMG files have a title/subtitle row before the actual column headers.
# This function scans the first 5 rows and finds which one contains "FIPS".
find_header_row <- function(path, sheet) {
  for (skip_n in 0:4) {
    test <- readxl::read_excel(path, sheet = sheet,
                               skip = skip_n, col_names = TRUE, n_max = 1)
    if (any(grepl("fips|FIPS", names(test)))) {
      message("  Header row found at skip = ", skip_n, " for sheet: ", sheet)
      return(skip_n)
    }
  }
  message("  WARNING: Could not auto-detect header row for sheet: ", sheet,
          ". Defaulting to skip = 1.")
  return(1)
}

# ── Load county-level sheet ───────────────────────────────────────────────────
message("\nDetecting header row for County sheet...")
county_skip <- find_header_row(mmg_path, "County")

mmg_county_raw <- readxl::read_excel(
  path      = mmg_path,
  sheet     = "County",
  skip      = county_skip,
  col_names = TRUE,
  na        = c("", "NA", "N/A", "n/a", "#N/A")
)

message("MMG County-level raw data: ", nrow(mmg_county_raw), " rows x ",
        ncol(mmg_county_raw), " columns")

# Verify FIPS column exists
if (!"FIPS" %in% names(mmg_county_raw)) {
  message("WARNING: 'FIPS' column not found. Actual column names:")
  print(names(mmg_county_raw))
  stop("Fix the skip value — FIPS column must be present before continuing.")
} else {
  message("✓ FIPS column confirmed present.")
}

# ── Load state-level sheet ────────────────────────────────────────────────────
message("\nDetecting header row for State sheet...")
state_skip <- find_header_row(mmg_path, "State")

mmg_state_raw <- readxl::read_excel(
  path      = mmg_path,
  sheet     = "State",
  skip      = state_skip,
  col_names = TRUE,
  na        = c("", "NA", "N/A", "n/a", "#N/A")
)

message("MMG State-level raw data: ", nrow(mmg_state_raw), " rows x ",
        ncol(mmg_state_raw), " columns")

# ── Quick preview ─────────────────────────────────────────────────────────────
message("\n--- MMG County Column Names ---")
print(names(mmg_county_raw))

message("\n--- First 3 rows ---")
print(head(mmg_county_raw, 3))

# ── Ensure output directory exists ───────────────────────────────────────────
dir.create(here("data", "raw"), recursive = TRUE, showWarnings = FALSE)

# ── Save raw objects for downstream scripts ───────────────────────────────────
saveRDS(mmg_county_raw, here("data", "raw", "mmg_county_raw.rds"))
saveRDS(mmg_state_raw,  here("data", "raw", "mmg_state_raw.rds"))

message("\n✓ 01a complete: MMG raw data saved to data/raw/")
