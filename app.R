# --- Packages ---------------------------------------------------------
library(shiny)
library(bslib)
library(dplyr)
library(purrr)
library(magrittr)
library(scales)
library(ggplot2)
library(DT)
library(sf)
library(whomapper)
library(readxl)
library(openxlsx)
library(zip)
library(countrycode)

options(
  bslib.inspect = FALSE,
  shiny.autoreload = FALSE,
  sass.cache = TRUE,
  shiny.devmode = FALSE
)

# whomapper::pull_sfs() fetches subnational boundaries from the WHO ArcGIS
# service over the network (via sf::st_read/GDAL) with no timeout of its
# own, so a slow or unresponsive upstream can hang indefinitely with no
# feedback to the user. Bound the connect and total transfer time so a
# dead/slow upstream fails fast instead of hanging the whole session.
Sys.setenv(
  GDAL_HTTP_CONNECTTIMEOUT = "10",
  GDAL_HTTP_TIMEOUT = "30"
)


# --- Helper functions -------------------------------------------------
helper_files <- file.path(
  "R",
  c(
    "get_risks.R",
    "make_indicator_table.R",
    "read_data.R",
    "read_shape.R",
    "validate_indicator_weights.R",
    "validate_pillar_weights.R",
    "vis_risk_table.R",
    "vis_scores.R"
  )
)

invisible(lapply(helper_files[file.exists(helper_files)], source))

whomapper_error_message <- function(e) {
  paste0(
    "The 'whomapper' package raised an error: ",
    conditionMessage(e),
    ". This may indicate a problem with a recent whomapper update.",
    " Please contact the whomapper developers ",
    "(https://github.com/whocov/whomapper/issues) or ",
    "open an issue on this app's GitHub page ",
    "(https://github.com/WHO-Collaboratory/seasonal-risk-assessment/issues) for assistance."
  )
}


# --- UI ---------------------------------------------------------------
## --- Download/Upload Data --------------------------------------------
app_header_actions_ui <- function() {
  div(
    class = "d-flex align-items-center gap-2 ms-auto app-header-actions",

    actionButton(
      "open_upload_modal",
      label = "Upload workbook",
      icon = icon("upload"),
      class = "btn btn-primary"
    ),

    uiOutput("header_download_button")
  )
}

## --- Title -----------------------------------------------------------
app_title_ui <- function() {
  div(
    class = "d-flex align-items-center w-100 gap-3",

    div(
      class = "d-flex align-items-center gap-2 app-title-brand",
      tags$img(
        src = "who-logo.png",
        height = "36px",
        alt = "World Health Organization"
      ),
      span(
        "WHO Seasonal Risk Assessment Tool for Acute Emergencies",
        style = "font-weight: 700;"
      )
    ),

    app_header_actions_ui()
  )
}

## --- Theme -----------------------------------------------------------
app_theme <- function() {
  bs_theme(
    bootswatch = "flatly",

    # Source: https://srhdteuwpubsa.z6.web.core.windows.net/gho/data/design-language/design-system/typography/
    base_font = font_google("Noto Sans"),

    # Core text colors
    fg = "#000000", # body text
    bg = "#FFFFFF",

    # Headings
    heading_color = "#009CDE", # WHO blue

    # Secondary text
    secondary = "#595959", # gray

    # Links
    link_color = "#009CDE", # WHO primary blue

    # Status colors
    danger = "#9a3709",
    warning = "#754d06",
    success = "#1d6339",
    info = "#245993",

    weights = c(400, 600, 700)
  )
}

## --- Sidebar UI ------------------------------------------------------
sidebar_ui <- function() {
  bslib::sidebar(
    width = 360,
    position = "left",
    open = "open",
    collapsible = TRUE,
    tabsetPanel(
      ### --- Instructions ---------------------------------------------
      tabPanel(
        title = "Instructions",
        tags$div(
          class = "p-2",
          tags$h5("About this tool"),
          tags$p(
            "This tool helps health authorities compare heat and cold related health risk across regions within a single country. It combines Exposure, Vulnerability, and Coping Capacity indicators into a composite risk score for each geographic unit, so areas can be ranked and prioritized."
          ),
          tags$p(
            "It's built for national ministries of health and public health authorities, with support from WHO country offices and technical partners."
          ),
          tags$p(
            tags$em(
              "Throughout this app, any use of the word \"country\" should be considered shorthand for a country, area, or territory."
            )
          ),

          tags$h5("How to use this app"),
          tags$p(
            "This app displays results from the WHO Seasonal Risk Assessment Excel workbook. It does not calculate or modify anything itself."
          ),
          tags$p(
            tags$span(
              class = "sidebar-strong",
              "All indicators, weights, and scores must be finalized in Excel before upload."
            )
          ),

          tags$h5("Quick start"),
          tags$ol(
            tags$li(
              tags$span(
                class = "sidebar-strong",
                "Complete the Excel workbook"
              ),
              tags$ul(
                tags$li(
                  "Assign indicators to Exposure, Vulnerability, or Coping Capacity."
                ),
                tags$li("Set pillar and indicator weights."),
                tags$li("Enter indicator scores for each geographic unit."),
                tags$li(
                  "Make sure composite scores calculate correctly in the workbook."
                )
              )
            ),
            tags$li(
              tags$span(
                class = "sidebar-strong",
                "Upload the completed workbook"
              ),
              " using the Upload workbook button above."
            ),
            tags$li(
              tags$span(class = "sidebar-strong", "Review results"),
              " in the Risk Scores tabs."
            )
          ),

          tags$h5("How scoring works"),
          tags$p(
            "Within each pillar, indicator scores are combined using ",
            "indicator weights: ",
            tags$code("Pillar Score = Σ (Indicator Weight × Indicator Score)"),
            "."
          ),
          tags$p(
            "The three pillar scores are then combined using pillar ",
            "weights: ",
            tags$code(
              "Composite Risk Score = Σ (Pillar Weight × Pillar Score)"
            ),
            "."
          ),
          tags$p(
            "Pillar and indicator weights are matched to their pillar/",
            "indicator by ",
            tags$strong("name"),
            ", not by row order in the workbook, so the order pillars or ",
            "indicators are listed in never changes which weight applies ",
            "to which one. See the ",
            tags$strong("Weight breakdown"),
            " tab for the exact weights currently in effect."
          ),

          tags$h5("Notes"),
          tags$ul(
            tags$li(
              "Scores are relative. Use them to compare regions within this assessment, not across different assessments or countries."
            ),
            tags$li(
              "To test different assumptions, change weights or indicators in Excel and re-upload."
            ),
            tags$li(
              "Your uploaded workbook is only processed in your browser session. It is not stored or sent anywhere."
            )
          ),

          tags$hr(),
          tags$p(tags$em(
            "Methodology note: For more details, see the ",
            tags$a(
              href = "https://github.com/WHO-Collaboratory/seasonal-risk-assessment#how-it-works",
              target = "_blank",
              "methodology guide"
            ),
            "."
          ))
        )
      ),
      ### --- Pillar Weights -------------------------------------------
      tabPanel(
        title = "Select Pillar Weights",
        uiOutput("pillar_weights"),
        uiOutput("pillar_validation_msg")
      ),
      ### --- Indicator Weights ----------------------------------------
      tabPanel(
        title = "Select Indicator Weights",
        uiOutput("indicator_weights"),
        uiOutput("indicator_validation_msg")
      ),
      ### --- Weight breakdown -------------------------------------------
      tabPanel(
        title = "Weight breakdown",
        tags$div(
          class = "p-2",
          tags$p(
            class = "small text-muted",
            "Shows exactly how the current pillar and indicator weights ",
            "combine to produce the Composite Risk Score:"
          ),
          tags$p(
            tags$code(
              "Overall Weight = Pillar Weight × Indicator Weight"
            ),
            class = "small"
          ),
          tags$p(
            class = "small text-muted",
            "An indicator's Overall Weight is its total contribution to ",
            "the Composite Risk Score. Pillar and indicator weights are ",
            "matched by pillar/indicator name, not by row order, so ",
            "reordering pillars or indicators never changes which weight ",
            "applies to which one."
          ),
          uiOutput("weight_breakdown")
        )
      )
    )
  )
}


