#' Aggregate ICD codes by hierarchy level
#'
#' Counts ICD codes grouped by a specified hierarchy level (chapter, category,
#' or subcategory). Optionally filters to codes within a parent group.
#'
#' @param data Enriched ICD data frame (from enrich_icd_data)
#' @param level Character: "chapter", "category", or "subcategory"
#' @param parent_filter Optional character: filter to codes within this parent
#'   (e.g., chapter "01" when level = "category")
#' @return data.frame with columns: group, count, and parent columns if filtered
#' @export
aggregate_by_hierarchy <- function(data, level = "chapter", parent_filter = NULL) {
  if (nrow(data) == 0) {
    return(data.frame(group = character(0), count = integer(0)))
  }

  # Determine parent level for filtering
  parent_level <- switch(
    level,
    "chapter" = NULL,
    "category" = "chapter",
    "subcategory" = "category"
  )

  # Apply parent filter if provided
  if (!is.null(parent_filter) && !is.null(parent_level)) {
    data <- data[data[[parent_level]] == parent_filter, , drop = FALSE]
  }

  # Aggregate counts
  counts <- as.data.frame(table(data[[level]]), stringsAsFactors = FALSE)
  names(counts) <- c("group", "count")

  # Remove NA groups
  counts <- counts[!is.na(counts$group) & counts$group != "", , drop = FALSE]

  counts
}
