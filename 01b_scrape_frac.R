# =============================================================================
# 01b_scrape_frac.R
# PURPOSE: Scrape state-level food insecurity and poverty data from FRAC
#          (Food Research & Action Center) - https://frac.org/hunger-poverty-america
#
# WHY FRAC INSTEAD OF FEEDINGAMERICA.ORG:
#   The feedingamerica.org/hunger-in-america/[state] pages are JavaScript-
#   rendered — rvest reads the raw HTML before JS executes, so all stat values
#   come back blank. FRAC's hunger-poverty-america page is static HTML and
#   contains real, scrapeable state-level food insecurity text and statistics.
#
# WHAT THIS SCRAPES:
#   - State food insecurity rates (from paragraph text on the FRAC page)
#   - Supporting poverty and SNAP context statistics
#   - Source URL for citation
# =============================================================================

library(rvest)
library(stringr)
library(dplyr)
library(here)

# ── Target URL ────────────────────────────────────────────────────────────────
frac_url <- "https://frac.org/hunger-poverty-america"

message("Reading FRAC hunger & poverty page...")
page <- rvest::read_html(frac_url)

# ── Step 1: Extract all paragraph text ───────────────────────────────────────
# FRAC's page has statistics embedded in <p> tags as static text
all_paragraphs <- page |>
  rvest::html_elements("p") |>
  rvest::html_text2() |>
  stringr::str_trim() |>
  (\(x) x[nchar(x) > 30])()   # drop very short/nav strings

message("Total paragraphs found: ", length(all_paragraphs))

# ── Step 2: Extract heading/stat text ────────────────────────────────────────
# FRAC uses h2, h3, and strong elements for key statistics
headings <- page |>
  rvest::html_elements("h2, h3, h4, strong, .stat, .statistic") |>
  rvest::html_text2() |>
  stringr::str_trim() |>
  (\(x) x[nchar(x) > 5])()

message("Total heading/stat elements found: ", length(headings))

# ── Step 3: Extract food insecurity rate mentions ─────────────────────────────
# Look for sentences containing state names + a percentage near food insecurity

# All text on the page combined
all_text <- page |>
  rvest::html_elements("p, h2, h3, h4, li") |>
  rvest::html_text2() |>
  stringr::str_trim()

# Filter to lines that mention a percentage
pct_lines <- all_text[stringr::str_detect(all_text, "[0-9]+\\.?[0-9]*\\s*%|[0-9]+\\s+percent")]
message("Lines containing percentages: ", length(pct_lines))

# ── Step 4: Build structured data frame ──────────────────────────────────────
# Pull the key national/state summary statistics from text

# Extract lines mentioning state-level food insecurity variation
state_range_lines <- pct_lines[
  stringr::str_detect(pct_lines, "(?i)state|Arkansas|North Dakota|ranged|ranging|percent")
]

# Extract lines with poverty statistics
poverty_lines <- pct_lines[
  stringr::str_detect(pct_lines, "(?i)poverty|poor|low.income")
]

# Extract SNAP-related lines
snap_lines <- pct_lines[
  stringr::str_detect(pct_lines, "(?i)SNAP|food stamp|nutrition assist")
]

# ── Step 5: Assemble summary data frame ──────────────────────────────────────
frac_summary <- data.frame(
  category     = c(
    rep("food_insecurity_range", length(state_range_lines)),
    rep("poverty",               length(poverty_lines)),
    rep("snap",                  length(snap_lines))
  ),
  text_extract = c(state_range_lines, poverty_lines, snap_lines),
  source_url   = frac_url,
  scraped_date = Sys.Date(),
  stringsAsFactors = FALSE
) |>
  dplyr::distinct(text_extract, .keep_all = TRUE)   # remove duplicates

message("\nFRAC summary records: ", nrow(frac_summary))

# ── Step 6: Parse national food insecurity rate from text ────────────────────
# FRAC typically states the national rate in a visible paragraph
national_fi_text <- all_text[
  stringr::str_detect(all_text, "(?i)(food insecure|food insecurity).{0,60}[0-9]+\\.?[0-9]*\\s*%")
][1]

national_fi_rate <- stringr::str_extract(
  national_fi_text,
  "[0-9]+\\.?[0-9]*(?=\\s*%|\\s*percent)"
) |> as.numeric()

message("Extracted national food insecurity rate: ", national_fi_rate, "%")

# ── Step 7: Build tidy state-range row (for merging) ─────────────────────────
# FRAC text example: "ranging from 9 percent in North Dakota to 19.4 percent in Arkansas"
# Extract min state, max state, min rate, max rate

range_sentence <- state_range_lines[
  stringr::str_detect(state_range_lines, "(?i)rang")
][1]

if (!is.na(range_sentence)) {
  rates_in_sentence <- stringr::str_extract_all(
    range_sentence,
    "[0-9]+\\.?[0-9]*(?=\\s*(percent|%))"
  )[[1]] |> as.numeric()

  frac_state_range <- data.frame(
    metric          = "state_fi_rate_range",
    min_rate_pct    = min(rates_in_sentence, na.rm = TRUE),
    max_rate_pct    = max(rates_in_sentence, na.rm = TRUE),
    national_fi_pct = national_fi_rate,
    source_text     = range_sentence,
    source_url      = frac_url,
    scraped_date    = Sys.Date(),
    stringsAsFactors = FALSE
  )

  message("State FI range: ", frac_state_range$min_rate_pct,
          "% – ", frac_state_range$max_rate_pct, "%")
} else {
  frac_state_range <- data.frame(
    metric = "state_fi_rate_range", min_rate_pct = NA, max_rate_pct = NA,
    national_fi_pct = national_fi_rate, source_text = NA,
    source_url = frac_url, scraped_date = Sys.Date(),
    stringsAsFactors = FALSE
  )
  message("Could not parse state range sentence — stored as NA.")
}

# ── Step 8: Preview and save ──────────────────────────────────────────────────
message("\n--- FRAC Summary (first 10 rows) ---")
print(head(frac_summary, 10))

message("\n--- FRAC State Range ---")
print(frac_state_range)

# Save both objects
saveRDS(frac_summary,      here("data", "raw", "frac_summary_raw.rds"))
saveRDS(frac_state_range,  here("data", "raw", "frac_state_range_raw.rds"))

message("\n✓ 01b complete: FRAC data saved to data/raw/")
message("  Note: This script targets frac.org (static HTML).")
message("  feedingamerica.org state pages are JS-rendered and not scrapeable with rvest.")