## --- Getting Started / Welcome UI --------------------------------------
welcome_step_ui <- function(icon_name, title, text) {
  div(
    class = "welcome-step",
    div(class = "welcome-step-icon", icon(icon_name)),
    tags$h5(title),
    tags$p(text)
  )
}

welcome_screenshot_ui <- function(src, alt, caption) {
  div(
    class = "welcome-screenshot",
    tags$img(src = src, alt = alt, class = "welcome-screenshot-img"),
    tags$p(class = "welcome-screenshot-caption", caption)
  )
}

welcome_ui <- function() {
  div(
    class = "welcome-page",

    ### --- Hero -----------------------------------------------------
    div(
      class = "welcome-hero",
      tags$h2("Welcome to the WHO Seasonal Risk Assessment Tool"),
      tags$p(
        class = "welcome-lead",
        "Compare heat- and cold-related health risk across regions within a single country. This app turns a completed WHO Seasonal Risk Assessment Excel workbook into interactive summary tables and choropleth maps, and lets you test alternative pillar and indicator weightings without touching Excel."
      ),
      div(
        class = "d-flex gap-2 flex-wrap",
        downloadButton(
          "download_template",
          label = "Download blank template",
          icon = icon("file-excel"),
          class = "btn btn-outline-primary"
        ),
        actionButton(
          "open_upload_modal_landing",
          label = "Upload your workbook",
          icon = icon("upload"),
          class = "btn btn-primary"
        )
      )
    ),

    ### --- How it works -----------------------------------------------
    tags$h4("How it works", class = "welcome-section-title"),
    div(
      class = "welcome-steps",
      welcome_step_ui(
        "file-excel",
        "1. Complete the Excel workbook",
        "Assign indicators to Exposure, Vulnerability, or Coping Capacity, set pillar and indicator weights, and enter scores for each geographic unit."
      ),
      welcome_step_ui(
        "upload",
        "2. Upload it here",
        "Use the Upload workbook button above. Your file is only processed in your browser session — it is not stored or sent anywhere."
      ),
      welcome_step_ui(
        "map-location-dot",
        "3. Explore results",
        "Review composite risk scores in tables and on maps, then adjust weights interactively to test alternative assumptions."
      )
    ),

    ### --- Screenshots --------------------------------------------------
    tags$h4("What to expect", class = "welcome-section-title"),
    div(
      class = "welcome-screenshots",
      welcome_screenshot_ui(
        src = "WHO Seasonal Risk Assessment Tool Workbook (EXAMPLE).png",
        alt = "A filled-in example WHO Seasonal Risk Assessment Excel workbook",
        caption = "The Excel workbook: indicators, weights, and scores are defined here before upload."
      ),
      welcome_screenshot_ui(
        src = "WHO Seasonal Risk Assessment Tool Shiny App.png",
        alt = "The WHO Seasonal Risk Assessment Shiny app, showing a results table and risk maps",
        caption = "This app: composite risk tables and maps generated from your uploaded workbook."
      )
    ),

    tags$p(
      class = "welcome-footnote",
      "Methodology note: For more details, see the ",
      tags$a(
        href = "https://github.com/WHO-Collaboratory/seasonal-risk-assessment#how-it-works",
        target = "_blank",
        "methodology guide"
      ),
      "."
    )
  )
}


