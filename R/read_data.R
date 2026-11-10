# Copyright 2026 World Health Organization
# SPDX-License-Identifier: Apache-2.0

#' Strip the workbook's "changes the results" marker from header labels.
#'
#' Headers in "2. Define Indicators" that affect the results are marked with a
#' trailing asterisk (e.g. "Pillar*"). Removing it keeps column names stable
#' for the code below.
clean_header <- function(x) {
  sub("\\s*\\*+$", "", trimws(x))
}

#' Number of rows to skip so that a sheet's header row is read as column names.
#'
#' Finds the first row containing all of \code{markers}, so instruction text
#' above a table can grow or shrink (rows inserted/removed) without breaking
#' the read. The probe uses an explicit row range so readxl keeps leading empty
#' rows, making the row index match the sheet's own row numbers.
#'
#' @param path Path to the workbook.
#' @param sheet Sheet name.
#' @param markers Header labels that must all appear in the header row.
#'   Matched after \code{clean_header()}, so marked headers such as
#'   "Pillar*" still match "Pillar".
#' @param n_max Number of rows to search.
header_skip <- function(path, sheet, markers, n_max = 100) {
  probe <- suppressMessages(readxl::read_excel(
    path,
    sheet = sheet,
    col_names = FALSE,
    col_types = "text",
    range = cellranger::cell_rows(c(1, n_max)),
    .name_repair = "minimal"
  ))
  hit <- which(apply(probe, 1, function(row) {
    all(markers %in% clean_header(row))
  }))
  if (length(hit) == 0) {
    stop(
      "Could not find the header row (",
      paste(markers, collapse = ", "),
      ") in sheet '", sheet, "'."
    )
  }
  hit[1] - 1
}

#' Flag the licence footer line the workbook carries under its tables.
#'
#' Step 3 ends with a line such as "(c) WHO 2026. Some rights reserved. ..."
#' in the Subnational Level column. It is text in an area column, so it would
#' otherwise be read as a subnational unit with no scores. Matched on
#' "rights reserved" (case-insensitive) so the year and licence wording can
#' change without breaking the read.
#'
#' @param x Character vector of Subnational Level cells.
is_licence_line <- function(x) {
  !is.na(x) & grepl("rights reserved", x, ignore.case = TRUE)
}

#' Signal that an uploaded workbook can't be used as-is.
#'
#' Raises a condition of class \code{workbook_check_error} whose message lists
#' every problem found, so the user can fix them all in one pass. The app shows
#' \code{e$problems} as a bulleted list instead of a generic "couldn't read"
#' notice.
#'
#' @param problems Character vector, one plain-language problem per element.
workbook_check_error <- function(problems) {
  stop(errorCondition(
    paste(
      c(
        "This workbook can't be used until these problems are fixed:",
        paste0("- ", problems)
      ),
      collapse = "\n"
    ),
    problems = problems,
    class = "workbook_check_error"
  ))
}

#' Is the uploaded workbook the unfilled template?
#'
#' TRUE when none of the cells a user is expected to fill contain anything:
#' no country in Step 1, no indicator names in Step 2, no scores in Step 3
#' and no pillar or indicator weights in Step 4. The app then shows a single
#' "this looks like the blank template" message instead of a list of
#' problems that all stem from the workbook being empty.
#'
#' Uses \code{read_pillar_weights()} and \code{read_indicator_weights()}
#' (R/validate_pillar_weights.R, R/validate_indicator_weights.R).
#'
#' @param path Path to the workbook.
workbook_is_blank <- function(path) {
  filled <- function(x) any(!is.na(x) & trimws(as.character(x)) != "")

  country <- readxl::read_excel(
    path,
    sheet = "1. Describe Your Emergency",
    range = "D6",
    col_names = FALSE,
    col_types = "text"
  )
  if (filled(unlist(country))) {
    return(FALSE)
  }

  indicators <- readxl::read_excel(
    path,
    sheet = "2. Define Indicators",
    skip = header_skip(
      path,
      "2. Define Indicators",
      c("Indicator ID", "Indicator", "Pillar", "Include")
    ),
    # the table's 30 rows (+1 in case a row was inserted), so the copyright
    # line below the table isn't mistaken for an indicator name
    n_max = 31,
    col_types = "text"
  ) |>
    dplyr::rename_with(clean_header)
  if (filled(indicators$Indicator)) {
    return(FALSE)
  }

  area_cols <- c("Country / Territory", "Subnational Level")
  scores <- readxl::read_excel(
    path,
    sheet = "3. Enter Indicator Scores",
    skip = header_skip(path, "3. Enter Indicator Scores", area_cols),
    col_types = "text",
    .name_repair = "minimal"
  )
  # numbers only: the row under the names holds formula-generated IDs
  score_cells <- unlist(scores[, !trimws(names(scores)) %in% area_cols])
  if (any(!is.na(suppressWarnings(as.numeric(score_cells))))) {
    return(FALSE)
  }

  !filled(read_pillar_weights(path)$`Pillar Weight`) &&
    !filled(read_indicator_weights(path)$`Indicator Weight`)
}

