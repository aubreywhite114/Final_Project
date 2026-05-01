# Food Insecurity Data Pipeline

## Project Overview

This project analyzes food insecurity trends across U.S. counties and states, with a focused comparison of Ohio against the national average. It combines three real-world data sources to build a single tidy, validated dataset ready for Tableau or Power BI visualization.

**Research Question:** How does food insecurity in Ohio compare to the rest of the United States, and do county-level patterns within Ohio mirror or diverge from broader U.S. trends?

---

## Data Sources

| # | Source | Acquisition Method | Coverage | Key Variables |
|---|--------|--------------------|----------|---------------|
| 1 | `MMG2025_2019-2023_Data_To_Share.xlsx` | Excel file load | County & State, 2019–2023 | Food insecurity rate, # food insecure, child FI rate, meal cost |
| 2 | `frac.org/hunger-poverty-america` | Web scraping (`rvest`) | National summary | National FI rate, state FI range, poverty/SNAP context |
| 3 | U.S. Census Bureau ACS 5-Year | API (`tidycensus`) | County & State, 2023 | Poverty rate, median income, unemployment rate, population |

> **Note on scraping target:** `feedingamerica.org/hunger-in-america/[state]` pages are JavaScript-rendered — `rvest` reads raw HTML before JS executes, so all stat values return blank. FRAC's `hunger-poverty-america` page is static HTML and fully scrapeable with `rvest`.

---

## Repository Structure

```
food_insecurity_pipeline/
│
├── README.md                          # This file
├── .gitignore                          # Excludes credentials, data files, R artifacts
│
├── 01_data_acquisition/
│   ├── 01a_load_mmg_excel.R            # Loads MMG2025 Excel (county + state sheets)
│   ├── 01b_scrape_frac.R               # Scrapes FRAC hunger-poverty-america page
│   └── 01c_census_api.R                # Pulls ACS data via tidycensus API
│
├── 02_cleaning/
│   ├── 02a_clean_mmg.R                 # Cleans MMG: FIPS padding, type coercion, flags
│   ├── 02b_clean_scraped.R             # Cleans FRAC scraped data, parses percentages
│   └── 02c_clean_census.R              # Cleans Census: derived poverty/unemployment rates
│
├── 03_merge/
│   └── 03_merge_final.R                # Merges all three sources on FIPS + state name
│
├── 04_validation/
│   └── 04_validate.R                   # 15 data quality checks; outputs validation_table.csv
│
├── 05_eda/
│   └── 05_eda_summaries.R              # Summary stats, Ohio vs. U.S. tables, 4 ggplot visuals
│
└── data/
    ├── raw/                            # Raw and intermediate .rds files (not committed)
    └── final/                          # Final merged dataset + validation table + EDA outputs
```

---

## How to Reproduce the Pipeline

### Prerequisites

Install required R packages:

```r
install.packages(c(
  "tidyverse", "readxl", "rvest", "stringr",
  "tidycensus", "janitor", "here", "skimr",
  "ggplot2", "scales", "writexl"
))
```

### Set Up the Census API Key Securely

**Never hard-code your API key in any script.**

1. Get a free key at: https://api.census.gov/data/key_signup.html
2. Open your `.Renviron` file:

```r
usethis::edit_r_environ()
```

3. Add this line and save:

```
CENSUS_API_KEY=your_actual_key_here
```

4. Restart R. Your key is now available via `Sys.getenv("CENSUS_API_KEY")`.

> ⚠️ `.Renviron` is listed in `.gitignore` and will **never** be committed to GitHub.

### Place the MMG Excel File

Download `MMG2025_2019-2023_Data_To_Share.xlsx` from Feeding America and place it at:

```
data/raw/MMG2025_2019-2023_Data_To_Share.xlsx
```

### Run the Pipeline (in order)

```r
source("01_data_acquisition/01a_load_mmg_excel.R")
source("01_data_acquisition/01b_scrape_frac.R")
source("01_data_acquisition/01c_census_api.R")
source("02_cleaning/02a_clean_mmg.R")
source("02_cleaning/02b_clean_scraped.R")
source("02_cleaning/02c_clean_census.R")
source("03_merge/03_merge_final.R")
source("04_validation/04_validate.R")
source("05_eda/05_eda_summaries.R")
```

---

## Final Dataset Structure

**File:** `data/final/food_insecurity_final.csv`

| Column | Source | Description |
|--------|--------|-------------|
| `fips` | MMG | 5-digit county FIPS code |
| `county_name` | MMG | County name |
| `state_name` | MMG | State name |
| `year` | MMG | Data year (2019–2023) |
| `is_ohio` | Derived | TRUE if Ohio county |
| `fi_rate` | MMG | Overall food insecurity rate |
| `fi_count` | MMG | Number of food insecure persons |
| `child_fi_rate` | MMG | Child food insecurity rate |
| `meal_cost` | MMG | Average meal cost ($) |
| `poverty_rate` | Census ACS | Poverty rate (derived) |
| `unemployment_rate` | Census ACS | Unemployment rate (derived) |
| `median_income` | Census ACS | Median household income |
| `total_population` | Census ACS | Total county population |
| `frac_national_fi_pct` | FRAC scrape | National FI rate reference |
| `frac_state_fi_min_pct` | FRAC scrape | Lowest state FI rate |
| `frac_state_fi_max_pct` | FRAC scrape | Highest state FI rate |
| `*_flag / *_invalid` | Derived | Data quality flags |

---

## Data Quality Notes

- **Missing values:** Flagged with `missing_*` boolean columns; documented in `validation_table.csv`
- **FIPS standardization:** All FIPS codes zero-padded to 5 digits for consistent joining
- **Duplicate handling:** Deduplicated on `fips + year` (MMG) and `state_name` (FRAC) — first valid row kept
- **Census join coverage:** County Census data joined for 2023 ACS and applied as context across all MMG years
- **Impossible values:** Rates outside 0–100%, negative counts, and zero/negative incomes are flagged in the validation table

---

## Security

- API keys are stored in `.Renviron` (excluded via `.gitignore`)
- No credentials, tokens, or secrets appear anywhere in any script
- Raw Excel and CSV data files are excluded from the repository via `.gitignore`
- The `.gitignore` also excludes `.RData`, `.Rhistory`, and `.Rproj.user/`
