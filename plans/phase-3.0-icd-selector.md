# Phase 3.0: ICD-10 Input Selector Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create an ICD-10 code selector input that handles 40k+ codes with search capability.

**Architecture:** Create `mod_icd_selector.R` as a golem Shiny module using `shinyWidgets::virtualSelectInput` for performant selection of large lists. Add helper function `format_icd_choices()` in `fct_data.R` to format codes as "A00 - Description" for searchability.

**Tech Stack:** shinyWidgets for virtualSelectInput, testthat for testing.

---

## Pre-requisites

- Phase 2.0 complete: treemap module working
- Add `shinyWidgets` package to DESCRIPTION Imports

---

## Task 1: Add shinyWidgets package dependency

**Files:**
- Modify: `DESCRIPTION`

**Step 1: Add shinyWidgets to Imports**

Edit `DESCRIPTION` Imports section:

```
Imports: 
    config,
    golem,
    nanoparquet,
    shiny,
    shinyWidgets,
    treemap
```

**Step 2: Verify installation**

Run: `Rscript -e "if (!requireNamespace('shinyWidgets', quietly=TRUE)) install.packages('shinyWidgets', repos='https://cloud.r-project.org', quiet=TRUE); library(shinyWidgets); packageVersion('shinyWidgets')"`

Expected: Version number printed (e.g., "0.8.6")

**Step 3: Commit**

```bash
git add DESCRIPTION
git commit -m "chore: add shinyWidgets package dependency"
```

---

## Task 2: Create format_icd_choices helper function with TDD

**Files:**
- Modify: `tests/testthat/test-fct_data.R`
- Modify: `R/fct_data.R`

### Step 1: Write failing tests for format_icd_choices()

Append to `tests/testthat/test-fct_data.R`:

```r
test_that("format_icd_choices returns named vector", {
  test_data <- data.frame(
    code = c("A00", "A01"),
    lib = c("CHOLERA", "TYPHOID"),
    stringsAsFactors = FALSE
  )
  
  result <- format_icd_choices(test_data)
  
  expect_type(result, "character")
  expect_true(!is.null(names(result)))
})

test_that("format_icd_choices formats labels as 'CODE - Description'", {
  test_data <- data.frame(
    code = c("A00", "B99"),
    lib = c("CHOLERA", "OTHER DISEASE"),
    stringsAsFactors = FALSE
  )
  
  result <- format_icd_choices(test_data)
  
  expect_equal(names(result)[1], "A00 - CHOLERA")
  expect_equal(names(result)[2], "B99 - OTHER DISEASE")
})

test_that("format_icd_choices uses code as value", {
  test_data <- data.frame(
    code = c("A00", "B99"),
    lib = c("CHOLERA", "OTHER DISEASE"),
    stringsAsFactors = FALSE
  )
  
  result <- format_icd_choices(test_data)
  
  expect_equal(unname(result[1]), "A00")
  expect_equal(unname(result[2]), "B99")
})

test_that("format_icd_choices handles empty data", {
  test_data <- data.frame(
    code = character(0),
    lib = character(0),
    stringsAsFactors = FALSE
  )
  
  result <- format_icd_choices(test_data)
  
  expect_length(result, 0)
})

test_that("format_icd_choices works with real ICD data", {
  icd_data <- get_icd_data()
  
  result <- format_icd_choices(icd_data)
  
  expect_gt(length(result), 40000)
  # Check format of first entry
  expect_true(grepl(" - ", names(result)[1]))
})
```

### Step 2: Run tests to verify they fail

Run: `cd /home/arthur/repo/excluvision_module_treemap && Rscript -e "devtools::test(filter = 'fct_data')"`

Expected: 5 new tests FAIL with "could not find function 'format_icd_choices'"

### Step 3: Implement format_icd_choices()

Append to `R/fct_data.R`:

