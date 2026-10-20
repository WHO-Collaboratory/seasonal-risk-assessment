# Seasonal Risk Assessment Tool for Acute Emergencies

**Get started:** [Download the Excel workbook](https://raw.githubusercontent.com/WHO-Collaboratory/seasonal-risk-assessment/main/workbook/Seasonal%20Risk%20Assessment%20Tool.xlsx) · [Download a worked example](https://raw.githubusercontent.com/WHO-Collaboratory/seasonal-risk-assessment/main/workbook/Seasonal%20Risk%20Assessment%20Tool%20%28EXAMPLE%29.xlsx) · [Go to the Shiny app](https://worldhealthorg.shinyapps.io/seasonal-risk-assessment/)

> **Note:** All Ukraine data in this repository (the worked example workbook, the screenshots below and the test workbooks derived from it) is **synthetic and used only as an illustrative example**. It does not represent real conditions, and the scores should not be used for any real-world assessment or decision.

This tool provides a quantitative framework for assessing public health risk related to extreme temperature conditions in acute emergency settings. It supports operational preparedness and response planning across different climates and seasonal contexts, applying a composite indicator methodology structured around three pillars of Exposure, Vulnerability, and Coping Capacity to produce relative risk scores across subnational areas within a single assessment. It is intended primarily for national ministries of health and public health authorities responsible for seasonal preparedness and response planning, supported by WHO country offices and technical partners.

A Shiny application that visualizes results from the WHO Seasonal Risk Assessment Excel workbook. Analysts complete the workbook offline by selecting indicators, assigning them to risk pillars, and entering scores for each geographic unit. The results can be uploaded to this app and turned into interactive summary tables and choropleth maps, with the ability to explore how the composite risk ranking changes under different pillar/indicator weightings.

**The app does not calculate or modify risk scores itself.** All indicators, weights, and scores are defined in the Excel workbook. This app reads that workbook, re-derives the same composite score under the current (or adjusted) weights, and renders it.

*Throughout this app and its documentation, any use of the word "country" should be considered shorthand for a country, area, or territory.*

## How it works

1. **Exposure**, **Vulnerability**, and **Coping Capacity** are the three risk "pillars." Each pillar is made up of one or more indicators (e.g. temperature severity, share of elderly population), scored per subnational region in the workbook.
2. Indicator scores within a pillar are combined using **indicator weights**; the three pillar scores are combined using **pillar weights** to produce a **Composite Risk Score** per region.
3. The Shiny app lets a user upload a completed workbook, review the resulting scores in tables and maps, and interactively adjust weights (without editing Excel) to test alternative assumptions. This all takes place in-session, without overwriting the uploaded file. Updated weights can be exported as a copy of the workbook.

Analysts normalize each indicator onto a common score scale in the workbook (1-5 is recommended, with higher meaning higher risk). The scores are then weighted within each pillar and combined into pillar scores, which are weighted into a composite score for each subnational area. The three-pillar structure is fixed, while indicators, normalization approaches, and weights are defined by the user. This allows the tool to be adapted to various hazards and geographies without requiring changes to the underlying methodology. Guidance for adaptation is provided in the workbook.

### Scoring methodology

The composite score is a two-level weighted sum:

```
Pillar Score            = Σ (Indicator Weight × Indicator Score)     — within each pillar
Composite Risk Score    = Σ (Pillar Weight × Pillar Score)           — across the three pillars
```

A given indicator's total contribution to the Composite Risk Score (its **Overall Weight**) is `Pillar Weight × Indicator Weight`. This is what the workbook's "4. Define Weights" sheet reports in column I, and what the app's *Weight breakdown* sidebar tab shows live for the currently active weights.

**Missing scores:** if an indicator has no score for a place, it is skipped for that place and the other indicators' weights in the pillar are rescaled to sum to 100%, so a blank is never counted as 0. The workbook and the app calculate this the same way. If every indicator in a pillar is blank for a place, that place has no pillar score and no composite score (shown as "-" in the workbook).

Only indicators marked **Include = TRUE** in "2. Define Indicators" are scored. Excluded indicators stay in the workbook, with any scores and weights already entered, so they can be included again later.

**Weight rules.** The workbook and the app apply the same rules:

- Pillar weights must sum to 100%, and indicator weights must sum to 100% within each pillar. Both checks allow ±0.15 percentage points, so thirds entered as 33.3% pass.
- Every pillar and every included indicator needs a weight. A blank weight is an error; enter 0% if something should not count.
- Every pillar needs at least one included indicator.
- Weights must be between 0% and 100%.
- If weights differ within a pillar, give a rationale in "2. Define Indicators". The workbook shows a note if one is missing, but this does not block the results.

Because pillar and composite scores are weighted averages of indicator scores, they always fall within the range of the indicator scores entered.

![The Shiny app's Composite Risk Scores tab, showing a results table and Exposure/Vulnerability/Coping Capacity/Composite maps for Ukraine](www/Seasonal%20Risk%20Assessment%20Tool%20Shiny%20App.png)

*Illustrative screenshot using synthetic example data for Ukraine; not real data.*

## Repository structure

```
.
├── app.R                                                          Shiny app: UI and server logic
├── R
│   ├── read_data.R                                                Reads indicator scores and definitions from the uploaded workbook, and checks them
│   ├── read_shape.R                                               Loads a shapefile and checks it matches the score data (legacy/local shapefile path)
│   ├── get_risks.R                                                Computes weighted pillar and composite risk scores
│   ├── make_indicator_table.R                                     Builds the per-pillar indicator breakdown table
│   ├── validate_pillar_weights.R                                  Reads pillar weights; checks they sum to 100%
│   ├── validate_indicator_weights.R                               Reads indicator weights; checks they are complete and sum to 100% within each pillar
│   ├── risk_palette.R                                             Shared colour scale for the maps and tables
│   ├── terms_of_use.R                                             Terms of Use text shown in the app
│   ├── vis_risk_table.R                                           Formats a risk table for display (DT)
│   └── vis_scores.R                                               Renders a choropleth map of a risk score using WHO map styling
├── workbook                                                       Excel workbook files, licensed separately (see License)
│   ├── LICENSE.md                                                 CC BY-NC-SA 3.0 IGO licence for this folder
│   ├── Seasonal Risk Assessment Tool.xlsx                         Blank workbook template for analysts to fill in
│   └── Seasonal Risk Assessment Tool (EXAMPLE).xlsx               Filled-in example workbook, kept for reference
├── tests
│   ├── test_upload_checks.R                                       Upload tests run against the test workbooks in tests/test-workbooks/
│   └── test-workbooks/                                            Test workbooks, each with one problem or structural change, saved in Excel (CC BY-NC-SA 3.0 IGO, see LICENSE.md there)
├── www
│   ├── who-logo.png                                               Logo used in the app header (optional, gitignored)
│   ├── Seasonal Risk Assessment Tool Shiny App.png                    Screenshot of the app, used in this README
│   └── Seasonal Risk Assessment Tool Workbook (EXAMPLE).png   Screenshot of the example workbook, used in this README
├── deploy_app.R                                                   Publishes the app to shinyapps.io via rsconnect
├── LICENSE                                                        Apache License 2.0 (source code)
└── NOTICE                                                         Copyright notice and WHO name and emblem exclusion
```

## Requirements

- R (recent 4.x release recommended)
- The following R packages:
  `shiny`, `bslib`, `dplyr`, `purrr`, `magrittr`, `scales`, `ggplot2`, `DT`, `sf`, `readxl`, `openxlsx`, `zip`, `countrycode`, `cellranger`, `glue`, `rlang`, `tibble`
- [`whomapper`](https://github.com/whocov/whomapper): a WHO package used to pull subnational (admin-1) shapefiles and apply WHO map styling. Install via `remotes::install_github("whocov/whomapper")`.
- (Optional) `openxlsx2`: used instead of `openxlsx` when re-writing the downloaded workbook, if installed, for better fidelity with complex Excel formatting.
- (Optional) `testthat`: needed only to run the tests.

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
   - Enter indicator scores for each geographic unit. To copy scores from another file, use *Paste Special > Values*: a normal paste also brings that file's formatting and removes the sheet's colour coding and checks.
   - Confirm the country/territory is entered under *1. Describe Your Emergency* — it is used to automatically fetch the matching subnational (admin-1) map.
   - Check that no warnings (⚠) remain in Steps 2-4.
2. **Upload the completed workbook** using the *Upload workbook* button in the app header. The app checks the workbook first. If anything would make the results unreliable, it lists every problem in one message and does not show results until they are fixed. Problems it checks for include duplicate indicator names, included indicators with no scores or no weight, scores left behind by a deleted indicator, scores that are not non-negative numbers, and blank or invalid weights. If nothing has been filled in at all, the app says the workbook looks empty, since the blank template was probably uploaded by mistake.
3. **Review weights** in the sidebar (*Select Pillar Weights* / *Select Indicator Weights* tabs). The app validates that weights sum to 100% before enabling the results tables and maps.
4. **View results** in the *Risk Scores* tabs (Composite, Exposure, Vulnerability, Coping Capacity) and on the maps below. All maps and tables share one colour scale, running from the lowest to the highest score entered for any included indicator. A given score is therefore the same colour in every view. Pillar and composite maps usually look paler than the scale's extremes, because averaging pulls scores toward the middle.
5. **Test alternative assumptions** by changing the weights (in %) in the sidebar — tables and maps update immediately. To persist a change, use *Download workbook* to export a copy of the original file with the updated weights written back in, or edit the source Excel file directly and re-upload.
6. **Download maps** as PNGs (zipped) using the *Download maps* button below the map grid.

Results are relative and intended for comparison **within the same assessment** (i.e. across regions in the same uploaded workbook), not as absolute or cross-assessment scores.

## The Excel workbook

The workbook (`workbook/Seasonal Risk Assessment Tool.xlsx`) drives all inputs to the app and contains:

| Sheet | Purpose |
|---|---|
| Instructions | How to fill out the workbook |
| 1. Describe Your Emergency | Country/territory and emergency context (country name is read from cell D6) |
| 2. Define Indicators | Indicator catalogue (up to 30 rows), with pillar assignment, an "Include" flag and an automatic Indicator ID |
| 3. Enter Indicator Scores | Per-region scores, with one column for each row of "2. Define Indicators" |
| 4. Define Weights | Pillar weights (Step 4A, B10:C12) and indicator weights (Step 4B, columns F:I, one row for each row of "2. Define Indicators"), including each indicator's Overall Weight (Pillar Weight × Indicator Weight). Step 4C checks the weights — see [Scoring methodology](#scoring-methodology) |
| 5. Weighted Indicator Scores | Reference calculations within Excel |
| 6. Composite Risk Scores | Reference calculations within Excel |
| 7. Indicator Correlations | Automatic pairwise correlation matrix flagging redundant indicators |
| Geographic Reference | Supporting reference data |

The app reads sheets 1-4 directly. Sheets 5-7 are for cross-checking within Excel and are not required by the app, since risk scores are recomputed in R from sheets 3 and 4. Sheets are protected so that only input cells can be edited.

![A filled-in example workbook, showing the "5. Weighted Indicator Scores" sheet for Ukraine](www/Seasonal%20Risk%20Assessment%20Tool%20Workbook%20%28EXAMPLE%29.png)

*Illustrative screenshot using synthetic example data for Ukraine; not real data.*

### How scores and weights stay with the right indicator

Each row of the "2. Define Indicators" table has a fixed, hidden row number. The matching score column in Step 3 and weight row in Step 4 carry the same number. Scores and weights therefore stay with their indicator when indicators are sorted, excluded, re-included or moved to another pillar. Indicator IDs combine the pillar and that number (e.g. `EXP-03`, `VUL-07`, `COP-12`).

The workbook warns about the changes it cannot handle on its own:

- **Inserting rows** into the Step 2 table: an inserted row has no score column. To add an indicator, type it into the next empty row at the bottom of the table instead.
- **Deleting or clearing an indicator row**: its leftover scores and weight are marked *⚠ Indicator deleted* in red. Undo the change, or delete those values. Once they are removed, the column shows as grey *Unused*.
- **Duplicate indicator names**, and rows with a pillar or Include value but no name.
- **Scores in rows with no subnational unit**, for example after the country in Step 1 is changed.

Excluded indicators are shown in grey. In "7. Indicator Correlations", *too few* means fewer than three subnational units have scores for both indicators. *no var* means one indicator has the same score everywhere, so no correlation can be calculated.

### Example indicators

The template's "2. Define Indicators" sheet ships blank — indicators and pillar assignments are entirely up to the analyst. For concrete ideas of what's meant by an "indicator," here is the set used in the filled-in example workbook (a cold-weather emergency in Ukraine; all figures are synthetic):

**Exposure**

- Mean winter minimum temperature severity
- Extreme cold days (below -10ºC) per winter season
- Households with damaged or disrupted heating infrastructure

**Vulnerability**

- Population aged 65 and older
- Internally displaced population
- Population below the national poverty line
- Chronic respiratory and cardiovascular disease prevalence

**Coping Capacity**

- Health facility density gap (facilities per 10,000 population)
- Hospital bed capacity gap (beds per 10,000 population)
- Roads not winterized or inaccessible in winter conditions
- Humanitarian organization presence gap (active organizations per oblast)

The example also includes four indicators marked Include = FALSE, to show how excluded indicators look: snow depth, population density, household fuel poverty rate, and number of emergency shelters / warming centers.

## Testing

`tests/test_upload_checks.R` runs the app's upload checks and scoring against the workbooks in `tests/test-workbooks/`. Most of those workbooks are the example data with one change made the way a user would make it, such as an excluded, sorted, deleted or inserted indicator, a duplicate name, a missing weight, or an empty pillar. Two are different: `blank_template.xlsx` is the unfilled template, and `old_layout_example.xlsx` is the example in the workbook layout used before 2026-10, to check that older workbooks still upload. Run the tests from the repository root:

```r
testthat::test_file("tests/test_upload_checks.R")
```

The app reads the values Excel stores when it saves a workbook. Test workbooks must therefore be opened, recalculated and saved in Microsoft Excel. A workbook written by a script, or saved in LibreOffice, will not read correctly.

## Credits

The risk-scoring logic in this app (`R/get_risks.R`, `R/read_data.R`, `R/read_shape.R`, `R/vis_risk_table.R`, `R/vis_scores.R`) was originally written by **Finlay Campbell** ([@finlaycampbell](https://github.com/finlaycampbell)) (WHO).

## Suggested citation

Citation is welcome but not required. If you cite this tool, please use:

> Seasonal Risk Assessment Tool for Acute Emergencies. Berlin: World Health Organization Hub for Pandemic and Epidemic Intelligence, 2026. Available online: https://worldhealthorg.shinyapps.io/seasonal-risk-assessment/ (last cited: [date]).

Citing the tool must not state or imply that WHO endorses you, your use of the tool, or any results produced with it (see [License](#license)).

## Terms of use

The app shows a summary of these terms at the start of every session, and you must select **I accept** to continue. The **Terms of Use** link in the header, sidebar, welcome page and upload dialog reopens them. Acceptance is not stored between sessions. If the summary in the app and this README differ, this README prevails.

### What the tool is and is not

The tool turns indicator scores and weights that you enter in the Excel workbook into risk scores, tables and maps. WHO does not supply, review or verify those scores, weights or indicator definitions, and every result depends entirely on what you entered. You are responsible for how you interpret and use the analyses and outputs you produce.

Results are relative: they compare areas within one assessment and are not absolute measures of risk, forecasts, or a basis for clinical or individual-level decisions. Use them as one input to preparedness and response planning, alongside local knowledge and other evidence. The example workbook and the screenshots in this README use synthetic data for Ukraine. They are illustrations only and do not describe real conditions.

### Your data

Only upload data you are allowed to share with this service. The workbook should hold aggregated scores for subnational areas. Do not enter personal data about individuals. Check whether your indicator data are confidential or politically sensitive before you upload them.

1. **Upload.** Your workbook is sent to the app server and saved in a temporary folder created for your session. The app reads it from there into the server's memory to calculate your tables and maps.
2. **During your session.** The app does not write your data to a database or other permanent storage. Weight changes stay in your session unless you download the updated workbook. When you download a workbook or maps, the app builds the file in a temporary folder and deletes that folder once the file has been sent.
3. **When the session ends.** A session ends when you close the tab or reload the page, or after a period without activity. The server then deletes your uploaded workbook and the session's temporary folders, and releases your session's data from memory. After a reload, you will need to upload the workbook again. Shiny deletes the uploaded file itself, and `app.R` also removes it, along with the app's own temporary folders, when the session ends.

Files are deleted in the usual way and are not securely erased. The app is hosted on shinyapps.io, run by Posit, on servers that may be outside your country. Posit may keep technical logs, such as IP addresses, under its own terms. The app's server log may also record error messages. If your upload has a problem, these can include indicator names from your workbook and the ISO3 code of your country or territory. They do not include your scores. The ISO3 code for the country or territory in "1. Describe Your Emergency" is sent to a WHO boundary service to fetch subnational boundaries. That service is hosted on Esri's ArcGIS Online platform, so Esri may see the request, including the server's IP address, under its own terms. Your scores, indicator names and workbook are not sent. Files you download are yours to store and protect.

The `whomapper` package makes the request. The app makes no other requests to third parties. To keep your workbook off a hosted service, run the app locally (see [Requirements](#requirements)). It still needs internet access to fetch boundaries.

### Other terms in brief

- **No WHO endorsement.** Results are not WHO's products, opinions or statements. Do not state or imply that WHO endorses you, your use of the tool or any result, and do not use the WHO name or emblem without WHO's written approval (see [License](#license)).
- **Maps.** Boundaries come from a WHO boundary service and may differ from those used by national authorities. The map disclaimer in [License](#license) applies to the maps in the app and to downloaded map images, which carry it in their caption. Keep it with the map when you share it.
- **Licences.** Code is Apache 2.0. The workbook, including the copy you download from the app, is CC BY-NC-SA 3.0 IGO, which is non-commercial and share-alike. An adaptation of the workbook must carry the adaptation statement given in [License](#license).
- **No warranty and no liability.** The tool is provided "as is", WHO is not liable for damages arising from its use or its outputs, the tool or these terms may change or be withdrawn at any time, and the hosted app may be unavailable at times (see [Disclaimer](#disclaimer)).
- **Privileges and immunities.** Nothing here waives WHO's privileges and immunities (see [License](#license)).

The Disclaimer and License sections below are also part of these terms.

## Disclaimer

The tool turns indicator scores and weights entered by the user into risk scores, maps and tables. Every result depends entirely on that information. WHO does not supply, review or verify the indicator scores, weights or definitions used, and results may differ from other analyses based on different data, methods or time periods. Interpret scores with care, alongside local knowledge and other sources of evidence.

Users are responsible for the interpretation and use of the analyses and outputs they produce. Use of the tool, or inclusion of any content in a workbook, does not mean that WHO has approved or endorsed that content or that it is suitable for any particular purpose.

The tool is provided "as is", without warranty of any kind. In no event shall WHO be liable for damages arising from the use of the tool or its outputs. WHO may update, change or withdraw the tool or these terms at any time without notice. See the [License](#license) section for the full terms.

## License

This repository contains three kinds of material. Each is covered by different terms.

### 1. Source code: Apache License 2.0

The source code (the R Shiny app, the R functions, the test script and the deployment script) is copyright © World Health Organization 2026 and is licensed under the [Apache License, Version 2.0](LICENSE). See also [NOTICE](NOTICE).

### 2. Excel workbook and embedded guidance: CC BY-NC-SA 3.0 IGO

The Excel workbook files in [`workbook/`](workbook/) and [`tests/test-workbooks/`](tests/test-workbooks/) (copies of the example workbook with one change each) and the guidance embedded in them are licensed under the [Creative Commons Attribution-NonCommercial-ShareAlike 3.0 IGO licence (CC BY-NC-SA 3.0 IGO)](https://creativecommons.org/licenses/by-nc-sa/3.0/igo/legalcode). The Apache License does not apply to them. See [`workbook/LICENSE.md`](workbook/LICENSE.md).

The licence is share-alike: if you adapt the workbook and share the adaptation, you must release it under the same or an equivalent licence and include this statement: "This adaptation was not created by WHO. WHO is not responsible for the content or accuracy of this adaptation. The original edition shall be the binding and authentic edition."

### 3. WHO name and emblem: not licensed

The name and emblem of the World Health Organization (WHO) are excluded from both licenses above. Any use of the WHO name or emblem requires prior written approval from WHO. Anyone adapting the tool must remove the WHO emblem and must not state or imply that WHO endorses the adaptation or its results. See WHO's [copyright](https://www.who.int/about/policies/publishing/copyright) and [logo](https://www.who.int/about/policies/publishing/logo) policies.

You also shall not state or imply that results produced with this tool are WHO's products, opinion or statements, or that WHO endorses or is affiliated with you, your use of the tool, or any entity, organization, company or product.

Filling out the workbook with your own data and running the app as provided does not require attribution or any other license action on your part.

### 4. Maps

The boundaries and names shown and the designations used on the maps in the app and in its downloadable map images (the "Maps") do not imply the expression of any opinion whatsoever on the part of WHO concerning the legal status of any country, territory, city or area or of its authorities, or concerning the delimitation of its frontiers or boundaries. Dotted and dashed lines on maps represent approximate border lines for which there may not yet be full agreement.

### 5. Third-party software

The app depends on third-party open source software, including the R packages listed under [Requirements](#requirements). That software is not part of this repository and is licensed by its authors under their own terms. WHO makes no warranties, and specifically disclaims all warranties, express or implied, that third-party software is free of defects, virus free, able to operate on an uninterrupted basis, merchantable, fit for a particular purpose, accurate, non-infringing or appropriate for your technical system. The use of third-party software does not imply that it is endorsed or recommended by WHO in preference to others of a similar nature.

### 6. Privileges and immunities of WHO

Nothing contained herein or in any license or terms of use related to the subject matter herein (including, without limitation, the Apache License, Version 2.0, and the CC BY-NC-SA 3.0 IGO licence) shall be construed as a waiver of any of the privileges and immunities enjoyed by the World Health Organization under national or international law, and/or as submitting the World Health Organization to any national jurisdiction.
