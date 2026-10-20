# Copyright 2026 World Health Organization
# SPDX-License-Identifier: Apache-2.0

#' Shared risk-score colour scale.
#'
#' Used by both the map (\code{vis_scores}) and the score tables
#' (\code{vis_risk_table}) so the two views read consistently.
#'
#' WHO GHO design system diverging scale: low (good) = navy, high (bad) = red.
#' https://srhdteuwpubsa.z6.web.core.windows.net/gho/data/design-language/design-system/colors/
risk_palette <- function() {
  c(
    "#0f2d5b",
    "#53abd0",
    "#d6dae5",
    "#d9777d",
    "#a00016"
  )
}

#' Colour-scale limits for a set of scores.
#'
#' The palette is stretched across the observed range of the data, so any
#' indicator score range works. If every score is identical the range is
#' widened by 0.5 either side so the scale stays valid (a single mid-palette
#' colour). Falls back to 1-5 when there are no finite scores.
#'
#' @param x Numeric vector (or anything coercible) of scores.
#' @return A length-2 numeric vector: c(min, max).
score_limits <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  x <- x[is.finite(x)]
  if (length(x) == 0) {
    return(c(1, 5))
  }
  lims <- range(x)
  if (lims[1] == lims[2]) {
    lims <- lims + c(-0.5, 0.5)
  }
  lims
}