```r
#' Format ICD data as choices for selection input
#'
#' Creates a named character vector suitable for use with selectInput
#' or virtualSelectInput. Names are formatted as "CODE - Description"
#' for searchability, values are the ICD codes.
#'
#' @param data ICD data frame with columns: code, lib
#' @return Named character vector (names = labels, values = codes)
#' @export
format_icd_choices <- function(data) {
  if (nrow(data) == 0) {
    return(character(0))
  }
  
  # Create labels as "CODE - Description"
  labels <- paste(data$code, "-", data$lib)
  
  # Create named vector: names are display labels, values are codes
  choices <- stats::setNames(data$code, labels)
  
  choices
}
```

### Step 4: Run tests to verify they pass

Run: `cd /home/arthur/repo/excluvision_module_treemap && Rscript -e "devtools::test(filter = 'fct_data')"`

Expected: All 8 tests PASS (3 original + 5 new)

### Step 5: Commit

```bash
git add R/fct_data.R tests/testthat/test-fct_data.R
git commit -m "feat: add format_icd_choices helper function"
```

---

## Task 3: Create mod_icd_selector module with TDD

**Files:**
- Create: `tests/testthat/test-mod_icd_selector.R`
- Create: `R/mod_icd_selector.R`

### Step 1: Write failing tests for module UI

Create `tests/testthat/test-mod_icd_selector.R`:

```r
test_that("mod_icd_selector_ui returns shiny tag list", {
  ui <- mod_icd_selector_ui("test")
  expect_s3_class(ui, "shiny.tag.list")
})

test_that("mod_icd_selector_ui contains virtualSelectInput", {
  ui <- mod_icd_selector_ui("test")
  ui_html <- as.character(ui)
  expect_true(grepl("test-icd_codes", ui_html))
})
```

### Step 2: Run tests to verify they fail

Run: `cd /home/arthur/repo/excluvision_module_treemap && Rscript -e "devtools::test(filter = 'mod_icd_selector')"`

Expected: Tests FAIL with "could not find function 'mod_icd_selector_ui'"

### Step 3: Implement mod_icd_selector module

Create `R/mod_icd_selector.R`:

```r
#' ICD Selector Module UI
#'
#' Creates a virtual select input for choosing ICD-10 codes.
#' Uses virtualSelectInput for performance with 40k+ items.
#'
#' @param id Module namespace id
#' @return Shiny UI tag list
#' @export
mod_icd_selector_ui <- function(id) {

  ns <- shiny::NS(id)
  
  shiny::tagList(
    shinyWidgets::virtualSelectInput(
      inputId = ns("icd_codes"),
      label = "Select ICD-10 codes:",
      choices = NULL,  # Choices loaded server-side
      multiple = TRUE,
      search = TRUE,
      placeholder = "Search and select codes...",
      showValueAsTags = TRUE,
      searchPlaceholderText = "Type to search (code or description)...",
      noOptionsText = "No matching codes",
      noSearchResultsText = "No results found",
      selectAllOnlyVisible = TRUE,
      optionsSelectedText = "codes selected",
      allOptionsSelectedText = "All codes selected",
      showSelectedOptionsFirst = TRUE,
      zIndex = 10
    )
  )
}

#' ICD Selector Module Server
#'
#' Server logic for ICD code selector. Loads ICD data and updates
#' virtualSelectInput choices.
#'
#' @param id Module namespace id
#' @return Reactive expression returning vector of selected ICD codes
#' @export
mod_icd_selector_server <- function(id) {
  shiny::moduleServer(id, function(input, output, session) {
    # Load ICD data once
    icd_data <- get_icd_data()
    choices <- format_icd_choices(icd_data)
    
    # Update choices in virtualSelectInput
    shinyWidgets::updateVirtualSelect(
      session = session,
      inputId = "icd_codes",
      choices = choices
    )
    
    # Return reactive with selected codes
    shiny::reactive({
      input$icd_codes
    })
  })
}
```

### Step 4: Run tests to verify they pass

Run: `cd /home/arthur/repo/excluvision_module_treemap && Rscript -e "devtools::test(filter = 'mod_icd_selector')"`