## --- Main UI ---------------------------------------------------------
main_ui <- function() {
  tagList(
    tags$style(HTML(
      "
      /* Header bar: light background so the blue WHO logo reads clearly */
      .navbar.navbar-static-top {
        background-color: #FFFFFF !important;
        border-bottom: 3px solid #009CDE;
      }
      .navbar.navbar-static-top .app-title-brand,
      .navbar.navbar-static-top .app-title-brand span {
        color: #009CDE !important;
        font-weight: 600;
      }
      /* Active tab & pagination accent: Flatly's yellow instead of the app's success green
         (scoped to these selectors only, so success checkmarks elsewhere stay green) */
      .nav-tabs .nav-link.active {
        color: #f39c12 !important;
      }
      .pagination .page-link {
        background-color: #f39c12 !important;
      }
      .pagination .page-link:hover {
        background-color: #b06f09 !important;
      }
      .pagination .page-item.active .page-link {
        background-color: #b06f09 !important;
      }
      .pagination .page-item.disabled .page-link {
        background-color: #f7ba5b !important;
        color: #7a4e00 !important;
        cursor: not-allowed;
      }
      .map-grid {
        display: grid;
        grid-template-columns: 1fr 1fr 1fr 2fr;
        gap: 20px;
        align-items: start;
      }
      .map-cell {
        padding: 5px;
      }
      /* Fix blurry text in bslib sidebar */
      .bslib-sidebar,
      .bslib-sidebar * {
        transform: none !important;
        backface-visibility: hidden;
        -webkit-font-smoothing: antialiased;
        -moz-osx-font-smoothing: grayscale;
      }

      /* Force clean font rendering */
      .bslib-sidebar {
        font-family: system-ui, -apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto, Helvetica, Arial, sans-serif;
      }

      /* Getting Started / welcome page */
      .welcome-page {
        max-width: 1100px;
        margin: 0 auto;
        padding: 8px 4px 24px;
      }
      .welcome-hero {
        padding-bottom: 8px;
        margin-bottom: 16px;
        border-bottom: 1px solid #e5e5e5;
      }
      .welcome-lead {
        max-width: 760px;
        color: #333333;
        font-size: 1.05rem;
      }
      .welcome-section-title {
        margin-top: 28px;
        margin-bottom: 12px;
      }
      .welcome-steps {
        display: grid;
        grid-template-columns: repeat(3, 1fr);
        gap: 16px;
      }
      .welcome-step {
        background-color: #f7fbfd;
        border: 1px solid #e0eef5;
        border-radius: 8px;
        padding: 16px;
      }
      .welcome-step-icon {
        color: #009CDE;
        font-size: 1.4rem;
        margin-bottom: 6px;
      }
      .welcome-step h5 {
        margin-bottom: 6px;
      }
      .welcome-step p {
        margin-bottom: 0;
        color: #595959;
        font-size: 0.92rem;
      }
      .welcome-screenshots {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 20px;
      }
      .welcome-screenshot-img {
        width: 100%;
        border: 1px solid #dddddd;
        border-radius: 6px;
      }
      .welcome-screenshot-caption {
        color: #595959;
        font-size: 0.88rem;
        margin-top: 6px;
      }
      .welcome-footnote {
        margin-top: 24px;
        color: #595959;
        font-style: italic;
      }
      @media (max-width: 900px) {
        .welcome-steps,
        .welcome-screenshots {
          grid-template-columns: 1fr;
        }
      }
      "
    )),

    conditionalPanel(
      condition = "!output.has_upload",
      welcome_ui()
    ),

    conditionalPanel(
      condition = "output.has_upload",

      ### --- Summary Tables ---------------------------------------------
      fluidRow(
        column(
          width = 12,
          h3("Risk Scores"),
          tabsetPanel(
            id = "score_tabs",

            tabPanel(
              title = "Composite Risk Scores",
              br(),
              uiOutput("table_overall")
            ),
            tabPanel(
              "Exposure",
              br(),
              uiOutput("table_exposure")
            ),
            tabPanel(
              "Vulnerability",
              br(),
              uiOutput("table_vulnerability")
            ),
            tabPanel(
              "Coping Capacity",
              br(),
              uiOutput("table_coping_capacity")
            )
          )
        )
      ),

      ## --- Maps --------------------------------------------------------
      fluidRow(
        column(
          width = 12,
          uiOutput("maps"),
          uiOutput("map_download_buttons")
        )
      )
    )
  )
}


## --- CSS -------------------------------------------------------------
global_css <- function() {
  tagList(
    tags$style(HTML(
      "
      @import url('https://fonts.googleapis.com/css2?family=Noto+Sans:wght@400;600;700&display=swap');

      body {
        font-family: 'Noto Sans', sans-serif !important;
      }

      /* Header buttons */
      .app-header-actions .btn {
        font-weight: 600;
        padding: 6px 14px;
      }

      /* Keep buttons compact in header */
      .app-header-actions .btn i {
        margin-right: 6px;
      }

      /* Helper text spacing */
      .app-header-actions .text-muted,
      .app-header-actions .text-warning {
        margin-top: 2px;
      }

      /* Disabled primary button – washed-out/greyed-out so it visibly
         reads as inactive, rather than relying on the icon alone */
      .app-header-actions .btn.btn-primary.btn-disabled {
          background-color: #e9ecef !important;
          border-color: #ced4da !important;

          color: #6c757d !important;
          opacity: 0.65;
          cursor: not-allowed !important;
          pointer-events: none;
        }

      .app-header-actions .btn.btn-primary.btn-disabled:hover {
          background-color: #e9ecef !important;
          border-color: #ced4da !important;
        }
      "
    ))
  )
}


## --- Render UI -------------------------------------------------------
ui <- page_sidebar(
  title = app_title_ui(),
  theme = app_theme(),
  fillable = TRUE,
  sidebar = sidebar_ui(),
  global_css(),
  main_ui()
)


