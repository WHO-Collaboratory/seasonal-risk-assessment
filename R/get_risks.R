#' Calculate risks from groupings, scores and overall weightings
#'
#' @details Scoring is a two-level weighted sum:
#'   \code{Pillar Score = sum(Indicator Weight * Indicator Score)} within
#'   each pillar (using \code{groupings}), then
#'   \code{Composite Risk Score = sum(Pillar Weight * Pillar Score)} across
#'   pillars (using \code{weightings}). Both levels align weights to their
#'   pillar/indicator by \strong{name}, not by position, so callers do not
#'   need to match the row/column order of any particular sheet or UI
#'   element.
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
        sum(x * weightings)
      })
    )
}
