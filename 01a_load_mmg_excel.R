# =============================================================================
# 01a_load_mmg_excel.R
# PURPOSE: Load and preview the MMG2025 Excel data (2019-2023)
# SOURCE:  MMG2025_2019-2023_Data_To_Share.xlsx (provided dataset)
# =============================================================================

library(readxl)
library(dplyr)
library(here)

# ── File path ────────────────────────────────────────────────────────────────
# Place the Excel file in data/raw/ before running
mmg_path <- "M:\\ISA401\\data\\MMG2025_2019-2023_Data_To_Share.xlsx"

if (!file.exists(mmg_path)) {
  stop("MMG Excel file not found. Please place it at: ", mmg_path)
}

# ── Inspect sheet names ───────────────────────────────────────────────────────
sheet_names <- readxl::excel_sheets("M:\\ISA401\\data\\MMG2025_2019-2023_Data_To_Share.xlsx")
message("Sheets found in MMG file:")
print(sheet_names)

# ── Load county-level sheet ───────────────────────────────────────────────────
# Adjust sheet name/number if different in your actual file
mmg_county_raw <- readxl::read_excel(
  path      = mmg_path,
  sheet     = 1,           # Usually "County" or first sheet — update if needed
  col_names = TRUE,
  na        = c("", "NA", "N/A", "n/a", "#N/A")
)

message("\nMMG County-level raw data: ", nrow(mmg_county_raw), " rows x ",
        ncol(mmg_county_raw), " columns")

# ── Load state-level sheet (if present) ──────────────────────────────────────
if (length(sheet_names) >= 2) {
  mmg_state_raw <- readxl::read_excel(
    path      = mmg_path,
    sheet     = 2,         # Usually "State" — update if needed
    col_names = TRUE,
    na        = c("", "NA", "N/A", "n/a", "#N/A")
  )
  message("MMG State-level raw data: ", nrow(mmg_state_raw), " rows x ",
          ncol(mmg_state_raw), " columns")
} else {
  mmg_state_raw <- NULL
  message("No second sheet found — skipping state-level MMG load.")
}

# ── Quick preview ─────────────────────────────────────────────────────────────
message("\n--- MMG County Column Names ---")
print(names(mmg_county_raw))

message("\n--- First 5 rows ---")
print(head(mmg_county_raw, 5))

# ── Ensure output directory exists ───────────────────────────────────────────
dir.create(here("data", "raw"), recursive = TRUE, showWarnings = FALSE)

# ── Save raw objects for downstream scripts ───────────────────────────────────
saveRDS(mmg_county_raw, here("data", "raw", "mmg_county_raw.rds"))
if (!is.null(mmg_state_raw)) {
  saveRDS(mmg_state_raw, here("data", "raw", "mmg_state_raw.rds"))
}

message("\n✓ 01a complete: MMG raw data saved to data/raw/")
