# Copyright 2026 World Health Organization
# SPDX-License-Identifier: Apache-2.0

#' Visualise risk scores in a table.
#'
#' @importFrom DT datatable formatStyle styleInterval
#' @importFrom scales percent
#'
#' @author Finlay Campbell
#'
#' @param risk The updated risk table access via \code{values$}
#' @param weightings The updated weightings access via \code{values$}
#' @param limits Optional colour-scale limits, c(min, max), shared with the
#'   maps. \code{NULL} stretches the colours over this table's own scores.
#'
vis_risk_table <- function(tbl, weightings, key_col = NULL, limits = NULL) {
  if (is.null(tbl) || is.null(weightings)) {
    return(NULL)
  }

  # Identify key column
  if (is.null(key_col)) {
    key_col <- names(tbl)[1]
  }

  # Identify last (total) column
  last_col <- names(tbl)[ncol(tbl)]

  # ---- Sort by last column, NAs always last ----
  tbl <- tbl[
    order(
      is.na(tbl[[last_col]]),
      -tbl[[last_col]],
      na.last = TRUE
    ),
  ]

  # ---- Format numeric columns to 2 decimals ----
  tbl_fmt <- tbl %>%
    dplyr::mutate(across(where(is.numeric), ~ sprintf("%.2f", .x)))

  # ---- Add % to weight-bearing indicator columns ----
  tbl_fmt <- tbl_fmt %>%
    dplyr::rename_with(function(cols) {
      sapply(cols, function(col) {
        if (col %in% names(weightings)) {
          paste0(col, " (", scales::percent(weightings[col]), ")")
        } else {
          col
        }
      })
    })

  # ---- Label total column ----
  names(tbl_fmt)[names(tbl_fmt) == last_col] <- paste0(last_col, " (Total)")

  # ---- Heatmap the score columns on the same range as the maps ----
  score_cols <- names(tbl_fmt)[-1]

  lims <- if (is.null(limits)) {
    score_limits(unlist(tbl[vapply(tbl, is.numeric, logical(1))]))
  } else {
    limits
  }

  n_bins <- 101
  bg_colors <- grDevices::colorRampPalette(risk_palette(), space = "Lab")(n_bins)
  cuts <- seq(lims[1], lims[2], length.out = n_bins - 1)

  # Pick legible text colour per bin, since the palette runs into near-black
  # navy and dark red at the extremes.
  text_colors <- vapply(bg_colors, function(col) {
    rgb <- grDevices::col2rgb(col)
    luminance <- sum(rgb * c(0.299, 0.587, 0.114))
    if (luminance < 140) "white" else "black"
  }, character(1))

  DT::datatable(tbl_fmt) %>%
    DT::formatStyle(
      columns = score_cols,
      backgroundColor = DT::styleInterval(cuts, bg_colors),
      color = DT::styleInterval(cuts, text_colors),
      textAlign = "center"
    )
}
