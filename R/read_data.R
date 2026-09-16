#' Read scores and groupings from data file provided
#'
#' @details The \code{groupings} in the returned list assign indicators to
#'   pillars with \strong{equal} weights within each pillar — they do not
#'   reflect the actual indicator/pillar weights entered in the "4. Define
#'   Weights" sheet. The Shiny app does not use these groupings for scoring;
#'   it builds its own weighted groupings from "4. Define Weights" (see
#'   \code{indicator_groupings()} / \code{pillar_weightings()} in
#'   \code{app.R}) before calling \code{get_risks()}. Use this function's
#'   \code{groupings} only for indicator/pillar membership, not weights.
#'
#' @importFrom readxl read_excel
#'
#' @author Finlay Campbell
#'

read_data <- function(path) {
  # --- Read both sheets ---
  indicator_data <- readxl::read_excel(
    path,
    sheet = "3. Enter Indicator Scores",
    skip = 7, # skip to row containing indicator name
  ) |>
    # drop Indicator ID row
    dplyr::filter(
      !(is.na(`Country / Territory`) & is.na(`Subnational Level`))
    ) |>
    # drop fully empty columns
    dplyr::select(
      dplyr::where(~ !all(is.na(.x) | .x == ""))
    ) |>
    # coerce indicator columns to numeric
    dplyr::mutate(
      dplyr::across(
        -c(`Country / Territory`, `Subnational Level`),
        as.numeric
      )
    )

  indicator_meta <- readxl::read_excel(
    path,
    sheet = "2. Define Indicators",
    skip = 7 # skip to row containing column names
  ) |>
    filter(Include)

  # --- Extract indicator columns automatically ---
  indicator_cols <- setdiff(
    names(indicator_data),
    c("Country / Territory", "Subnational Level")
  )

  # --- Filter metadata so it only includes indicators present in the data ---
  meta_clean <- indicator_meta %>%
    filter(Indicator %in% indicator_cols)

  # --- Build groupings: pillar → vector of equal-weight indicators ---
  groupings <- meta_clean %>%
    split(.$Pillar) %>% # split into Exposure / Vulnerability / Coping Capacity
    lapply(function(df) {
      n <- nrow(df)
      w <- rep(1 / n, n) # equal weights for each indicator
      names(w) <- df$Indicator
      w
    })

  # --- Scores table ---
  scores <- indicator_data %>%
    select(`Subnational Level`, all_of(indicator_cols))

  return(list(
    scores = scores,
    groupings = groupings,
    metadata = meta_clean
  ))
}