#' Is the uploaded workbook the synthetic Ukraine example?
#'
#' The example workbook that ships with the tool labels itself: its Step 1
#' description starts with "ILLUSTRATIVE EXAMPLE". The app uses this to put an
#' "ILLUSTRATIVE" watermark on the maps made from it (and only from it). A
#' user who writes their own description in Step 1 gets clean maps. Matched on
#' the start of the text, case-insensitively, so the rest of the wording can
#' change. Any problem reading the cell counts as "not the example", so this
#' can never stop a real workbook from loading.
#'
#' @param path Path to the workbook.
is_illustrative_example <- function(path) {
  tryCatch(
    {
      step1 <- suppressMessages(readxl::read_excel(
        path,
        sheet = "1. Describe Your Emergency",
        range = "C1:D30",
        col_names = FALSE,
        col_types = "text"
      ))
      label <- grepl("Description of Acute Emergency", step1[[1]], fixed = TRUE)
      if (!any(label)) {
        return(FALSE)
      }
      description <- step1[[2]][which(label)[1]]
      !is.na(description) &&
        grepl("^\\s*ILLUSTRATIVE EXAMPLE", description, ignore.case = TRUE)
    },
    error = function(e) FALSE
  )
}

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
#'   Step 3 has one score column per Step 2 row ("slot"), so it also holds
#'   columns for excluded and unused rows. Only included indicators are
#'   returned. Rather than silently dropping or renaming data, the function
#'   stops with a \code{workbook_check_error} (see
#'   \code{workbook_check_error()}) listing every problem when: indicator names
#'   are duplicated; an included indicator has no scores or sits in a row
#'   inserted into the Step 2 table (so has no score column); a score is not a
#'   non-negative number; or scores were left in a column with no indicator or
#'   a row with no subnational unit.
#'
#' @importFrom readxl read_excel
#'
#' @author Finlay Campbell
#'

