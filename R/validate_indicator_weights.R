# Copyright 2026 World Health Organization
# SPDX-License-Identifier: Apache-2.0

validate_indicator_weights <- function(df, tol = 1.5e-3) {
  stopifnot(all(c("Pillar", "Indicator", "Indicator Weight") %in% names(df)))

  df %>%
    group_by(Pillar) %>%
    summarise(
      total = sum(`Indicator Weight`, na.rm = TRUE),
      off_by = total - 1,
      valid = abs(off_by) < tol,
      .groups = "drop"
    )
}

#' Read Step 4B (indicator weights) from an uploaded workbook.
#'
#' Reads F1:I200 as an explicit range so each row's index is its sheet row
#' number (kept as \code{sheet_row}). Step 4B has one row per Step 2 slot, with
#' gaps for empty or excluded slots, so the download must write each weight
#' back to the row it came from rather than to consecutive rows. Excluded
#' indicators keep their typed weight in the workbook (so it is still there if
#' they are re-included) but are dropped here, as are rows with no indicator.
#'
#' @param path Path to the workbook.
read_indicator_weights <- function(path) {
  raw <- readxl::read_excel(
    path,
    sheet = "4. Define Weights",
    range = cellranger::cell_limits(c(1, 6), c(200, 9)),
    col_names = FALSE,
    col_types = "text",
    .name_repair = "minimal"
  )

  header_row <- which(raw[[1]] == "Indicator")[1]
  if (is.na(header_row)) {
    stop("Could not find the 'Indicator' header in Step 4B's table.")
  }

  raw |>
    rlang::set_names(unlist(raw[header_row, ])) |>
    dplyr::mutate(sheet_row = dplyr::row_number()) |>
    # drop everything down to and including the header row
    dplyr::slice(-seq_len(header_row)) |>
    # drop empty rows
    dplyr::filter(!is.na(Indicator), Indicator != "") |>
    dplyr::filter(is.na(Pillar) | Pillar != "Excluded") |>
    # validate numeric values
    dplyr::mutate(
      Indicator = trimws(Indicator),
      `Indicator Weight` = as.numeric(`Indicator Weight`),
      `Overall Weight` = as.numeric(`Overall Weight`)
    ) |>
    as.data.frame()
}

#' Problems that stop indicator weights from being used.
#'
#' Fails loudly instead of scoring with gaps: every included indicator needs a
#' weight in Step 4, and Step 4 must list exactly the indicators that Step 2
#' includes. (Whether weights sum to 100% is checked separately by
#' \code{validate_indicator_weights()}.)
#'
#' @param df Indicator weights, as returned by \code{read_indicator_weights()}.
#' @param included Names of the indicators included in Step 2, or \code{NULL}
#'   to skip the cross-check (e.g. when Step 2/3 couldn't be read).
#' @param pillars Pillar weights table (Step 4A, columns \code{Pillar} and
#'   \code{Pillar Weight}), or \code{NULL} to skip the pillar checks. Every
#'   pillar needs a weight (0\% is fine, blank is not) and at least one
#'   included indicator.
#' @return Character vector of plain-language problems (empty if none).
indicator_weight_problems <- function(df, included = NULL, pillars = NULL) {
  problems <- character()

  if (!is.null(pillars)) {
    no_pillar_weight <- pillars$Pillar[is.na(pillars$`Pillar Weight`)]
    if (length(no_pillar_weight) > 0) {
      problems <- c(
        problems,
        paste0(
          "Pillar weights are missing in Step 4 for: ",
          paste(no_pillar_weight, collapse = "; "),
          ". Enter 0% if a pillar should not count."
        )
      )
    }
    empty_pillars <- setdiff(pillars$Pillar, df$Pillar)
    if (length(empty_pillars) > 0) {
      problems <- c(
        problems,
        paste0(
          "Every pillar needs at least one included indicator in Step 2. ",
          "None for: ",
          paste(empty_pillars, collapse = "; "),
          "."
        )
      )
    }
  }

  no_weight <- df$Indicator[is.na(df$`Indicator Weight`)]
  if (length(no_weight) > 0) {
    problems <- c(
      problems,
      paste0(
        "These included indicators have no weight in Step 4: ",
        paste(no_weight, collapse = "; "),
        ". Enter 0% if an indicator should not count."
      )
    )
  }

  if (!is.null(included)) {
    not_in_step4 <- setdiff(included, df$Indicator)
    not_in_step2 <- setdiff(df$Indicator, included)
    if (length(not_in_step4) > 0) {
      problems <- c(
        problems,
        paste0(
          "These indicators are included in Step 2 but missing from Step 4: ",
          paste(not_in_step4, collapse = "; "),
          "."
        )
      )
    }
    if (length(not_in_step2) > 0) {
      problems <- c(
        problems,
        paste0(
          "These indicators have weights in Step 4 but aren't included in ",
          "Step 2: ",
          paste(not_in_step2, collapse = "; "),
          "."
        )
      )
    }
  }

  problems
}
