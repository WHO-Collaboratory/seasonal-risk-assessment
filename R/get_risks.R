# Copyright 2026 World Health Organization
# SPDX-License-Identifier: Apache-2.0

# TODO(multiplicative-score): PR-readiness checklist for this branch. Search
# the repo for "TODO(multiplicative-score)" to find every item; delete each
# one as it is resolved, and remove this block when none remain.
#   1. Workbook: sheets "5. Weighted Indicator Scores" and "6. Composite Risk
#      Scores" (main + EXAMPLE) still use the additive formula, so the
#      workbook and this function now disagree. They must be ported to
#      prod(pillar ^ weight) and the Instructions text updated. See README.
#   2. Direction of Coping Capacity (see the TODO in the function body).
#   3. Input edge cases (see the TODO in the function body).
#   4. Unit tests for get_risks() (see tests/test_upload_checks.R).
#   5. App help-text wording (see app.R) needs methodology sign-off.
#   6. Record the methodology decision (weighted geometric mean, pillar
#      weights as exponents) in the GitHub issue before opening the PR.

#' Calculate risks from groupings, scores and overall weightings
#'
#' @details Scoring combines indicators and pillars using two different
#'   rules:
#'   \itemize{
#'     \item \strong{Within each pillar} (using \code{groupings}):
#'       \code{Pillar Score = sum(Indicator Weight * Indicator Score)}, an
#'       arithmetic weighted sum, so indicators within a pillar can offset
#'       one another.
#'     \item \strong{Across pillars} (using \code{weightings}):
#'       \code{Composite Risk Score = prod(Pillar Score ^ Pillar Weight)},
#'       a weighted geometric mean implementing the multiplicative risk
#'       formula \code{Risk = Exposure * Vulnerability * Lack of Coping
#'       Capacity}. A pillar score close to its minimum pulls the composite
#'       score sharply down rather than being averaged away by strong
#'       scores in the other pillars. Using the geometric mean (rather
#'       than a raw product) keeps the composite on the same scale as the
#'       pillar scores (e.g. 1-5), within the range of the indicator
#'       scores, which the maps' and tables' shared colour scale uses.
#'   }
#'   Both levels align weights to their pillar/indicator by \strong{name},
#'   not by position, so callers do not need to match the row/column order
#'   of any particular sheet or UI element.
#'
#' @author Finlay Campbell
#'
#' @param groupings Named list of named numeric vectors grouping the different
#'   scores into pillars and indicating their relative weighting within-pillar,
#'   as returned by \code{read_data}.
#'
#' @param scores data.frame of risk scores for each geographic region, as
#'   returned by \code{read_data}.
#'
#' @param weightings Numeric vector of the same length as \code{groupings}
#'   indicating the relative weightings of the different pillars. If named,
#'   the names must match \code{names(groupings)} and are used to align the
#'   two (since \code{groupings} is reordered alphabetically by \code{split}
#'   and need not match the order \code{weightings} was supplied in).
#'
get_risks <- function(
  groupings,
  scores,
  weightings = rep(1 / length(groupings), length(groupings))
) {
  if (!is.null(names(weightings))) {
    stopifnot(setequal(names(weightings), names(groupings)))
    weightings <- weightings[names(groupings)]
  }

  weightings <- weightings / sum(weightings)

  tibble(
    scores[, 1],
    map_dfc(
      groupings,
      \(grouping) {
        score <- scores[, names(grouping)]
        weightings <- map2_dfc(
          score,
          grouping,
          ~ as.numeric(!is.na(.x)) * .y
        ) %>%
          as.matrix() %>%
          apply(1, \(x) x / sum(x)) %>%
          t()
        if (length(grouping) == 1) {
          weightings <- t(weightings)
        }
        apply(
          as.matrix(score) * weightings,
          1,
          \(x) if (all(is.na(x))) return(NA) else return(sum(x, na.rm = TRUE))
        )
      }
    )
  ) %>%
    mutate(
      `Composite Risk Score` = apply(select(., -1), 1, \(x) {
        # TODO(multiplicative-score): the formula is documented as
        # Exposure * Vulnerability * LACK of Coping Capacity, but the
        # Coping Capacity pillar score is used as-is (higher = higher
        # risk). Decide whether to invert it (e.g. 6 - score on a 1-5
        # scale) or whether analysts already score it as lack of capacity,
        # and then make the code, workbook and README say the same thing.
        #
        # TODO(multiplicative-score): edge cases. A pillar score of 0 gives a
        # composite of 0, and a negative one gives NaN (non-integer power).
        # Nothing in read_data() currently enforces scores >= 1, so decide
        # whether to validate on upload or guard here. A pillar weight of 0
        # is fine (x^0 = 1) but should be covered by a test.
        prod(x ^ weightings)
      })
    )
}
