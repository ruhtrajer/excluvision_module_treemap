# Phase 2.0: Basic Treemap Display Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Render a static treemap showing selected ICD-10 codes aggregated by hierarchy level.

**Architecture:** Create `fct_treemap.R` with pure functions to aggregate ICD codes by hierarchy and prepare data for treemap visualization. Create `mod_treemap.R` as a golem Shiny module that wraps the treemap output. Use `treemap::treemap()` for initial static rendering.

**Tech Stack:** treemap package for visualization, base R for aggregation logic, testthat for testing.

---

## Pre-requisites

- Phase 1.0 complete: `get_icd_data()`, `enrich_icd_data()`, `parse_hierarchy()` available
- Add `treemap` package to DESCRIPTION Imports

---

## Task 1: Add treemap package dependency

**Files:**
- Modify: `DESCRIPTION`

**Step 1: Add treemap to Imports**

Edit `DESCRIPTION` Imports section to add `treemap`:

```
Imports: 
    config,
    golem,
    nanoparquet,
    shiny,
    treemap
```

**Step 2: Install the package**

Run: `R -e "install.packages('treemap', repos='https://cloud.r-project.org')"`

**Step 3: Verify installation**

Run: `R -e "library(treemap); packageVersion('treemap')"`
Expected: Version number printed (e.g., "2.4.4")

**Step 4: Commit**

```bash
git add DESCRIPTION
git commit -m "chore: add treemap package dependency"
```

---

## Task 2: Create aggregation function with TDD

**Files:**
- Create: `tests/testthat/test-fct_treemap.R`
- Create: `R/fct_treemap.R`

### Step 1: Write failing tests for aggregate_by_hierarchy()

Create `tests/testthat/test-fct_treemap.R`:

```r
test_that("aggregate_by_hierarchy returns data frame with required columns", {
  # Create minimal test data
  test_data <- data.frame(
    code = c("A00", "A01", "B00"),
    lib = c("Disease A", "Disease B", "Disease C"),
    chapter = c("01", "01", "02"),
    category = c("01", "01", "01"),
    subcategory = c(NA, NA, NA),
    stringsAsFactors = FALSE
  )
  
  result <- aggregate_by_hierarchy(test_data, level = "chapter")
  
  expect_s3_class(result, "data.frame")
  expect_true("group" %in% names(result))
  expect_true("count" %in% names(result))
})

test_that("aggregate_by_hierarchy counts codes by chapter", {
  test_data <- data.frame(
    code = c("A00", "A01", "B00", "B01", "B02"),
    lib = c("D1", "D2", "D3", "D4", "D5"),
    chapter = c("01", "01", "02", "02", "02"),
    category = c("01", "01", "01", "02", "02"),
    subcategory = c(NA, NA, NA, NA, NA),
    stringsAsFactors = FALSE
  )
  
  result <- aggregate_by_hierarchy(test_data, level = "chapter")
  
  expect_equal(nrow(result), 2)
  expect_equal(result$count[result$group == "01"], 2)
  expect_equal(result$count[result$group == "02"], 3)
})

test_that("aggregate_by_hierarchy works at category level", {
  test_data <- data.frame(
    code = c("A00", "A01", "A10"),
    lib = c("D1", "D2", "D3"),
    chapter = c("01", "01", "01"),
    category = c("01", "01", "02"),
    subcategory = c(NA, NA, NA),
    stringsAsFactors = FALSE
  )
  
  result <- aggregate_by_hierarchy(test_data, level = "category")
  
  expect_equal(nrow(result), 2)
  expect_equal(result$count[result$group == "01"], 2)
  expect_equal(result$count[result$group == "02"], 1)
})

test_that("aggregate_by_hierarchy filters by parent when provided", {
  test_data <- data.frame(
    code = c("A00", "A01", "B00"),
    lib = c("D1", "D2", "D3"),
    chapter = c("01", "01", "02"),
    category = c("01", "02", "01"),
    subcategory = c(NA, NA, NA),
    stringsAsFactors = FALSE
  )
  
  result <- aggregate_by_hierarchy(test_data, level = "category", parent_filter = "01")
  
  # Should only include categories within chapter "01"
  expect_equal(nrow(result), 2)
  expect_false("02" %in% result$chapter) # No chapter 02 data
})

test_that("aggregate_by_hierarchy returns empty data frame for empty input", {
  test_data <- data.frame(
    code = character(0),
    lib = character(0),
    chapter = character(0),
    category = character(0),
    subcategory = character(0),
    stringsAsFactors = FALSE
  )
  
  result <- aggregate_by_hierarchy(test_data, level = "chapter")
  
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0)
})
```

