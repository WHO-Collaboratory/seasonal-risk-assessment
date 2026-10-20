# Copyright 2026 World Health Organization
# SPDX-License-Identifier: Apache-2.0

validate_pillar_weights <- function(df, tol = 1.5e-3) {
  stopifnot(all(c("Pillar", "Pillar Weight") %in% names(df)))

  total <- sum(df$`Pillar Weight`, na.rm = TRUE)
  off_by <- total - 1

  list(
    valid = abs(off_by) < tol,
    total = total,
    off_by = off_by
  )
}

#' Read Step 4A (pillar weights) from an uploaded workbook.
#'
#' Locates the "Pillar" header and "TOTAL" rows dynamically rather than
#' assuming fixed row numbers, since editing the Instructions text above the
#' table shifts it down and previously broke a hardcoded range. A blank pillar
#' weight is returned as \code{NA} (see \code{indicator_weight_problems()}).
#'
#' @param path Path to the workbook.
read_pillar_weights <- function(path) {
  raw <- readxl::read_excel(
    path,
    sheet = "4. Define Weights",
    range = "B7:C15", # wide enough to cover Step 4A regardless of its exact row
    col_names = FALSE
  )

  header_row <- which(raw[[1]] == "Pillar")[1]
  if (is.na(header_row)) {
    stop("Could not find the 'Pillar' header in Step 4A's table.")
  }

  # Data rows run from just below the header down to (but not including) the
  # "TOTAL" row.
  total_row <- which(raw[[1]] == "TOTAL")[1]
  if (is.na(total_row) || total_row <= header_row) {
    stop("Could not find the 'TOTAL' row in Step 4A's table.")
  }

  raw |>
    rlang::set_names(unlist(raw[header_row, ])) |>
    dplyr::slice((header_row + 1):(total_row - 1)) |>
    dplyr::mutate(`Pillar Weight` = as.numeric(`Pillar Weight`)) |>
    as.data.frame()
}