Expected: All 2 tests PASS

### Step 5: Commit

```bash
git add R/mod_icd_selector.R tests/testthat/test-mod_icd_selector.R
git commit -m "feat: add mod_icd_selector Shiny module with virtualSelectInput"
```

---

## Task 4: Integrate selector module into app

**Files:**
- Modify: `R/app_ui.R`
- Modify: `R/app_server.R`

### Step 1: Update app_ui.R

Replace current UI with selector + treemap layout:

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
          width = 4,
          wellPanel(
            mod_icd_selector_ui("icd_selector")
          )
        ),
        column(
          width = 8,
          mod_treemap_ui("treemap")
        )
      )
    )
  )
}
```

### Step 2: Update app_server.R

Wire selector to treemap:

```r
#' The application server-side
#'
#' @param input,output,session Internal parameters for {shiny}.
#'     DO NOT REMOVE.
#' @import shiny
#' @noRd
app_server <- function(input, output, session) {
  # ICD selector returns reactive with selected codes
  selected_codes <- mod_icd_selector_server("icd_selector")
  
  # Pass selected codes to treemap module
  mod_treemap_server("treemap", selected_codes = selected_codes)
}
```

### Step 3: Commit

```bash
git add R/app_ui.R R/app_server.R
git commit -m "feat: integrate ICD selector with treemap in app layout"
```

---

## Task 5: Run all tests and generate documentation

**Step 1: Run full test suite**

Run: `cd /home/arthur/repo/excluvision_module_treemap && Rscript -e "devtools::test()"`

Expected: All tests PASS (~44 tests: 37 existing + 5 format_icd_choices + 2 mod_icd_selector)

**Step 2: Generate documentation**

Run: `cd /home/arthur/repo/excluvision_module_treemap && Rscript -e "devtools::document()"`

Expected: New .Rd files created for format_icd_choices, mod_icd_selector_ui, mod_icd_selector_server

**Step 3: Commit documentation updates**

```bash
git add NAMESPACE man/
git commit -m "docs: update documentation for Phase 3.0"
```

---

## Task 6: Human visual verification

**⚠️ STOP: Human review required**

**Instructions for human tester:**

1. Start the Shiny app:
   ```r
   devtools::load_all()
   run_app()
   ```

2. Verify ICD selector functionality:
   - [ ] virtualSelectInput appears in left panel
   - [ ] Typing in search box filters codes (try "A00", "cholera")
   - [ ] Multiple selection works (select 5-10 codes)
   - [ ] Selected codes show as tags
   - [ ] Treemap updates when codes are selected
   - [ ] Empty selection shows placeholder message in treemap

3. Performance check:
   - [ ] Initial load time acceptable (<3 seconds)
   - [ ] Search/filter responsive (<500ms)

4. Report any issues before proceeding.

---

## Exit Criteria Checklist

- [ ] shinyWidgets package added to DESCRIPTION
- [ ] `format_icd_choices()` function works with unit tests
- [ ] `mod_icd_selector_ui/server` module created with tests
- [ ] virtualSelectInput displays all 40k+ codes
- [ ] Search works (by code and label)
- [ ] Multiple selection enabled
- [ ] Selector integrated with treemap in app
- [ ] All tests pass
- [ ] Human visual verification complete

---

## Files Created/Modified Summary

| File | Action | Purpose |
|------|--------|---------|
| `DESCRIPTION` | Modified | Add shinyWidgets dependency |
| `R/fct_data.R` | Modified | Add format_icd_choices() |
| `R/mod_icd_selector.R` | Created | ICD selector Shiny module |
| `R/app_ui.R` | Modified | Add selector to layout |
| `R/app_server.R` | Modified | Wire selector to treemap |
| `tests/testthat/test-fct_data.R` | Modified | Add format_icd_choices tests |
| `tests/testthat/test-mod_icd_selector.R` | Created | Module tests |
| `NAMESPACE` | Modified | Exports (via devtools::document) |
| `man/*.Rd` | Created | Documentation files |
