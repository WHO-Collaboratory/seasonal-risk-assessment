#' Visualise scores on a map.
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
  data_source = "World Health Organization",
  date = Sys.Date()
) {
  stopifnot(inherits(map_sf, "sf"))
  stopifnot(value %in% names(map_sf))

  # WHO GHO design system diverging/alt scale: low (good) = navy, high (bad) = red
  # https://srhdteuwpubsa.z6.web.core.windows.net/gho/data/design-language/design-system/colors/
  risk_palette <- c(
    "#0f2d5b",
    "#53abd0",
    "#d6dae5",
    "#d9777d",
    "#a00016"
  )

  disclaimer_labs <- whomapper::who_map_annotate(
    region = region,
    data_source = data_source
  )[[1]]

  # whomapper's disclaimer text is authored as long unwrapped lines, which
  # overflow past the plot edge and get cut off at typical map widths. Wrap
  # each line so the caption stays inside the plot regardless of output size.
  disclaimer_labs$caption <- paste(
    vapply(
      strsplit(disclaimer_labs$caption, "\n")[[1]],
      function(line) paste(strwrap(line, width = 100), collapse = "\n"),
      character(1)
    ),
    collapse = "\n"
  )

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

  ggplot(map_sf) +
    geom_sf_who_poly(aes(fill = !!sym(value))) +
    scale_fill_gradientn(
      colours = risk_palette,
      limits = c(1, 5),
      breaks = c(1, 5),
      oob = scales::squish,
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
      subtitle = paste("As of", format(as.Date(date), "%d %b %Y"))
    ) +
    disclaimer_labs +
    theme_void() +
    who_map_text_theme
}
