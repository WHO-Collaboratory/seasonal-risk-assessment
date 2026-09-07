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
      "Original error: ", conditionMessage(e),
      call. = FALSE
    )
  }
)

rsconnect::setAccountInfo(
  name = Sys.getenv("USERNAME"),
  token = Sys.getenv("TOKEN"),
  secret = Sys.getenv("SECRET")
)

rsconnect::deployApp(
  account = Sys.getenv("USERNAME"),
  appName = "riskassess",
  appTitle = "WHO Seasonal Risk Assessment Tool",
  appFiles = c(
    "app.R",
    "R",
    "www"
  )
)