### Step 2: Run tests to verify they fail

Run: `cd /home/arthur/repo/excluvision_module_treemap && Rscript -e "devtools::test(filter = 'fct_treemap')"`

Expected: All tests FAIL with "could not find function 'aggregate_by_hierarchy'"

### Step 3: Implement aggregate_by_hierarchy()

Create `R/fct_treemap.R`:

```r
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
```

### Step 4: Run tests to verify they pass

Run: `cd /home/arthur/repo/excluvision_module_treemap && Rscript -e "devtools::test(filter = 'fct_treemap')"`

Expected: All 5 tests PASS

### Step 5: Commit

```bash
git add R/fct_treemap.R tests/testthat/test-fct_treemap.R
git commit -m "feat: add aggregate_by_hierarchy function with tests"
```

---

## Task 3: Create treemap data preparation function with TDD

**Files:**
- Modify: `tests/testthat/test-fct_treemap.R`
- Modify: `R/fct_treemap.R`

### Step 1: Write failing tests for prepare_treemap_data()

Append to `tests/testthat/test-fct_treemap.R`:

```r
test_that("prepare_treemap_data returns treemap-ready data frame", {
  test_data <- data.frame(
    code = c("A00", "A01", "B00"),
    lib = c("Disease A", "Disease B", "Disease C"),
    chapter = c("01", "01", "02"),
    category = c("01", "01", "01"),
    subcategory = c(NA, NA, NA),
    stringsAsFactors = FALSE
  )
  
  result <- prepare_treemap_data(test_data)
  
  expect_s3_class(result, "data.frame")
  expect_true(all(c("group", "count", "label") %in% names(result)))
})

test_that("prepare_treemap_data includes labels from hierarchy lookup", {
  # This test uses real data to verify label lookup
  icd_data <- get_icd_data()
  enriched <- enrich_icd_data(icd_data)
  # Take small subset
  subset_data <- enriched[enriched$chapter == "01", ][1:10, ]
  
  result <- prepare_treemap_data(subset_data)
  
  # Labels should not be just numeric codes
  expect_true(any(nchar(result$label) > 2))
})

test_that("prepare_treemap_data handles empty data", {

  test_data <- data.frame(
    code = character(0),
    lib = character(0),
    chapter = character(0),
    category = character(0),
    subcategory = character(0),
    stringsAsFactors = FALSE
  )
  
  result <- prepare_treemap_data(test_data)
  
  expect_equal(nrow(result), 0)
})
```

### Step 2: Run tests to verify they fail

Run: `cd /home/arthur/repo/excluvision_module_treemap && Rscript -e "devtools::test(filter = 'fct_treemap')"`

Expected: New tests FAIL with "could not find function 'prepare_treemap_data'"

### Step 3: Implement prepare_treemap_data()

Append to `R/fct_treemap.R`:

```r
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
```

### Step 4: Run tests to verify they pass

Run: `cd /home/arthur/repo/excluvision_module_treemap && Rscript -e "devtools::test(filter = 'fct_treemap')"`

Expected: All 8 tests PASS

### Step 5: Commit

```bash
git add R/fct_treemap.R tests/testthat/test-fct_treemap.R
git commit -m "feat: add prepare_treemap_data function with label lookup"
```

---

## Task 4: Create render_treemap function with TDD

**Files:**
- Modify: `tests/testthat/test-fct_treemap.R`
- Modify: `R/fct_treemap.R`

