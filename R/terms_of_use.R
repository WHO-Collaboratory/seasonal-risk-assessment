# Copyright 2026 World Health Organization
# SPDX-License-Identifier: Apache-2.0

# Terms of Use shown in the app. Keep in step with the "Terms of use" and
# "License" sections of README.md: the README is the longer reference, this is
# the version users see before they upload anything.

repo_url <- "https://github.com/WHO-Collaboratory/seasonal-risk-assessment"
terms_last_updated <- "20 October 2026"

terms_section <- function(title, ...) {
  tagList(tags$h5(title, class = "terms-heading"), ...)
}

terms_of_use_ui <- function() {
  tagList(
    tags$p(
      class = "text-muted small",
      tags$em(paste("Last updated:", terms_last_updated))
    ),

    tags$p(
      class = "text-muted small",
      "Please read these terms before using the app. By selecting ",
      "\"I accept\", you agree to them. They summarize the full terms of use ",
      "in the ",
      tags$a(
        href = paste0(repo_url, "#terms-of-use"),
        target = "_blank",
        "README"
      ),
      " of the GitHub repository, which also contains the full license ",
      "texts."
    ),

    terms_section(
      "1. Scope",
      tags$p(
        "This tool turns indicator scores and weights that you enter in the ",
        "Excel workbook into risk scores, tables and maps. WHO does not ",
        "supply, review or verify those scores, weights or indicator ",
        "definitions, and every result depends entirely on what you entered. ",
        "You are responsible for how you interpret and use the analyses and ",
        "outputs you produce."
      )
    ),

    terms_section(
      "2. No WHO endorsement; use of WHO name and emblem",
      tags$p(
        "Results produced with this tool are your own. They are not WHO's ",
        "products, opinions or statements. You must not state or imply that ",
        "WHO endorses or is affiliated with you, your use of the tool, any ",
        "results, or any entity, organization, company or product."
      ),
      tags$p(
        "The name and emblem of the World Health Organization are not ",
        "licensed. Any use needs prior written approval from WHO. If you ",
        "adapt the tool or the workbook, remove the WHO emblem. See WHO's ",
        tags$a(
          href = "https://www.who.int/about/policies/publishing/copyright",
          target = "_blank",
          "copyright"
        ),
        " and ",
        tags$a(
          href = "https://www.who.int/about/policies/publishing/logo",
          target = "_blank",
          "logo"
        ),
        " policies."
      )
    ),

    terms_section(
      "3. Data processing",
      tags$p(
        "Only upload data you are allowed to share with this service. The ",
        "workbook should hold aggregated scores for subnational areas. ",
        "Do not enter personal data about individuals. Check whether your",
        " indicator data are confidential or politically sensitive before ",
        "you upload them."
      ),
      tags$p(tags$strong("How the app handles your workbook")),
      tags$ol(
        tags$li(
          tags$strong("Upload. "),
          "Your workbook is sent to the app server and saved in a temporary ",
          "folder created for your session. The app reads it from there into ",
          "the server's memory to calculate your tables and maps."
        ),
        tags$li(
          tags$strong("During your session. "),
          "The app does not write your data to a database or other permanent ",
          "storage. Weight changes stay in ",
          "your session unless you download the updated workbook. When you ",
          "download a workbook or maps, the app builds the file in a ",
          "temporary folder and deletes that folder once the file has been ",
          "sent."
        ),
        tags$li(
          tags$strong("When the session ends. "),
          "A session ends when you close the tab or reload the page, or ",
          "after a period without activity. The server then deletes your ",
          "uploaded workbook and the session's temporary folders, and ",
          "releases your session's data from memory. After a reload, you ",
          "will need to upload the workbook again."
        )
      ),
      tags$p(
        class = "small text-muted",
        "Files are deleted in the standard way and are not securely erased from the server's disk. The ",
        "app is hosted on shinyapps.io, owned and operated by Posit, on servers that may be ",
        "outside your country. Posit may keep technical logs, such as IP ",
        "addresses, under its own terms."
      )
    ),

    terms_section(
      "4. Maps",
      tags$p(
        "The boundaries and names shown and the designations used on the ",
        "maps in the app and in its downloadable map images do not imply the ",
        "expression of any opinion whatsoever on the part of WHO concerning ",
        "the legal status of any country, territory, city or area or of its ",
        "authorities, or concerning the delimitation of its frontiers or ",
        "boundaries. Dotted and dashed lines on maps represent approximate ",
        "border lines for which there may not yet be full agreement."
      ),
      tags$p(
        "Boundaries come from the WHO boundary service and may differ from ",
        "those used by national authorities. Downloaded maps carry WHO's map ",
        "disclaimer in their caption. Keep it with the map if you share it. ",
        "In this app, \"country\" is shorthand for a country, area or ",
        "territory."
      )
    ),

    terms_section(
      "5. Licenses",
      tags$ul(
        tags$li(
          tags$strong("Source code: "),
          "Apache License 2.0, copyright World Health Organization 2026."
        ),
        tags$li(
          tags$strong("Excel workbook and its embedded guidance: "),
          tags$a(
            href = "https://creativecommons.org/licenses/by-nc-sa/3.0/igo/",
            target = "_blank",
            "CC BY-NC-SA 3.0 IGO"
          ),
          ". This is a non-commercial, share-alike license, and it also ",
          "applies to the copy you get from \"Download workbook\". Filling in ",
          "the workbook with your own data and running the app as provided ",
          "needs no attribution or other license action. If you adapt the ",
          "workbook and share the adaptation, release it under the same or ",
          "an equivalent license and include this statement: \"This ",
          "adaptation was not created by WHO. WHO is not responsible for the ",
          "content or accuracy of this adaptation. The original edition ",
          "shall be the binding and authentic edition.\""
        ),
        tags$li(
          tags$strong("Third-party software: "),
          "the app uses open source R packages under their authors' own ",
          "licenses. Their use does not mean WHO endorses or recommends them."
        )
      )
    ),

    terms_section(
      "6. No warranty and no liability",
      tags$p(
        "The tool is provided \"as is\", without warranty of any kind. ",
        "In no event shall WHO be liable for damages arising ",
        "from the use of the tool or its outputs. WHO may update, change or ",
        "withdraw the tool or these terms at any time without notice, and ",
        "the app may be unavailable at times."
      )
    ),

    terms_section(
      "7. Privileges and immunities",
      tags$p(
        "Nothing in these terms or in any license for this tool (including ",
        "the Apache License, Version 2.0, and the CC BY-NC-SA 3.0 IGO ",
        "license) is a waiver of any of the privileges and immunities ",
        "enjoyed by the World Health Organization under national or ",
        "international law, or submits WHO to any national jurisdiction."
      )
    ),

    terms_section(
      "8. Contact",
      tags$p(
        "Questions or problems: ",
        tags$a(
          href = paste0(repo_url, "/issues"),
          target = "_blank",
          "open an issue"
        ),
        " or write to collaboratory@who.int."
      )
    )
  )
}
