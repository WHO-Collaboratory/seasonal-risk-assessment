# Copyright 2026 World Health Organization
# SPDX-License-Identifier: Apache-2.0

# Upload checks against saved test workbooks.
#
# Each workbook in tests/test-workbooks/ is the EXAMPLE data (Ukraine, 15
# indicators, 11 included) in the slot-keyed template, with one change made
# the way a user would make it, then recalculated and saved in Excel (the app
# reads Excel's cached values, so the files must have been saved by Excel).
#
# Run from the repo root:
#   Rscript -e 'testthat::test_file("tests/test_upload_checks.R")'

library(testthat)
suppressMessages({
  library(dplyr)
  library(purrr)
  library(tibble)
})

# test_file() runs from tests/, Rscript from the repo root
root <- if (file.exists("app.R")) "." else ".."
for (f in c(
  "read_data.R", "validate_indicator_weights.R", "validate_pillar_weights.R",
  "get_risks.R"
)) {
  source(file.path(root, "R", f))
}

wb <- function(name) file.path(root, "tests", "test-workbooks", paste0(name, ".xlsx"))

# Problems raised by read_data() (empty if it succeeds)
data_problems <- function(name) {
  tryCatch(
    {
      read_data(wb(name))
      character()
    },
    workbook_check_error = function(e) e$problems
  )
}

expected <- read_data(wb("base"))$scores

test_that("valid workbooks read, keeping each indicator's own scores", {
  # Structural changes that must NOT shift scores between indicators
  for (name in c(
    "base", "sort_by_pillar", "pillar_change", "exclude_slot2",
    "exclude_slot7", "delete_slot5_cleaned", "blank_included_row"
  )) {
    d <- read_data(wb(name))
    for (ind in names(d$scores)[-1]) {
      expect_equal(d$scores[[ind]], expected[[ind]], info = paste(name, ind))
    }
  }
})

test_that("excluded indicators are left out of scores and weights", {
  d <- read_data(wb("exclude_slot2"))
  ex <- "Extreme Cold Days  (<-10ºC) per Winter Season"
  expect_false(ex %in% names(d$scores))
  w <- read_indicator_weights(wb("exclude_slot2"))
  expect_false(ex %in% w$Indicator)
  # Step 4 rows are keyed by slot, so the excluded slot (row 11) is a gap
  expect_equal(w$sheet_row, c(10, 12:20))
})

test_that("problem workbooks are rejected with a specific message", {
  expect_match(data_problems("delete_slot5"), "whose indicator was deleted")
  # clearing only the leftover weight still leaves the scores behind
  expect_match(
    data_problems("delete_slot5_weight_cleared"),
    "whose indicator was deleted"
  )
  expect_match(data_problems("duplicate_name"), "must be unique")
  expect_match(data_problems("insert_row3"), "inserted into the Step 2")
  expect_match(data_problems("missing_scores"), "have no scores")
  expect_match(data_problems("stray_scores"), "rows with no subnational unit")
})

test_that("missing weights are rejected", {
  d <- read_data(wb("missing_weight"))
  w <- read_indicator_weights(wb("missing_weight"))
  expect_match(
    indicator_weight_problems(w, d$metadata$Indicator),
    "no weight in Step 4: Population Aged 65 and Older"
  )
})

test_that("valid workbooks have consistent weights and score end to end", {
  for (name in c("base", "sort_by_pillar", "exclude_slot2_rebalanced")) {
    d <- read_data(wb(name))
    w <- read_indicator_weights(wb(name))
    expect_length(indicator_weight_problems(w, d$metadata$Indicator), 0)
    expect_true(all(validate_indicator_weights(w)$valid), info = name)
    groupings <- split(w, w$Pillar) |>
      lapply(\(df) setNames(df$`Indicator Weight`, df$Indicator))
    risks <- get_risks(groupings, d$scores)
    expect_equal(nrow(risks), 28)
    expect_false(anyNA(risks$`Composite Risk Score`), info = name)
  }
})

# TODO(multiplicative-score): the test above only checks that get_risks()
# returns no NAs. Add focused unit tests for the weighted geometric mean:
# a hand-computed composite, equal pillars equalling their common score, a
# pillar weight of 0 being ignored, an entirely blank pillar giving NA, and
# the composite staying within the range of the indicator scores.

test_that("workbooks from the old (pre-slot) template still read", {
  # copy of the EXAMPLE as it was before the slot redesign
  d <- read_data(wb("old_layout_example"))
  expect_equal(ncol(d$scores) - 1, 11)
  expect_equal(nrow(d$scores), 28)
})

test_that("the licence footer is not mistaken for a subnational unit", {
  expect_equal(
    is_licence_line(c(
      "Kharkivska",
      NA,
      "\u00a9 WHO 2026. Some rights reserved. This work is available under the CC BY-NC-SA 3.0 IGO licence.",
      "(c) WHO 2030. SOME RIGHTS RESERVED."
    )),
    c(FALSE, FALSE, TRUE, TRUE)
  )
  # the EXAMPLE workbook carries the footer in Step 3
  d <- read_data(file.path(root, "workbook", "Seasonal Risk Assessment Tool (EXAMPLE).xlsx"))
  expect_false(any(is_licence_line(d$scores$`Subnational Level`)))
  expect_equal(nrow(d$scores), 28)
})

# Issue 3: Step 4 weights (blank = error, +/-0.15 points, every pillar needs
# an indicator; the "unequal weights need a rationale" note is sheet-only)
weight_problems <- function(name) {
  d <- read_data(wb(name))
  indicator_weight_problems(
    read_indicator_weights(wb(name)),
    included = d$metadata$Indicator,
    pillars = read_pillar_weights(wb(name))
  )
}

test_that("blank weights are rejected even when the rest add to 100%", {
  expect_match(
    weight_problems("blank_weight_others_100"),
    "no weight in Step 4: Internally Displaced Population"
  )
  expect_match(
    weight_problems("pillar_weight_blank"),
    "Pillar weights are missing in Step 4 for: Coping Capacity"
  )
})

test_that("a pillar with no included indicators is rejected", {
  expect_match(
    weight_problems("empty_pillar"),
    "None for: Coping Capacity"
  )
})

test_that("thirds typed as 33.3% pass, and unequal weights alone don't block", {
  for (name in c("thirds_33_3", "unequal_no_rationale")) {
    expect_length(weight_problems(name), 0)
    expect_true(
      all(validate_indicator_weights(read_indicator_weights(wb(name)))$valid),
      info = name
    )
    expect_true(
      validate_pillar_weights(read_pillar_weights(wb(name)))$valid,
      info = name
    )
  }
})

test_that("the unfilled template is recognised as blank, and nothing else is", {
  expect_true(workbook_is_blank(wb("blank_template")))
  # read on its own, the blank template must not report phantom scores
  expect_false(any(grepl("no subnational unit", data_problems("blank_template"))))
  for (name in c(
    "base", "missing_scores", "missing_weight", "pillar_weight_blank",
    "empty_pillar", "old_layout_example"
  )) {
    expect_false(workbook_is_blank(wb(name)), info = name)
  }
})