### Step 1: Write failing test for render_treemap()

Append to `tests/testthat/test-fct_treemap.R`:

```r
test_that("render_treemap returns NULL for empty data", {
  test_data <- data.frame(
    group = character(0),
    count = integer(0),
    label = character(0),
    stringsAsFactors = FALSE
  )
  
  result <- render_treemap(test_data)
  expect_null(result)
})

test_that("render_treemap creates treemap object", {
  test_data <- data.frame(
    group = c("01", "02"),
    count = c(100, 200),
    label = c("Chapter 1", "Chapter 2"),
    stringsAsFactors = FALSE
  )
  
  # render_treemap should not error
  expect_no_error(render_treemap(test_data))
})
```

### Step 2: Run tests to verify they fail

Run: `cd /home/arthur/repo/excluvision_module_treemap && Rscript -e "devtools::test(filter = 'fct_treemap')"`

Expected: New tests FAIL with "could not find function 'render_treemap'"

### Step 3: Implement render_treemap()

Append to `R/fct_treemap.R`:

```r
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
```

### Step 4: Run tests to verify they pass

Run: `cd /home/arthur/repo/excluvision_module_treemap && Rscript -e "devtools::test(filter = 'fct_treemap')"`

Expected: All 10 tests PASS

### Step 5: Commit

```bash
git add R/fct_treemap.R tests/testthat/test-fct_treemap.R
git commit -m "feat: add render_treemap function"
```

---

## Task 5: Create Shiny module mod_treemap

**Files:**
- Create: `R/mod_treemap.R`
- Create: `tests/testthat/test-mod_treemap.R`

### Step 1: Write module test

Create `tests/testthat/test-mod_treemap.R`:

```r
test_that("mod_treemap_ui returns shiny tag list", {
  ui <- mod_treemap_ui("test")
  expect_s3_class(ui, "shiny.tag.list")
})

test_that("mod_treemap_ui contains plot output", {
  ui <- mod_treemap_ui("test")
  ui_html <- as.character(ui)
  expect_true(grepl("test-treemap_plot", ui_html))
})
```

### Step 2: Run tests to verify they fail

Run: `cd /home/arthur/repo/excluvision_module_treemap && Rscript -e "devtools::test(filter = 'mod_treemap')"`

Expected: Tests FAIL with "could not find function 'mod_treemap_ui'"

### Step 3: Implement mod_treemap module

Create `R/mod_treemap.R`:

```r
#' Treemap Module UI
#'
#' @param id Module namespace id
#' @return Shiny UI tag list
#' @export
mod_treemap_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::plotOutput(ns("treemap_plot"), height = "500px")
  )
}

#' Treemap Module Server
#'
#' @param id Module namespace id
#' @param selected_codes Reactive expression returning vector of selected ICD codes
#' @return NULL (side effects only)
#' @export
mod_treemap_server <- function(id, selected_codes) {
  shiny::moduleServer(id, function(input, output, session) {
    # Load and enrich data once
    icd_data <- enrich_icd_data(get_icd_data())
    
    # Filter data based on selected codes
    filtered_data <- shiny::reactive({
      codes <- selected_codes()
      if (is.null(codes) || length(codes) == 0) {
        return(icd_data[0, ])  # Empty data frame with same structure
      }
      icd_data[icd_data$code %in% codes, ]
    })
    
    # Prepare treemap data
    treemap_data <- shiny::reactive({
      prepare_treemap_data(filtered_data())
    })
    
    # Render treemap
    output$treemap_plot <- shiny::renderPlot({
      data <- treemap_data()
      if (nrow(data) == 0) {
        plot.new()
        text(0.5, 0.5, "Select ICD-10 codes to display treemap", 
             cex = 1.5, col = "gray50")
        return()
      }
      render_treemap(data)
    })
  })
}
```

### Step 4: Run tests to verify they pass

Run: `cd /home/arthur/repo/excluvision_module_treemap && Rscript -e "devtools::test(filter = 'mod_treemap')"`

