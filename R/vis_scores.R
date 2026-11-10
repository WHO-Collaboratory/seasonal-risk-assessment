# Copyright 2026 World Health Organization
# SPDX-License-Identifier: Apache-2.0

#' Diagonal "ILLUSTRATIVE EXAMPLE" watermark, sized to the plot panel.
#'
#' A grid grob whose text size is worked out when it is drawn, as a share of
#' the panel's width, so it looks the same on the small grid maps, the
#' enlarged map and the 8 x 6 inch PNG downloads.
illustrative_watermark <- function() {
  grid::gTree(cl = "illustrative_watermark")
}

makeContent.illustrative_watermark <- function(x) {
  panel_w <- grid::convertWidth(grid::unit(1, "npc"), "points", valueOnly = TRUE)
  panel_h <- grid::convertHeight(grid::unit(1, "npc"), "points", valueOnly = TRUE)
  size <- min(panel_w * 0.07, panel_h * 0.11)

  label <- grid::textGrob(
    "ILLUSTRATIVE EXAMPLE",
    rot = 22,
    gp = grid::gpar(
      fontsize = size,
      fontface = "bold",
      col = grDevices::adjustcolor("grey25", alpha.f = 0.28)
    )
  )
  grid::setChildren(x, grid::gList(label))
}
registerS3method(
  "makeContent",
  "illustrative_watermark",
  makeContent.illustrative_watermark,
  envir = asNamespace("grid")
)

#' Visualise scores on a map.
#'
#' @param limits Optional colour-scale limits, c(min, max). \code{NULL}
#'   stretches the palette over this map's own values.
#' @param illustrative If \code{TRUE}, draws a diagonal "ILLUSTRATIVE
#'   EXAMPLE" watermark across the map. The app sets this only for the synthetic
#'   example workbook (see \code{is_illustrative_example()}).
#'
#' @importFrom sf st_centroid
#'
#' @author Finlay Campbell
#'
vis_scores <- function(
  map_sf,
  value,
  value_label = "Risk Score",
  title = NULL,
  region = "HQ",
  date = Sys.Date(),
  limits = NULL,
  illustrative = FALSE
) {
  stopifnot(inherits(map_sf, "sf"))
  stopifnot(value %in% names(map_sf))

  # Fixed on purpose: scores come from the user's workbook, not from WHO.
  disclaimer_labs <- whomapper::who_map_annotate(
    region = region,
    data_source = "User-provided indicator scores and weights, via Seasonal Risk Assessment Tool"
  )[[1]]

  # whomapper's disclaimer text is authored as long unwrapped lines, which
  # overflow past the plot edge and get cut off at typical map widths. Wrap
  # the caption so it stays inside the plot regardless of output size. The
  # legal text has a hard line break mid-sentence, so lines are re-joined
  # into sentences-ending paragraphs before wrapping (wrapping line by line
  # would leave short orphan lines); the data source / production /
  # copyright block keeps its own line breaks.
  wrap_caption <- function(caption, width = 92) {
    blocks <- strsplit(caption, "\n[ \t]*\n")[[1]]
    blocks <- vapply(
      blocks,
      function(block) {
        if (grepl("^Data Source:", block)) {
          return(block)
        }
        lines <- strsplit(block, "\n")[[1]]
        # a new paragraph starts after any line that ends a sentence
        para <- cumsum(c(TRUE, grepl("[.]\\s*$", lines[-length(lines)])))
        paste(
          vapply(
            split(lines, para),
            function(l) paste(strwrap(paste(l, collapse = " "), width), collapse = "\n"),
            character(1)
          ),
          collapse = "\n"
        )
      },
      character(1)
    )
    paste(blocks, collapse = "\n\n")
  }
  disclaimer_labs$caption <- wrap_caption(disclaimer_labs$caption)

  who_map_text_theme <- theme(
    plot.title = element_text(
      color = who_map_col("title"),
      size = 16,
      face = "bold",
      hjust = 0
    ),
    plot.subtitle = element_text(
      color = who_map_col("title"),
      size = 13,
      hjust = 0
    ),
    plot.caption = element_text(
      hjust = 0,
      size = 9,
      lineheight = 1.1
    ),
    legend.position = "bottom",
    legend.title = element_text(size = 12, face = "bold", hjust = 0.5),
    legend.text = element_text(size = 10, face = "bold")
  )

  # Use the shared range when given (the app passes the range of all
  # included indicator scores, so every map uses the same colours); otherwise
  # stretch the palette over this map's own scores.
  lims <- if (is.null(limits)) score_limits(map_sf[[value]]) else limits

  p <- ggplot(map_sf) +
    geom_sf_who_poly(aes(fill = !!sym(value))) +
    scale_fill_gradientn(
      colours = risk_palette(),
      limits = lims,
      breaks = lims,
      # pillar/composite scores are weighted averages of indicator scores, so
      # they sit inside the indicator range; squish guards rounding at the ends
      oob = scales::squish,
      labels = function(x) as.character(round(x, 2)),
      na.value = who_map_col("not_applicable"),
      name = value_label,
      guide = guide_colorbar(
        title.position = "top",
        title.hjust = 0.5,
        barwidth = unit(160, "pt"),
        barheight = unit(12, "pt"),
        frame.colour = "grey30",
        frame.linewidth = 0.4,
        ticks.colour = "grey30",
        ticks.linewidth = 0.4
      )
    ) +
    labs(
      title = title,
      subtitle = paste("As of", format(as.Date(date), "%d %B %Y"))
    ) +
    disclaimer_labs +
    theme_void() +
    who_map_text_theme

  if (isTRUE(illustrative)) {
    # drawn last so it sits on top of the polygons
    p <- p +
      annotation_custom(
        illustrative_watermark(),
        xmin = -Inf, xmax = Inf, ymin = -Inf, ymax = Inf
      )
  }
  p
}