read_data <- function(path) {
  scores_sheet <- "3. Enter Indicator Scores"
  area_cols <- c("Country / Territory", "Subnational Level")
  problems <- character()

  # --- Step 3 scores ---
  # Read everything as text with minimal name repair: a score column whose
  # Step 2 row was deleted or cleared then keeps a blank header (instead of
  # readxl's "...12"), and a stray text entry can be reported, not coerced
  # to NA.
  raw_scores <- readxl::read_excel(
    path,
    sheet = scores_sheet,
    # skip to row containing indicator name
    skip = header_skip(path, scores_sheet, area_cols),
    col_types = "text",
    .name_repair = "minimal"
  )
  headers <- trimws(names(raw_scores))
  headers[is.na(headers)] <- ""
  names(raw_scores) <- headers
  score_idx <- which(!headers %in% area_cols)

  no_area <- (is.na(raw_scores[[area_cols[1]]]) &
    is.na(raw_scores[[area_cols[2]]])) |
    is_licence_line(raw_scores[[area_cols[2]]])
  # The hidden Indicator ID row sits directly under the names (any ID format,
  # so workbooks from older templates still read)
  id_row <- no_area & seq_len(nrow(raw_scores)) == 1
  has_values <- apply(
    raw_scores[, score_idx, drop = FALSE],
    1,
    \(x) any(!is.na(x) & trimws(x) != "")
  )
  stray <- no_area & !id_row & has_values
  if (any(stray)) {
    problems <- c(
      problems,
      paste(
        "Step 3 has scores in rows with no subnational unit (highlighted",
        "red), often because the country in Step 1 was changed. Delete",
        "them, or change the country back."
      )
    )
  }
  indicator_data <- raw_scores[!no_area, , drop = FALSE]

  has_data <- vapply(
    score_idx,
    \(j) any(!is.na(indicator_data[[j]]) & indicator_data[[j]] != ""),
    logical(1)
  )
  if (any(headers[score_idx] == "" & has_data)) {
    problems <- c(
      problems,
      paste(
        "Step 3 has scores in a column whose indicator was deleted (marked",
        "'Indicator deleted'). Its row in Step 2 was deleted or cleared: undo",
        "that, or delete those scores."
      )
    )
  }

  # --- Step 2 indicator definitions ---
  indicator_meta <- readxl::read_excel(
    path,
    sheet = "2. Define Indicators",
    # skip to row containing column names
    skip = header_skip(
      path,
      "2. Define Indicators",
      c("Indicator ID", "Indicator", "Pillar", "Include")
    )
  ) |>
    dplyr::rename_with(clean_header) |>
    dplyr::mutate(
      Indicator = trimws(Indicator),
      Include = as.logical(Include)
    ) |>
    # rows without a name are ignored by every sheet in the workbook
    dplyr::filter(!is.na(Indicator), Indicator != "")

  # Excel treats names as case-insensitive, so "Snow depth" and "Snow Depth"
  # collide in its lookups even though R would tell them apart.
  dup_names <- unique(indicator_meta$Indicator[
    duplicated(tolower(indicator_meta$Indicator))
  ])
  if (length(dup_names) > 0) {
    problems <- c(
      problems,
      paste0(
        "Indicator names in Step 2 must be unique. Used more than once: ",
        paste(dup_names, collapse = "; "),
        "."
      )
    )
  }

  meta_clean <- indicator_meta |>
    dplyr::filter(Include %in% TRUE)

  if (nrow(meta_clean) == 0) {
    problems <- c(
      problems,
      "No indicators are marked Include = TRUE in Step 2."
    )
  }

  # A row inserted into the Step 2 table has no hidden slot number, so no
  # Indicator ID and no score column in Step 3.
  inserted <- meta_clean$Indicator[
    is.na(meta_clean$`Indicator ID`) | meta_clean$`Indicator ID` == ""
  ]
  if (length(inserted) > 0) {
    problems <- c(
      problems,
      paste0(
        "These indicators are in rows that were inserted into the Step 2 ",
        "table, so they have no score column in Step 3: ",
        paste(inserted, collapse = "; "),
        ". Undo the insert, and type new indicators into an empty row at the ",
        "bottom of the table instead."
      )
    )
  }

  # --- Check each included indicator's scores ---
  scores <- tibble::tibble(
    `Subnational Level` = indicator_data$`Subnational Level`
  )
  no_scores <- non_numeric <- negative <- character()
  for (ind in setdiff(meta_clean$Indicator, c(dup_names, inserted))) {
    j <- which(headers == ind)
    if (length(j) == 0) {
      no_scores <- c(no_scores, ind)
      next
    }
    raw <- indicator_data[[j[1]]]
    num <- suppressWarnings(as.numeric(raw))
    entered <- !is.na(raw) & trimws(raw) != ""
    if (!any(entered)) {
      no_scores <- c(no_scores, ind)
    }
    if (any(entered & is.na(num))) {
      non_numeric <- c(non_numeric, ind)
    }
    if (any(num < 0, na.rm = TRUE)) {
      negative <- c(negative, ind)
    }
    scores[[ind]] <- num
  }
  if (length(no_scores) > 0) {
    problems <- c(
      problems,
      paste0(
        "These indicators are included in Step 2 but have no scores in ",
        "Step 3: ",
        paste(no_scores, collapse = "; "),
        ". Enter scores, or set Include to FALSE."
      )
    )
  }
  if (length(non_numeric) > 0) {
    problems <- c(
      problems,
      paste0(
        "Step 3 has entries that aren't numbers for: ",
        paste(non_numeric, collapse = "; "),
        "."
      )
    )
  }
  if (length(negative) > 0) {
    problems <- c(
      problems,
      paste0(
        "Step 3 has negative scores for: ",
        paste(negative, collapse = "; "),
        ". Scores must be zero or above."
      )
    )
  }

  if (length(problems) > 0) {
    workbook_check_error(problems)
  }

  # --- Build groupings: pillar → vector of equal-weight indicators ---
  groupings <- meta_clean %>%
    split(.$Pillar) %>% # split into Exposure / Vulnerability / Coping Capacity
    lapply(function(df) {
      n <- nrow(df)
      w <- rep(1 / n, n) # equal weights for each indicator
      names(w) <- df$Indicator
      w
    })

  return(list(
    scores = scores,
    groupings = groupings,
    metadata = meta_clean
  ))
}