Expected: All 2 tests PASS

### Step 5: Commit

```bash
git add R/mod_treemap.R tests/testthat/test-mod_treemap.R
git commit -m "feat: add mod_treemap Shiny module"
```

---

## Task 6: Integrate module into app for visual testing

**Files:**
- Modify: `R/app_ui.R`
- Modify: `R/app_server.R`

### Step 1: Update app_ui.R

Replace golem welcome page with treemap module:

```r
#' The application User-Interface
#'
#' @param request Internal parameter for `{shiny}`.
#'     DO NOT REMOVE.
#' @import shiny
#' @noRd
app_ui <- function(request) {
  tagList(
    golem_add_external_resources(),
    fluidPage(
      h1("ICD-10 Treemap"),
      fluidRow(
        column(
          width = 12,
          mod_treemap_ui("treemap")
        )
      )
    )
  )
}
```

### Step 2: Update app_server.R

Wire up the module with sample data:

```r
#' The application server-side
#'
#' @param input,output,session Internal parameters for {shiny}.
#'     DO NOT REMOVE.
#' @import shiny
#' @noRd
app_server <- function(input, output, session) {
  # For Phase 2.0: use sample codes for testing
  # This will be replaced with actual input selection in Phase 3.0
  sample_codes <- reactive({
    icd_data <- get_icd_data()
    # Return first 500 codes as sample
    icd_data$code[1:500]
  })
  
  mod_treemap_server("treemap", selected_codes = sample_codes)
}
```

### Step 3: Commit

```bash
git add R/app_ui.R R/app_server.R
git commit -m "feat: integrate treemap module into app for visual testing"
```

---

## Task 7: Run all tests and verify

**Step 1: Run full test suite**

Run: `cd /home/arthur/repo/excluvision_module_treemap && Rscript -e "devtools::test()"`

Expected: All tests PASS (17 from Phase 1 + 12 new = ~29 tests)

**Step 2: Generate documentation**

Run: `cd /home/arthur/repo/excluvision_module_treemap && Rscript -e "devtools::document()"`

**Step 3: Check package**

Run: `cd /home/arthur/repo/excluvision_module_treemap && Rscript -e "devtools::check(document = FALSE, args = '--no-examples')"`

Expected: 0 errors, 0 warnings (notes OK)

**Step 4: Commit documentation updates**

```bash
git add NAMESPACE man/
git commit -m "docs: update documentation for Phase 2.0"
```

---

## Task 8: Human visual verification

**⚠️ STOP: Human review required**

**Instructions for human tester:**

1. Start the Shiny app:
   ```r
   devtools::load_all()
   run_app()
   ```

2. Verify:
   - [ ] App loads without error
   - [ ] Treemap displays with sample ICD-10 codes
   - [ ] Treemap shows colored rectangles proportional to code counts
   - [ ] Labels are readable on treemap rectangles
   - [ ] Colors are visually distinct

3. Report any issues before proceeding.

---

## Exit Criteria Checklist

- [ ] `aggregate_by_hierarchy()` function works with unit tests
- [ ] `prepare_treemap_data()` function works with unit tests
- [ ] `render_treemap()` function works with unit tests
- [ ] `mod_treemap_ui/server` module created
- [ ] Treemap renders correctly given a subset of codes
- [ ] All tests pass
- [ ] Package check passes
- [ ] Human visual verification complete

---

## Files Created/Modified Summary

| File | Action | Purpose |
|------|--------|---------|
| `DESCRIPTION` | Modified | Add treemap dependency |
| `R/fct_treemap.R` | Created | Aggregation and rendering functions |
| `R/mod_treemap.R` | Created | Shiny module |
| `R/app_ui.R` | Modified | Integrate module |
| `R/app_server.R` | Modified | Integrate module |
| `tests/testthat/test-fct_treemap.R` | Created | Function tests |
| `tests/testthat/test-mod_treemap.R` | Created | Module tests |
| `NAMESPACE` | Modified | Exports (via devtools::document) |
| `man/*.Rd` | Created | Documentation files |