# --- Server -----------------------------------------------------------
server <- function(input, output, session) {
  ## --- Welcome/results panel switch ------------------------------------
  # Drives the conditionalPanel switch between the welcome page and results.
  # (input.upload_data can't be read directly client-side: fileInput's JS
  # value is namespaced as "upload_data:shiny.file", so we go through a
  # server-computed output instead.)
  output$has_upload <- reactive({
    !is.null(input$upload_data)
  })
  outputOptions(output, "has_upload", suspendWhenHidden = FALSE)

  ## --- Data ingestion ------------------------------------------------
  data <- reactive({
    req(input$upload_data)
    tryCatch(
      read_data(input$upload_data$datapath),
      error = function(e) {
        showNotification(
          paste(
            "Couldn't read indicator scores from this workbook.",
            "Make sure you uploaded the WHO Seasonal Risk Assessment Tool",
            "template, with the '2. Define Indicators' and",
            "'3. Enter Indicator Scores' sheets intact."
          ),
          type = "error",
          duration = NULL
        )
        message("ERROR reading data from upload: ", e$message)
        return(NULL)
      }
    )
  })

  country_from_workbook <- reactive({
    req(input$upload_data)

    country <- readxl::read_excel(
      input$upload_data$datapath,
      sheet = "1. Describe Your Emergency",
      range = "D6",
      col_names = FALSE
    )[[1, 1]]

    validate(
      need(
        is.character(country) && nzchar(country),
        "Country name in '1. Describe Your Acute Emergency'!D6 is missing."
      )
    )

    trimws(country)
  })

  iso3_from_country <- reactive({
    req(country_from_workbook())

    iso3 <- countrycode(
      sourcevar = country_from_workbook(),
      origin = "country.name",
      destination = "iso3c"
    )

    validate(
      need(
        !is.na(iso3),
        paste("Could not map country name to ISO3:", country_from_workbook())
      )
    )

    iso3
  })

  shape <- reactive({
    req(input$upload_data)
    tryCatch(
      {
        result <- whomapper::pull_sfs(
          adm_level = 1,
          iso3 = iso3_from_country(), # Aligns with Country / Territory value entered in 1. Describe Your Emergency
          query_server = TRUE
        )

        # whomapper's own HTTP layer swallows real network/upstream errors
        # (it just message()s "failed to pull data" and returns NULL) instead
        # of raising a catchable condition, so we check for that case
        # explicitly rather than letting a downstream NULL produce a
        # confusing, unrelated error.
        if (is.null(result)) {
          stop(errorCondition(
            paste0(
              "Could not retrieve subnational boundaries from the WHO ",
              "boundary service for '",
              iso3_from_country(),
              "'. This usually means the service is temporarily unreachable ",
              "or the network request failed. Please check your connection ",
              "and try again in a moment."
            ),
            class = "shape_lookup_error"
          ))
        }

        result <- result %>%
          # Field name is truncated to 10 characters server-side (shapefile/DBF limit)
          rename(`Subnational Level` = adm1_viz_n)

        if (nrow(result) == 0) {
          stop(errorCondition(
            paste0(
              "No subnational boundaries were returned for '",
              iso3_from_country(),
              "'. The WHO boundary service may not have data for this ",
              "country/territory, or the ISO3 code may be unrecognized."
            ),
            class = "shape_lookup_error"
          ))
        }

        result
      },
      error = function(e) {
        # Errors we raise ourselves above are already specific and
        # actionable; only wrap genuinely unexpected whomapper/internal
        # errors with the generic "raised an error" boilerplate.
        showNotification(
          if (inherits(e, "shape_lookup_error")) {
            conditionMessage(e)
          } else {
            whomapper_error_message(e)
          },
          type = "error",
          duration = NULL
        )
        message("ERROR reading shape from upload: ", conditionMessage(e))
        NULL
      }
    )
  })

  observeEvent(input$upload_data, {
    tryCatch(
      {
        raw_pillar_weights_tbl <- readxl::read_excel(
          input$upload_data$datapath,
          sheet = "4. Define Weights",
          range = "B7:C15", # wide enough to cover Step 4A regardless of its exact row
          col_names = FALSE
        )

        # Locate the "Pillar" header row dynamically rather than assuming a
        # fixed row number, since editing the Instructions text above this
        # table shifts it down and previously broke a hardcoded range.
        pillar_header_row <- which(raw_pillar_weights_tbl[[1]] == "Pillar")[1]
        if (is.na(pillar_header_row)) {
          stop("Could not find the 'Pillar' header in Step 4A's table.")
        }

        # Data rows run from just below the header down to (but not
        # including) the "TOTAL" row.
        total_row <- which(raw_pillar_weights_tbl[[1]] == "TOTAL")[1]
        if (is.na(total_row) || total_row <= pillar_header_row) {
          stop("Could not find the 'TOTAL' row in Step 4A's table.")
        }

        weights$pillar <- raw_pillar_weights_tbl |> # Align with Step 4A. Define Pillar Weights table
          rlang::set_names(unlist(raw_pillar_weights_tbl[pillar_header_row, ])) |>
          dplyr::slice((pillar_header_row + 1):(total_row - 1)) |>
          dplyr::mutate(`Pillar Weight` = as.numeric(`Pillar Weight`)) |>
          as.data.frame()

        raw_indicator_weights_tbl <- readxl::read_excel(
          input$upload_data$datapath,
          sheet = "4. Define Weights",
          range = cellranger::cell_cols("F:I")
        )

        weights$indicator <- raw_indicator_weights_tbl |> # Align with Step 4B. Define Indicator Weights table
          # use first row as column names
          rlang::set_names(unlist(raw_indicator_weights_tbl[1, ])) |>
          # drop header row
          dplyr::slice(-1) |>
          # drop empty rows
          dplyr::filter(!is.na(Indicator), Indicator != "") |>
          # validate numeric values
          dplyr::mutate(
            `Indicator Weight` = as.numeric(`Indicator Weight`),
            `Overall Weight` = as.numeric(`Overall Weight`)
          ) |>
          as.data.frame()
      },
      error = function(e) {
        showNotification(
          paste(
            "Couldn't read pillar and indicator weights from this workbook.",
            "Make sure you uploaded the WHO Seasonal Risk Assessment Tool",
            "template, with the '4. Define Weights' sheet intact and in its",
            "original layout."
          ),
          type = "error",
          duration = NULL
        )
        message("ERROR reading weights from upload: ", e$message)
        weights$pillar <- NULL
        weights$indicator <- NULL
      }
    )

    req(weights$pillar, weights$indicator)

    # Initial validation
    validation <- tryCatch(
      list(
        pillar_check = validate_pillar_weights(weights$pillar),
        indicator_check = validate_indicator_weights(weights$indicator)
      ),
      error = function(e) {
        showNotification(
          paste(
            "Couldn't validate pillar and indicator weights from this",
            "workbook. Make sure you uploaded the WHO Seasonal Risk",
            "Assessment Tool template, with the '4. Define Weights' sheet",
            "intact and in its original layout.",
            paste0("(Details: ", conditionMessage(e), ")")
          ),
          type = "error",
          duration = NULL
        )
        message("ERROR validating weights from upload: ", conditionMessage(e))
        NULL
      }
    )

    if (is.null(validation)) {
      weights$pillar <- NULL
      weights$indicator <- NULL
      return()
    }

    pillar_check <- validation$pillar_check
    indicator_check <- validation$indicator_check

    if (!pillar_check$valid || any(!indicator_check$valid)) {
      msg <- c()

      if (!pillar_check$valid) {
        msg <- c(
          msg,
          sprintf(
            "Pillar weights sum to %.1f%% (off by %+0.1f%%).",
            pillar_check$total * 100,
            pillar_check$off_by * 100
          )
        )
      }

      bad_indicators <- indicator_check |> filter(!valid)

      if (nrow(bad_indicators) > 0) {
        msg <- c(
          msg,
          paste0(
            "Indicator weights do not sum to 100% for\n",
            paste(
              sprintf(
                "%s: %.1f%% (off by %+0.1f%%)",
                bad_indicators$Pillar,
                bad_indicators$total * 100,
                bad_indicators$off_by * 100
              ),
              collapse = "\n"
            )
          )
        )
      }

      showNotification(
        paste(msg, collapse = "\n"),
        type = "error",
        duration = NULL
      )

      values$risks <- NULL
      return()
    }
  })

  ## --- Reactive state ------------------------------------------------
  values <- reactiveValues(
    risks = NULL,
    groupings = NULL,
    weightings = NULL,
    weightings_table = NULL
  )

  ### --- Weight defaults ----------------------------------------------
  weights <- reactiveValues(
    pillar = NULL,
    indicator = NULL
  )

  ### --- Weight updates -----------------------------------------------
  pillar_weights_updated <- reactive({
    req(weights$pillar)

    df <- weights$pillar

    df$`Pillar Weight` <- vapply(
      seq_len(nrow(df)),
      function(i) {
        p <- df$Pillar[i]
        input_val <- input[[paste0("pillar_", p)]]
        if (is.null(input_val)) df$`Pillar Weight`[i] else input_val / 100
      },
      numeric(1)
    )

    df
  })

  indicator_weights_updated <- reactive({
    req(weights$indicator)

    df <- weights$indicator

    row_in_pillar <- ave(seq_len(nrow(df)), df$Pillar, FUN = seq_along)

    df$`Indicator Weight` <- vapply(
      seq_len(nrow(df)),
      function(i) {
        id <- paste0("indicator_", df$Pillar[i], "_", row_in_pillar[i])
        input_val <- input[[id]]
        if (is.null(input_val)) df$`Indicator Weight`[i] else input_val / 100
      },
      numeric(1)
    )

    df
  })

  ### --- Weight validation --------------------------------------------
  pillar_validation <- reactive({
    req(pillar_weights_updated())
    validate_pillar_weights(pillar_weights_updated())
  })

  indicator_validation <- reactive({
    req(indicator_weights_updated())
    validate_indicator_weights(indicator_weights_updated())
  })

  weights_valid <- reactive({
    pv <- pillar_validation()
    iv <- indicator_validation()

    pv$valid && all(iv$valid)
  })

  ## --- Weight computation --------------------------------------------
  pillar_weightings <- reactive({
    req(weights$pillar)

    vals <- vapply(
      seq_len(nrow(weights$pillar)),
      function(i) {
        p <- weights$pillar$Pillar[i]
        input_val <- input[[paste0("pillar_", p)]]
        if (is.null(input_val)) {
          weights$pillar$`Pillar Weight`[i]
        } else {
          input_val / 100
        }
      },
      numeric(1)
    )

    vals <- vals / sum(vals, na.rm = TRUE)
    setNames(vals, weights$pillar$Pillar)
  })

  indicator_groupings <- reactive({
    req(weights$indicator)

    split(weights$indicator, weights$indicator$Pillar) |>
      map(function(df) {
        vals <- vapply(
          seq_len(nrow(df)),
          function(i) {
            id <- paste0("indicator_", df$Pillar[i], "_", i)
            input_val <- input[[id]]
            if (is.null(input_val)) {
              df$`Indicator Weight`[i]
            } else {
              input_val / 100
            }
          },
          numeric(1)
        )
        vals <- vals / sum(vals, na.rm = TRUE)
        setNames(vals, df$Indicator)
      })
  })

  ## --- Risk computation ----------------------------------------------
  observe({
    req(data(), weights$pillar, weights$indicator, weights_valid())

    tryCatch(
      {
        values$groupings <- indicator_groupings()
        values$weightings <- pillar_weightings()

        values$weightings_table <- map_dfr(
          seq_along(values$weightings),
          \(x) {
            tibble(
              pillar = names(values$groupings)[x],
              metric = names(values$groupings[[x]]),
              pillar_weight = values$weightings[x],
              metric_weight = values$groupings[[x]],
              total_weight = values$weightings[x] * values$groupings[[x]]
            )
          }
        )
        values$risks <- get_risks(
          groupings = values$groupings,
          scores = data()$scores,
          weightings = values$weightings
        )
      },
      error = function(e) {
        showNotification(
          paste(
            "Couldn't calculate risk scores. This usually means a Pillar",
            "name in the indicator weights table (Step 4B) doesn't exactly",
            "match a pillar name in the pillar weights table (Step 4A) —",
            "check for typos, extra spaces, or inconsistent capitalization",
            "in the 'Pillar' column of the '4. Define Weights' sheet.",
            paste0("(Details: ", conditionMessage(e), ")")
          ),
          type = "error",
          duration = NULL
        )
        message("ERROR computing risks: ", conditionMessage(e))
        values$risks <- NULL
        values$groupings <- NULL
        values$weightings <- NULL
        values$weightings_table <- NULL
      }
    )
  })

  map_sf <- reactive({
    req(values$risks, shape())

    shape() %>%
      left_join(values$risks, by = "Subnational Level")
  })

  ## --- Tables --------------------------------------------------------
  no_workbook_message <- function(content) {
    tagList(
      tags$h4("No workbook uploaded"),
      tags$p(
        paste0(
          "To view ",
          content,
          ", upload a completed WHO Seasonal Risk Assessment Excel workbook "
        ),
        "using the Upload workbook button in the upper righthand corner."
      ),
      tags$p(
        "The workbook must include defined indicators, weights, and scores. "
      )
    )
  }

  no_workbook_weights_message <- function(label) {
    tags$div(
      class = "p-2",
      tags$h5("No workbook uploaded"),
      tags$p(
        paste0(
          label,
          " are defined in the Seasonal Risk Assessment Excel workbook."
        )
      ),
      tags$p(
        paste0(
          "Upload a completed workbook to view and review ",
          tolower(label),
          "."
        )
      )
    )
  }

  weights_invalid_message <- function(content = "Tables") {
    pv <- pillar_validation()
    iv <- indicator_validation()

    issues <- list()

    if (!pv$valid) {
      issues <- c(
        issues,
        list(
          sprintf(
            paste0(
              "Pillar weights sum to %.1f%% (off by %+0.1f%%). Fix this ",
              "under Select Pillar Weights."
            ),
            pv$total * 100,
            pv$off_by * 100
          )
        )
      )
    }

    bad_indicators <- iv |> filter(!valid)

    if (nrow(bad_indicators) > 0) {
      issues <- c(
        issues,
        lapply(seq_len(nrow(bad_indicators)), function(i) {
          sprintf(
            paste0(
              "%s indicator weights sum to %.1f%% (off by %+0.1f%%). Fix ",
              "this under Select Indicator Weights > %s."
            ),
            bad_indicators$Pillar[i],
            bad_indicators$total[i] * 100,
            bad_indicators$off_by[i] * 100,
            bad_indicators$Pillar[i]
          )
        })
      )
    }

    tagList(
      tags$p(sprintf(
        "%s are disabled until all weights sum to 100%%:",
        content
      )),
      tags$ul(lapply(issues, tags$li))
    )
  }

  output$table_overall <- renderUI({
    if (is.null(input$upload_data)) {
      return(no_workbook_message("the composite risk score table"))
    }
    if (!weights_valid()) {
      return(weights_invalid_message())
    }
    DT::dataTableOutput("table_overall_dt")
  })

  output$table_overall_dt <- DT::renderDT({
    req(values$risks)

    df <- values$risks %>%
      dplyr::select(
        `Subnational Level`,
        Exposure,
        Vulnerability,
        `Coping Capacity`,
        `Composite Risk Score`
      )

    vis_risk_table(df, values$weightings)
  })

  output$table_exposure <- renderUI({
    if (is.null(input$upload_data)) {
      return(no_workbook_message("the exposure indicator table"))
    }
    if (!weights_valid()) {
      return(weights_invalid_message())
    }
    DT::dataTableOutput("table_exposure_dt")
  })

  output$table_exposure_dt <- DT::renderDT({
    req(values$risks, values$groupings, data())

    df <- make_indicator_table(
      scores = data()$scores,
      risks = values$risks,
      groupings = values$groupings,
      pillar_name = "Exposure"
    )
    vis_risk_table(df, values$groupings[["Exposure"]])
  })

  output$table_vulnerability <- renderUI({
    if (is.null(input$upload_data)) {
      return(no_workbook_message("the vulnerability indicator table"))
    }
    if (!weights_valid()) {
      return(weights_invalid_message())
    }
    DT::dataTableOutput("table_vulnerability_dt")
  })

  output$table_vulnerability_dt <- DT::renderDT({
    req(values$risks, values$groupings, data())

    df <- make_indicator_table(
      scores = data()$scores,
      risks = values$risks,
      groupings = values$groupings,
      pillar_name = "Vulnerability"
    )
    vis_risk_table(df, values$groupings[["Vulnerability"]])
  })

  output$table_coping_capacity <- renderUI({
    if (is.null(input$upload_data)) {
      return(no_workbook_message("the coping capacity indicator table"))
    }
    if (!weights_valid()) {
      return(weights_invalid_message())
    }
    DT::dataTableOutput("table_coping_capacity_dt")
  })

  output$table_coping_capacity_dt <- DT::renderDT({
    req(values$risks, values$groupings, data())

    df <- make_indicator_table(
      scores = data()$scores,
      risks = values$risks,
      groupings = values$groupings,
      pillar_name = "Coping Capacity"
    )
    vis_risk_table(df, values$groupings[["Coping Capacity"]])
  })

  outputOptions(output, "table_overall", suspendWhenHidden = FALSE)
  outputOptions(output, "table_exposure", suspendWhenHidden = FALSE)
  outputOptions(output, "table_vulnerability", suspendWhenHidden = FALSE)
  outputOptions(output, "table_coping_capacity", suspendWhenHidden = FALSE)

  ## --- Maps ----------------------------------------------------------
  observe({
    req(weights_valid(), values$risks, shape())

    map_order <- c("Exposure", "Vulnerability", "Coping Capacity")
    nms <- c(
      intersect(map_order, names(values$groupings)),
      "Composite Risk Score"
    )

    lapply(nms, function(name) {
      local({
        nm <- name
        output[[paste0("map_", gsub(" ", "_", nm))]] <- renderPlot({
          tryCatch(
            vis_scores(
              map_sf = map_sf(),
              value = nm,
              title = nm
            ),
            error = function(e) {
              showNotification(
                whomapper_error_message(e),
                type = "error",
                duration = NULL
              )
              NULL
            }
          )
        })
      })
    })
  })

  output$maps <- renderUI({
    if (!weights_valid()) {
      div(
        class = "text-danger",
        weights_invalid_message("Maps")
      )
    } else {
      validate(need(!is.null(data()), "No valid data available."))
      req(values$risks, shape())

      map_order <- c("Exposure", "Vulnerability", "Coping Capacity")

      nms <- c(
        intersect(map_order, names(values$groupings)),
        "Composite Risk Score"
      )
      cells <- lapply(nms, function(name) {
        div(
          class = "map-cell",
          plotOutput(outputId = paste0("map_", gsub(" ", "_", name)))
        )
      })

      div(class = "map-grid", !!!cells)
    }
  })

  output$map_download_buttons <- renderUI({
    req(weights_valid(), values$risks, shape())

    div(
      class = "d-flex justify-content-end mt-3 mb-4",
      downloadButton(
        "download_maps_png",
        "Download maps",
        class = "btn-primary"
      )
    )
  })

  output$download_maps_png <- downloadHandler(
    filename = function() {
      paste0("WHO_Seasonal_Risk_Assessment_Maps_", Sys.Date(), ".zip")
    },
    content = function(file) {
      tmpdir <- tempdir()

      map_names <- c(
        intersect(
          c("Exposure", "Vulnerability", "Coping Capacity"),
          names(values$groupings)
        ),
        "Composite Risk Score"
      )

      png_files <- character(0)

      for (nm in map_names) {
        p <- tryCatch(
          vis_scores(
            map_sf = map_sf(),
            value = nm,
            title = nm
          ),
          error = function(e) {
            showNotification(
              whomapper_error_message(e),
              type = "error",
              duration = NULL
            )
            stop(e)
          }
        )

        outfile <- file.path(
          tmpdir,
          paste0("WHO_Seasonal_Risk_Assessment_Maps_", nm, ".png")
        )

        ggsave(
          filename = outfile,
          plot = p,
          width = 8,
          height = 6,
          dpi = 300,
          bg = "white"
        )

        png_files <- c(png_files, outfile)
      }

      zip::zipr(file, png_files)
    }
  )

  ## --- Weight Tables UI ----------------------------------------------
  output$pillar_weights <- renderUI({
    if (is.null(input$upload_data)) {
      return(no_workbook_weights_message("Pillar weights"))
    }

    req(weights$pillar)

    tagList(
      lapply(seq_len(nrow(weights$pillar)), function(i) {
        pillar_name <- weights$pillar$Pillar[i]
        pillar_weight <- weights$pillar$`Pillar Weight`[i]

        numericInput(
          inputId = paste0("pillar_", pillar_name),
          label = paste0(pillar_name, " (%)"),
          value = round(pillar_weight * 100, 2),
          min = 0,
          max = 100,
          step = 5
        )
      })
    )
  })

  output$indicator_weights <- renderUI({
    if (is.null(input$upload_data)) {
      return(no_workbook_weights_message("Indicator weights"))
    }

    req(weights$indicator)

    tabs <- lapply(unique(weights$indicator$Pillar), function(pillar) {
      df <- weights$indicator |> filter(Pillar == pillar)

      tabPanel(
        title = pillar,
        tagList(
          lapply(seq_len(nrow(df)), function(i) {
            numericInput(
              inputId = paste0("indicator_", pillar, "_", i),
              label = paste0(df$Indicator[i], " (%)"),
              value = round(df$`Indicator Weight`[i] * 100, 2),
              min = 0,
              max = 100,
              step = 5
            )
          })
        )
      )
    })

    do.call(tabsetPanel, c(list(id = "indicator_tab"), tabs))
  })
  output$pillar_validation_msg <- renderUI({
    v <- pillar_validation()

    if (v$valid) {
      div(class = "text-success small", "✓ Pillar weights sum to 100%")
    } else {
      div(
        class = "text-danger small",
        sprintf(
          "Pillar weights sum to %.1f%% (off by %+0.1f%%)",
          v$total * 100,
          v$off_by * 100
        )
      )
    }
  })

  output$indicator_validation_msg <- renderUI({
    req(input$indicator_tab)

    v <- indicator_validation()

    row <- v |> filter(Pillar == input$indicator_tab)

    if (nrow(row) == 0) {
      return(NULL)
    }

    if (row$valid) {
      div(
        class = "text-success small",
        sprintf("✓ %s indicators sum to 100%%", row$Pillar)
      )
    } else {
      div(
        class = "text-danger small",
        sprintf(
          "%s indicators sum to %.1f%% (off by %+0.1f%%)",
          row$Pillar,
          row$total * 100,
          row$off_by * 100
        )
      )
    }
  })

  output$weight_breakdown <- renderUI({
    if (is.null(input$upload_data)) {
      return(tags$div(
        class = "p-2",
        tags$h5("No workbook uploaded"),
        tags$p(
          "Upload a completed workbook to see how pillar and indicator ",
          "weights combine into each indicator's overall contribution to ",
          "the Composite Risk Score."
        )
      ))
    }

    req(values$weightings_table)

    rows_by_pillar <- split(values$weightings_table, values$weightings_table$pillar)

    tagList(
      lapply(names(rows_by_pillar), function(p) {
        pillar_rows <- rows_by_pillar[[p]]

        tags$table(
          class = "table table-sm small mb-3",
          tags$thead(
            tags$tr(
              tags$th(
                colspan = 3,
                sprintf(
                  "%s (pillar weight %s)",
                  p,
                  scales::percent(pillar_rows$pillar_weight[1])
                )
              )
            ),
            tags$tr(
              tags$th("Indicator"),
              tags$th("Indicator weight"),
              tags$th("Overall weight")
            )
          ),
          tags$tbody(
            lapply(seq_len(nrow(pillar_rows)), function(i) {
              tags$tr(
                tags$td(pillar_rows$metric[i]),
                tags$td(scales::percent(pillar_rows$metric_weight[i])),
                tags$td(scales::percent(pillar_rows$total_weight[i]))
              )
            })
          )
        )
      })
    )
  })

  ## --- Workbook upload/download --------------------------------------
  show_upload_modal <- function() {
    showModal(
      modalDialog(
        title = "Upload WHO Seasonal Risk Assessment workbook",

        fileInput(
          "upload_data",
          label = NULL,
          buttonLabel = "Choose Excel file",
          accept = c(".xlsx"),
          width = "100%"
        ),

        footer = modalButton("Close"),
        easyClose = TRUE
      )
    )
  }

  observeEvent(input$open_upload_modal, show_upload_modal())
  observeEvent(input$open_upload_modal_landing, show_upload_modal())

  output$download_template <- downloadHandler(
    filename = function() {
      "WHO_Seasonal_Risk_Assessment_Tool_TEMPLATE.xlsx"
    },
    content = function(file) {
      file.copy(
        file.path("data", "WHO Seasonal Risk Assessment Tool (TEMPLATE).xlsx"),
        file
      )
    }
  )

  output$header_download_button <- renderUI({
    btn_class <- "btn btn-primary"
    btn_title <- NULL

    if (is.null(input$upload_data)) {
      btn_class <- "btn btn-primary btn-disabled"
      btn_title <- "Upload a workbook before downloading"
    } else if (!weights_valid()) {
      btn_class <- "btn btn-primary btn-disabled"
      btn_title <- paste(
        "Can't download: pillar and/or indicator weights don't sum to",
        "100%. Adjust the weights until the validation messages show a",
        "checkmark, then try downloading again."
      )
    }

    div(
      class = "d-flex flex-column align-items-start",
      downloadButton(
        "download_updated_file",
        label = "Download workbook",
        icon = icon("download"),
        class = btn_class,
        title = btn_title
      )
    )
  })

  # File downloads
  output$download_updated_file <- downloadHandler(
    filename = function() {
      tryCatch(
        {
          paste0("WHO_Seasonal_Risk_Assessment_Tool_", Sys.Date(), ".xlsx")
        },
        error = function(e) {
          showNotification(
            paste("Error in filename function:", e$message),
            type = "error",
            duration = NULL
          )
          "download.xlsx"
        }
      )
    },
    content = function(file) {
      tryCatch(
        {
          req(input$upload_data)

          pillar_data_check <- pillar_weights_updated()

          indicator_data_check <- indicator_weights_updated()

          weights_check <- weights_valid()

          if (!weights_check) {
            showNotification(
              paste(
                "Can't download: pillar and/or indicator weights don't sum",
                "to 100%. Adjust the weights until the validation messages",
                "show a checkmark, then try downloading again."
              ),
              type = "error",
              duration = NULL
            )
          }

          req(weights_check)

          validate(
            need(
              !is.null(input$upload_data$datapath),
              "Upload data path is missing"
            )
          )

          # Strategy: Copy the original file and modify only specific cells
          # This preserves all formatting, formulas, and conditional formatting
          upload_path <- input$upload_data$datapath

          # Create a temporary copy of the uploaded file
          temp_copy <- tempfile(fileext = ".xlsx")
          file.copy(upload_path, temp_copy, overwrite = TRUE)

          # Try openxlsx2 first (better at handling complex files)
          if (requireNamespace("openxlsx2", quietly = TRUE)) {
            wb <- openxlsx2::wb_load(temp_copy)
            wb_type <- "openxlsx2"
          } else {
            # Try openxlsx loadWorkbook with the copy
            wb <- tryCatch(
              {
                loaded_wb <- openxlsx::loadWorkbook(temp_copy)
                loaded_wb
              },
              error = function(e) {
                # Fallback: recreate workbook
                sheet_names <- readxl::excel_sheets(temp_copy)
                new_wb <- openxlsx::createWorkbook()
                for (sheet_name in sheet_names) {
                  tryCatch(
                    {
                      sheet_data <- readxl::read_excel(
                        temp_copy,
                        sheet = sheet_name,
                        col_names = FALSE,
                        .name_repair = "minimal"
                      )
                      openxlsx::addWorksheet(new_wb, sheet_name)
                      openxlsx::writeData(
                        new_wb,
                        sheet = sheet_name,
                        x = sheet_data,
                        colNames = FALSE
                      )
                    },
                    error = function(e2) {
                      message(
                        "Warning: Could not process sheet '",
                        sheet_name,
                        "': ",
                        e2$message
                      )
                    }
                  )
                }
                new_wb
              }
            )
            wb_type <- "openxlsx"
          }

          # Write pillar weights to "4. Define Weights" sheet
          sheet_list <- if (wb_type == "openxlsx2") {
            wb$sheet_names
          } else {
            names(wb)
          }

          if ("4. Define Weights" %in% sheet_list) {
            pillar_data <- pillar_weights_updated()

            # Row 9 = headers, Rows 10-12 = data
            if (wb_type == "openxlsx2") {
              # openxlsx2 syntax
              wb <- openxlsx2::wb_add_data(
                wb,
                sheet = "4. Define Weights",
                x = pillar_data,
                start_row = 10,
                start_col = 2,
                col_names = FALSE
              )
            } else {
              # openxlsx syntax
              openxlsx::writeData(
                wb,
                sheet = "4. Define Weights",
                x = pillar_data,
                startRow = 10,
                startCol = 2,
                colNames = FALSE
              )
            }

            # Write indicator weights to the same sheet
            indicator_data <- indicator_weights_updated()

            if (
              !is.null(indicator_data) &&
                nrow(indicator_data) > 0 &&
                "Indicator Weight" %in% names(indicator_data)
            ) {
              ind_weights <- indicator_data[["Indicator Weight"]]

              # Write just the Indicator Weight column values
              # Row 9 = column headers, Rows 10+ = data
              if (wb_type == "openxlsx2") {
                wb <- openxlsx2::wb_add_data(
                  wb,
                  sheet = "4. Define Weights",
                  x = as.data.frame(ind_weights),
                  start_row = 10,
                  start_col = 8,
                  col_names = FALSE
                )
              } else {
                openxlsx::writeData(
                  wb,
                  sheet = "4. Define Weights",
                  x = ind_weights,
                  startRow = 10,
                  startCol = 8,
                  colNames = FALSE
                )
              }
            }
          }

          if (wb_type == "openxlsx2") {
            openxlsx2::wb_save(wb, file, overwrite = TRUE)
          } else {
            openxlsx::saveWorkbook(wb, file, overwrite = TRUE)
          }
        },
        error = function(e) {
          if (inherits(e, "shiny.silent.error")) {
            stop(e)
          }
          showNotification(
            "Something went wrong preparing the download. Please re-upload your workbook and try again.",
            type = "error",
            duration = NULL
          )
          message("ERROR: ", e$message)
          message(
            "ERROR traceback: ",
            paste(deparse(sys.calls()), collapse = "\n")
          )
          stop(e)
        }
      )
    }
  )
}

shinyApp(ui = ui, server = server)
