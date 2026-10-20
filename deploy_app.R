# Copyright 2026 World Health Organization
# SPDX-License-Identifier: Apache-2.0

tryCatch(
  {
    remotes::install_github("whocov/whomapper", force = TRUE, upgrade = "never")
    library(whomapper)
  },
  error = function(e) {
    stop(
      "Failed to install/load the latest 'whomapper' package from ",
      "https://github.com/whocov/whomapper -- deploy aborted.\n",
      "Investigate the whomapper repo (e.g. a recent commit may have broken ",
      "the package) before redeploying.\n\n",
      "Original error: ",
      conditionMessage(e),
      call. = FALSE
    )
  }
)

rsconnect::setAccountInfo(
  name = Sys.getenv("USERNAME"),
  token = Sys.getenv("TOKEN"),
  secret = Sys.getenv("SECRET")
)

# List files explicitly: rsconnect copies whole directories (including
# .DS_Store and www/archive/) and has no ignore file.
app_files <- c(
  "app.R",
  list.files("R", pattern = "\\.R$", full.names = TRUE),
  list.files("www", pattern = "\\.png$", full.names = TRUE),
  "workbook/Seasonal Risk Assessment Tool.xlsx"
)

rsconnect::deployApp(
  account = Sys.getenv("USERNAME"),
  appName = "seasonal-risk-assessment",
  appTitle = "Seasonal Risk Assessment Tool",
  appFiles = app_files
)
