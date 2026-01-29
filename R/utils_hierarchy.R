#' Parse hierarchy string into components
#'
#' Splits a hierarchy string (e.g., "01.02.03") into chapter, category,
#' and subcategory components.
#'
#' @param hiera Character vector of hierarchy strings (e.g., "01.02.03")
#' @return data.frame with columns: chapter, category, subcategory
#' @export
#' @examples
#' parse_hierarchy("01.02.03")
#' parse_hierarchy(c("01.02", "03.04.05"))
parse_hierarchy <- function(hiera) {
  parts <- strsplit(hiera, "\\.")
  data.frame(
    chapter = vapply(parts, `[`, character(1), 1),
    category = vapply(
      parts,
      function(x) if (length(x) >= 2) x[2] else NA_character_,
      character(1)
    ),
    subcategory = vapply(
      parts,
      function(x) if (length(x) >= 3) x[3] else NA_character_,
      character(1)
    ),
    stringsAsFactors = FALSE
  )
}

#' Enrich ICD data with parsed hierarchy columns
#'
#' Adds chapter, category, and subcategory columns to ICD data by
#' parsing the hiera column.
#'
#' @param data ICD data frame (from get_icd_data)
#' @return data.frame with added chapter, category, subcategory columns
#' @export
enrich_icd_data <- function(data) {
  parsed <- parse_hierarchy(data$hiera)
  cbind(data, parsed)
}
