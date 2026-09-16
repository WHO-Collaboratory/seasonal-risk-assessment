# WHO Seasonal Risk Assessment Tool for Acute Emergencies

This tool provides a quantitative framework for assessing public health risk related to extreme temperature conditions in acute emergency settings. It supports operational preparedness and response planning across different climates and seasonal contexts, applying a composite indicator methodology structured around three pillars — Exposure, Vulnerability, and Coping Capacity — to produce relative risk scores across subnational areas within a single assessment. It is intended primarily for national ministries of health and public health authorities responsible for seasonal preparedness and response planning, supported by WHO country offices and technical partners.

A Shiny application that visualizes results from the WHO Seasonal Risk Assessment Excel workbook. Analysts complete the workbook offline by selecting indicators, assigning them to risk pillars, and entering scores for each geographic unit. The results can be be uploaded to this app and turned into interactive summary tables and choropleth maps, with the ability to explore how the composite risk ranking changes under different pillar/indicator weightings.

**The app does not calculate or modify risk scores itself.** All indicators, weights, and scores are defined in the Excel workbook. This app reads that workbook, re-derives the same composite score under the current (or adjusted) weights, and renders it.

*Throughout this document, any use of the word "country" should be considered shorthand for a country, area, or territory.*

## How it works

1. **Exposure**, **Vulnerability**, and **Coping Capacity** are the three risk "pillars." Each pillar is made up of one or more indicators (e.g. temperature severity, share of elderly population), scored per subnational region in the workbook.
2. Indicator scores within a pillar are combined using **indicator weights**; the three pillar scores are combined using **pillar weights** to produce a **Composite Risk Score** per region.
3. The Shiny app lets a user upload a completed workbook, review the resulting scores in tables and maps, and interactively adjust weights (without editing Excel) to test alternative assumptions. This all takes place in-session, without overwriting the uploaded file. Updated weights can be exported as a copy of the workbook.

Indicator scores are normalized, weighted within each pillar, and combined into pillar scores, which are then weighted into a composite score for each subnational area. The three-pillar structure is fixed, while indicators, normalization approaches, and weights are defined by the user. This allows the tool to be adapted to various hazards and geographies without requiring changes to the underlying methodology. Guidance for adaptation is provided in the workbook.

### Scoring methodology

The composite score is a two-level weighted sum:

```
Pillar Score            = Σ (Indicator Weight × Indicator Score)     — within each pillar
Composite Risk Score    = Σ (Pillar Weight × Pillar Score)           — across the three pillars
```

Indicator weights must sum to 100% within each pillar; pillar weights must sum to 100% overall (the app and workbook both validate this). A given indicator's total contribution to the Composite Risk Score — its **Overall Weight** — is `Pillar Weight × Indicator Weight`; this is what the workbook's "4. Define Weights" sheet reports in column I, and what the app's *Weight breakdown* sidebar tab shows live for the currently active weights.

**Weights are matched by pillar/indicator name, not by row or column position.** Neither the Excel workbook nor the app assume pillars or indicators appear in any particular order — a pillar weight always applies to the pillar it's labeled with, regardless of which row it occupies in "4. Define Weights" or which order sliders are drawn in the app.

![The Shiny app's Composite Risk Scores tab, showing a results table and Exposure/Vulnerability/Coping Capacity/Composite maps for Ukraine](www/WHO%20Seasonal%20Risk%20Assessment%20Tool%20Shiny%20App.png)

## Repository structure

```
app.R                 Shiny app: UI and server logic
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
  WHO Seasonal Risk Assessment Tool (EXAMPLE).xlsx     Filled-in example workbook (git-ignored, kept locally for reference)
www/
  who-logo.png         Logo used in the app header
  WHO Seasonal Risk Assessment Shiny App.png              Screenshot of the app, used in this README
  WHO Seasonal Risk Assessment Tool Workbook (EXAMPLE).png Screenshot of the example workbook, used in this README
deploy_app.R           Publishes the app to shinyapps.io via rsconnect
```

## Requirements

- R (recent 4.x release recommended)
- The following R packages:
  `shiny`, `bslib`, `dplyr`, `purrr`, `magrittr`, `scales`, `ggplot2`, `DT`, `sf`, `readxl`, `openxlsx`, `zip`, `countrycode`, `cellranger`, `glue`, `rlang`, `tibble`
- [`whomapper`](https://github.com/whocov/whomapper): a WHO package used to pull subnational (admin-1) shapefiles and apply WHO map styling. Install via `remotes::install_github("whocov/whomapper")`.
- (Optional) `openxlsx2`: used instead of `openxlsx` when re-writing the downloaded workbook, if installed, for better fidelity with complex Excel formatting.

Install the CRAN packages with:

```r
install.packages(c(
  "shiny", "bslib", "dplyr", "purrr", "magrittr",
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
| 4. Define Weights | Pillar weights (B8:C11) and indicator weights (columns F:I), including each indicator's Overall Weight (Pillar Weight × Indicator Weight) — see [Scoring methodology](#scoring-methodology) |
| 5. Weighted Indicator Scores | Reference calculations within Excel |
| 6. Composite Risk Scores | Reference calculations within Excel |
| 7. Indicator Correlations | Automatic pairwise correlation matrix flagging redundant indicators |
| Geographic Reference | Supporting reference data |

The app reads sheets 1–4 directly; sheets 5–7 are informational/for cross-checking within Excel and are not required by the app, since risk scores are recomputed in R from sheets 3 and 4.

![A filled-in example workbook, showing the "5. Weighted Indicator Scores" sheet for Ukraine](www/WHO%20Seasonal%20Risk%20Assessment%20Tool%20Workbook%20%28EXAMPLE%29.png)

### Example subpillars and indicators

The template's "2. Define Indicators" sheet ships blank — indicators, subpillars, and pillar assignments are entirely up to the analyst. For concrete ideas of what's meant by a "subpillar" or "indicator," here is the set used in the filled-in example workbook (a cold-weather emergency in Ukraine):

**Exposure**
- *Hazard*: Average number of days below 10°C from October to March, Severity Score

**Vulnerability**
- *Vulnerable Population*: Elderly population (60 and above); Infant population (under 5); Chronic illness (hypertension); Prevalence of respiratory illnesses
- *Socioeconomic*: Internally displaced people (IDP); Average household income
- *Proximity*: Proximity to frontline

**Coping Capacity**
- *Health Service Accessibility*: Unable to access health services; Unable to get necessary medicine; Health facility accessibility (walking scenario); Functioning of health facilities; Health facility power availability; Health facility heating availability; Health cluster partner support
- *Public Infrastructure*: Frequency and duration of power outage
- *Safety and Security*: Attacks on healthcare (SSA); Conflict classification

A subpillar is just a label grouping related indicators under a pillar (e.g. several health-access indicators grouped under *Health Service Accessibility* within Coping Capacity) — it does not affect scoring, which happens at the indicator level.

### Known data gaps

- **Philippines (PHL) is missing entirely from the Geographic Reference tab.** OCHA's P-code registry carries 17 admin1 units for the Philippines, but the workbook has zero rows for it - it's the only WHO member state absent from the sheet. Needs follow-up to add the missing rows.

## Credits

The risk-scoring logic in this app (`R/get_risks.R`, `R/read_data.R`, `R/read_shape.R`, `R/vis_risk_table.R`, `R/vis_scores.R`) was originally written by **Finlay Campbell** ([@finlaycampbell](https://github.com/finlaycampbell)) (WHO).
