# WHO Seasonal Risk Assessment Tool for Acute Emergencies

A Shiny application that visualizes results from the WHO Seasonal Risk Assessment Excel workbook. Analysts complete the workbook offline by selecting indicators, assigning them to risk pillars, and entering scores for each geographic unit. The results can be be uploaded to this app and turned into interactive summary tables and choropleth maps, with the ability to explore how the composite risk ranking changes under different pillar/indicator weightings.

**The app does not calculate or modify risk scores itself.** All indicators, weights, and scores are defined in the Excel workbook. This app reads that workbook, re-derives the same composite score under the current (or adjusted) weights, and renders it.

## How it works

1. **Exposure**, **Vulnerability**, and **Coping Capacity** are the three risk "pillars." Each pillar is made up of one or more indicators (e.g. temperature severity, share of elderly population), scored per subnational region in the workbook.
2. Indicator scores within a pillar are combined using **indicator weights**; the three pillar scores are combined using **pillar weights** to produce a **Composite Risk Score** per region.
3. The Shiny app lets a user upload a completed workbook, review the resulting scores in tables and maps, and interactively adjust weights (without editing Excel) to test alternative assumptions. This all takes place in-session, without overwriting the uploaded file. Updated weights can be exported as a copy of the workbook.

## Repository structure

```
app.R                 Shiny app: UI, authentication, server logic
R/
  read_data.R          Parses indicator scores & groupings from the uploaded workbook
  read_shape.R         Loads a shapefile and checks it matches the score data (legacy/local shapefile path)
  get_risks.R          Computes weighted pillar and composite risk scores
  make_indicator_table.R  Builds the per-pillar indicator breakdown table
  validate_pillar_weights.R     Checks pillar weights sum to 100%
  validate_indicator_weights.R  Checks indicator weights sum to 100% within each pillar
  vis_risk_table.R     Formats a risk table for display (DT)
  vis_scores.R         Renders a choropleth map of a risk score using WHO map styling
data/
  WHO Seasonal Risk Assessment Tool (TEMPLATE).xlsx   Blank workbook template for analysts to fill in
www/
  who-logo.png         Logo used in the app header
deploy_app.R           Publishes the app to shinyapps.io via rsconnect
```

## Requirements

- R (recent 4.x release recommended)
- The following R packages:
  `shiny`, `shinymanager`, `bslib`, `dplyr`, `purrr`, `magrittr`, `scales`, `ggplot2`, `DT`, `sf`, `readxl`, `openxlsx`, `zip`, `countrycode`, `cellranger`, `glue`, `rlang`, `tibble`
- [`whomapper`](https://github.com/whocov/whomapper): a WHO package used to pull subnational (admin-1) shapefiles and apply WHO map styling. Install via `remotes::install_github("whocov/whomapper")`.
- (Optional) `openxlsx2`: used instead of `openxlsx` when re-writing the downloaded workbook, if installed, for better fidelity with complex Excel formatting.

Install the CRAN packages with:

```r
install.packages(c(
  "shiny", "shinymanager", "bslib", "dplyr", "purrr", "magrittr",
  "scales", "ggplot2", "DT", "sf", "readxl", "openxlsx", "zip",
  "countrycode", "cellranger", "glue", "rlang", "tibble"
))
```

Install `whomapper` package with:

```r
#install.packages("remotes") # if not already installed 
remotes::install_github("whocov/whomapper")
```

## Using the app

1. **Complete the Excel workbook** (offline, before uploading):
   - Select indicators and assign each to Exposure, Vulnerability, or Coping Capacity.
   - Define pillar weights and indicator weights.
   - Enter indicator scores for each geographic unit.
   - Confirm the country/territory is entered under *1. Describe Your Emergency* — it is used to automatically fetch the matching subnational (admin-1) map.
2. **Upload the completed workbook** using the *Upload workbook* button in the app header.
3. **Review weights** in the sidebar (*Select Pillar Weights* / *Select Indicator Weights* tabs). The app validates that weights sum to 100% before enabling the results tables and maps.
4. **View results** in the *Risk Scores* tabs (Composite, Exposure, Vulnerability, Coping Capacity) and on the maps below.
5. **Test alternative assumptions** by adjusting the weight sliders in the sidebar — tables and maps update immediately. To persist a change, use *Download workbook* to export a copy of the original file with the updated weights written back in, or edit the source Excel file directly and re-upload.
6. **Download maps** as PNGs (zipped) using the *Download maps* button below the map grid.

Results are relative and intended for comparison **within the same assessment** (i.e. across regions in the same uploaded workbook), not as absolute or cross-assessment scores.

## The Excel workbook

The workbook (`data/WHO Seasonal Risk Assessment Tool (TEMPLATE).xlsx`) drives all inputs to the app and contains:

| Sheet | Purpose |
|---|---|
| Instructions | How to fill out the workbook |
| 1. Describe Your Emergency | Country/territory and emergency context (country name is read from cell D6) |
| 2. Define Indicators | Indicator catalogue, with pillar assignment and an "Include" flag |
| 3. Enter Indicator Scores | Per-region scores for each included indicator |
| 4. Define Weights | Pillar weights (B8:C11) and indicator weights (columns F:I) |
| 5. Weighted Indicator Scores | Reference calculations within Excel |
| 6. Composite Risk Scores | Reference calculations within Excel |
| Geographic Reference | Supporting reference data |

The app reads sheets 1–4 directly; sheets 5–6 are informational/for cross-checking within Excel and are not required by the app, since risk scores are recomputed in R from sheets 3 and 4.

## Credits

The risk-scoring logic in this app (`R/get_risks.R`, `R/read_data.R`, `R/read_shape.R`, `R/vis_risk_table.R`, `R/vis_scores.R`) was originally written by **Finlay Campbell** ([@finlaycampbell](https://github.com/finlaycampbell)) (WHO).
