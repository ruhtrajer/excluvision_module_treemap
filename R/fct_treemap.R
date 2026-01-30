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

#' Prepare data for treemap visualization
#'
#' Aggregates ICD codes by hierarchy level and adds human-readable labels
#' from the hierarchy lookup table.
#'
#' @param data Enriched ICD data frame (from enrich_icd_data)
#' @param level Character: "chapter", "category", or "subcategory"
#' @param parent_filter Optional character: filter to codes within this parent
#' @return data.frame ready for treemap with columns: group, count, label
#' @export
prepare_treemap_data <- function(data, level = "chapter", parent_filter = NULL) {
  if (nrow(data) == 0) {
    return(data.frame(
      group = character(0),
      count = integer(0),
      label = character(0),
      stringsAsFactors = FALSE
    ))
  }

  # Get aggregated counts
  agg <- aggregate_by_hierarchy(data, level = level, parent_filter = parent_filter)

  if (nrow(agg) == 0) {
    return(data.frame(
      group = character(0),
      count = integer(0),
      label = character(0),
      stringsAsFactors = FALSE
    ))
  }

  # Load hierarchy lookup for labels
  hiera_lookup <- get_hierarchy_lookup()

  # Build hierarchy code to match lookup format
  # For chapter level: "01", for category: "01.02", etc.
  if (level == "chapter") {
    agg$hiera_code <- agg$group
  } else if (level == "category") {
    if (!is.null(parent_filter)) {
      agg$hiera_code <- paste(parent_filter, agg$group, sep = ".")
    } else {
      # Need parent info from data - this case is less common
      agg$hiera_code <- agg$group
    }
  } else {
    agg$hiera_code <- agg$group
  }

  # Match labels from lookup
  label_idx <- match(agg$hiera_code, hiera_lookup$hiera)
  agg$label <- ifelse(
    is.na(label_idx),
    agg$group,
    hiera_lookup$lib[label_idx]
  )

  # Clean up and return
  agg$hiera_code <- NULL
  agg
}

#' Render a treemap visualization
#'
#' Creates a treemap visualization from prepared treemap data.
#' Uses the treemap package for rendering.
#'
#' @param data Prepared treemap data (from prepare_treemap_data)
#' @param title Optional title for the treemap
#' @return treemap object (invisibly), or NULL if data is empty
#' @export
render_treemap <- function(data, title = "ICD-10 Codes Distribution") {
  if (nrow(data) == 0) {
    return(NULL)
  }

  treemap::treemap(
    data,
    index = "label",
    vSize = "count",
    title = title,
    fontsize.labels = 12,
    fontcolor.labels = "white",
    fontface.labels = "bold",
    bg.labels = 0,
    border.col = "white",
    border.lwds = 2,
    palette = "Set3",
    aspRatio = 1.5
  )
}

#' Build hierarchical data structure for D3.js treemap
#'
#' Converts flat ICD data into a nested hierarchy suitable for D3.js
#' treemap visualization. Structure: root -> chapters -> categories -> subcategories.
#'
#' @param data Enriched ICD data frame (from enrich_icd_data)
#' @return Nested list with name, children, and value fields for D3.js
#' @export
build_treemap_hierarchy <- function(data) {
  if (nrow(data) == 0) {
    return(list(name = "root", children = list()))
  }

  # Load hierarchy lookup for labels
  hiera_lookup <- get_hierarchy_lookup()

  # Helper to get label from lookup
  get_label <- function(hiera_code) {
    idx <- match(hiera_code, hiera_lookup$hiera)
    if (is.na(idx)) return(hiera_code)
    hiera_lookup$lib[idx]
  }

  # Build nested structure
  chapters <- unique(data$chapter)
  chapters <- chapters[!is.na(chapters)]

  children <- lapply(chapters, function(ch) {
    ch_data <- data[data$chapter == ch, , drop = FALSE]
    ch_label <- get_label(ch)

    # Get categories within this chapter
    categories <- unique(ch_data$category)
    categories <- categories[!is.na(categories)]

    if (length(categories) == 0) {
      # Leaf node - just codes
      return(list(
        name = ch_label,
        id = ch,
        value = nrow(ch_data)
      ))
    }

    cat_children <- lapply(categories, function(cat) {
      cat_data <- ch_data[ch_data$category == cat, , drop = FALSE]
      cat_hiera <- paste(ch, cat, sep = ".")
      cat_label <- get_label(cat_hiera)

      # Get subcategories within this category
      subcats <- unique(cat_data$subcategory)
      subcats <- subcats[!is.na(subcats)]

      if (length(subcats) == 0) {
        # Leaf node
        return(list(
          name = cat_label,
          id = cat_hiera,
          value = nrow(cat_data)
        ))
      }

      subcat_children <- lapply(subcats, function(subcat) {
        subcat_data <- cat_data[cat_data$subcategory == subcat, , drop = FALSE]
        subcat_hiera <- paste(ch, cat, subcat, sep = ".")
        subcat_label <- get_label(subcat_hiera)

        list(
          name = subcat_label,
          id = subcat_hiera,
          value = nrow(subcat_data)
        )
      })

      list(
        name = cat_label,
        id = cat_hiera,
        value = nrow(cat_data),
        children = subcat_children
      )
    })

    list(
      name = ch_label,
      id = ch,
      value = nrow(ch_data),
      children = cat_children
    )
  })

  list(name = "root", children = children)
}
