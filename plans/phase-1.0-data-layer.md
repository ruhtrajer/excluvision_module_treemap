# Phase 1.0: Data Layer & Hierarchy Parsing

## Overview
Build the data foundation for the treemap module: load ICD-10 data from parquet, load hierarchies from RDA, and provide functions to parse the hierarchy structure.

## Data Sources
- `cim.parquet`: 42,496 ICD-10 codes with columns: `code`, `lib`, `liblong`, `hiera`
- `cim_hiera.rda`: Hierarchy lookup with columns: `hiera`, `diag_deb`, `diag_fin`, `lib`

## Hierarchy Structure
- Format: "XX.YY.ZZ" where XX=chapter, YY=category, ZZ=subcategory
- Variable depth: some codes have 2 levels ("01.01"), some have 3 ("01.01.01")
- Example: "01.01" → chapter="01", category="01", subcategory=NA

---

## Implementation Steps (TDD Approach)

### Step 1: Create test file structure
**Task**: Set up testthat infrastructure

**Actions**:
1. Create `tests/testthat/` directory
2. Create `tests/testthat.R` bootstrap file
3. Add testthat to Suggests in DESCRIPTION

**Exit Criteria**:
- [ ] `devtools::test()` runs without error (0 tests OK)

---

### Step 2: Write tests for `get_icd_data()`
**Task**: Write failing tests for data loading function

**Test Cases**:
```r
test_that("get_icd_data returns data frame with expected columns", {
  data <- get_icd_data()
  expect_s3_class(data, "data.frame")
  expect_named(data, c("code", "lib", "liblong", "hiera"))
})

test_that("get_icd_data returns all ICD-10 codes",
{
  data <- get_icd_data()
  expect_gt(nrow(data), 40000)  # Should have 42k+ codes
})
```

**Exit Criteria**:
- [ ] Tests exist and FAIL (function doesn't exist yet)

---

### Step 3: Implement `get_icd_data()`
**Task**: Create R/fct_data.R with data loading function

**Implementation**:
```r
#' Load ICD-10 data from parquet
#' @return data.frame with columns: code, lib, liblong, hiera
#' @export
get_icd_data <- function() {
  nanoparquet::read_parquet(
    app_sys("cim.parquet")
  )
}
```

**Exit Criteria**:
- [ ] `get_icd_data()` tests pass
- [ ] `devtools::check()` passes

---

### Step 4: Write tests for `get_hierarchy_lookup()`
**Task**: Write failing tests for hierarchy lookup loading

**Test Cases**:
```r
test_that("get_hierarchy_lookup returns data frame with expected columns", {
  lookup <- get_hierarchy_lookup()
  expect_s3_class(lookup, "data.frame")
  expect_named(lookup, c("hiera", "diag_deb", "diag_fin", "lib"))
})

test_that("get_hierarchy_lookup contains chapter entries", {
  lookup <- get_hierarchy_lookup()
  # Chapters are single-segment hiera values like "01", "02"
  chapters <- lookup[nchar(lookup$hiera) == 2, ]
  expect_gt(nrow(chapters), 0)
})
```

**Exit Criteria**:
- [ ] Tests exist and FAIL

---

### Step 5: Implement `get_hierarchy_lookup()`
**Task**: Add function to load hierarchy from RDA

**Implementation**:
```r
#' Load ICD-10 hierarchy lookup
#' @return data.frame with columns: hiera, diag_deb, diag_fin, lib
#' @export
get_hierarchy_lookup <- function() {
  env <- new.env()
  load(app_sys("cim_hiera.rda"), envir = env)
  env$cim_hiera
}
```

**Exit Criteria**:
- [ ] `get_hierarchy_lookup()` tests pass

---

### Step 6: Write tests for `parse_hierarchy()`
**Task**: Write failing tests for hierarchy parsing

**Test Cases**:
```r
test_that("parse_hierarchy extracts chapter correctly", {
  result <- parse_hierarchy("01.02.03")
  expect_equal(result$chapter, "01")
})

test_that("parse_hierarchy extracts category correctly", {
  result <- parse_hierarchy("01.02.03")
  expect_equal(result$category, "02")
})

test_that("parse_hierarchy extracts subcategory correctly", {
  result <- parse_hierarchy("01.02.03")
  expect_equal(result$subcategory, "03")
})

test_that("parse_hierarchy handles 2-level hierarchy", {
  result <- parse_hierarchy("05.12")
  expect_equal(result$chapter, "05")
  expect_equal(result$category, "12")
  expect_true(is.na(result$subcategory))
})

test_that("parse_hierarchy handles chapter-only", {
  result <- parse_hierarchy("07")
  expect_equal(result$chapter, "07")
  expect_true(is.na(result$category))
  expect_true(is.na(result$subcategory))
})

test_that("parse_hierarchy is vectorized", {
  result <- parse_hierarchy(c("01.02", "03.04.05"))
  expect_equal(nrow(result), 2)
  expect_equal(result$chapter, c("01", "03"))
})
```

**Exit Criteria**:
- [ ] Tests exist and FAIL

---

### Step 7: Implement `parse_hierarchy()`
**Task**: Create R/utils_hierarchy.R with parsing function

**Implementation**:
```r
#' Parse hierarchy string into components
#' @param hiera Character vector of hierarchy strings (e.g., "01.02.03")
#' @return data.frame with columns: chapter, category, subcategory
#' @export
parse_hierarchy <- function(hiera) {
  parts <- strsplit(hiera, "\\.")
  data.frame(
    chapter = vapply(parts, `[`, character(1), 1),
    category = vapply(parts, function(x) if(length(x) >= 2) x[2] else NA_character_, character(1)),
    subcategory = vapply(parts, function(x) if(length(x) >= 3) x[3] else NA_character_, character(1)),
    stringsAsFactors = FALSE
  )
}
```

**Exit Criteria**:
- [ ] All `parse_hierarchy()` tests pass

---

### Step 8: Write tests for `enrich_icd_data()`
**Task**: Write failing tests for enrichment function that adds parsed hierarchy

**Test Cases**:
```r
test_that("enrich_icd_data adds hierarchy columns", {
  data <- get_icd_data()
  enriched <- enrich_icd_data(data)
  expect_true(all(c("chapter", "category", "subcategory") %in% names(enriched)))
})

test_that("enrich_icd_data preserves original columns", {
  data <- get_icd_data()
  enriched <- enrich_icd_data(data)
  expect_true(all(c("code", "lib", "liblong", "hiera") %in% names(enriched)))
})

test_that("enrich_icd_data preserves row count", {
  data <- get_icd_data()
  enriched <- enrich_icd_data(data)
  expect_equal(nrow(enriched), nrow(data))
})
```

**Exit Criteria**:
- [ ] Tests exist and FAIL

---

### Step 9: Implement `enrich_icd_data()`
**Task**: Add function to combine data loading with hierarchy parsing

**Implementation**:
```r
#' Enrich ICD data with parsed hierarchy columns
#' @param data ICD data frame (from get_icd_data)
#' @return data.frame with added chapter, category, subcategory columns
#' @export
enrich_icd_data <- function(data) {
  parsed <- parse_hierarchy(data$hiera)
  cbind(data, parsed)
}
```

**Exit Criteria**:
- [ ] All tests pass
- [ ] `devtools::check()` passes with 0 errors, 0 warnings

---

### Step 10: Copy data files to inst/
**Task**: Move data files to proper package location

**Actions**:
1. Create `inst/extdata/` directory
2. Copy `cim.parquet` and `cim_hiera.rda` to `inst/extdata/`
3. Update functions to use `app_sys("extdata/...")`

**Exit Criteria**:
- [ ] All tests still pass
- [ ] Data loads correctly from installed package path

---

### Step 11: Update DESCRIPTION
**Task**: Add nanoparquet to Imports

**Exit Criteria**:
- [ ] `devtools::check()` passes
- [ ] Package installs cleanly

---

### Step 12: Document functions
**Task**: Add roxygen2 documentation

**Exit Criteria**:
- [ ] All exported functions have roxygen docs
- [ ] `devtools::document()` runs without errors
- [ ] `devtools::check()` passes

---

## Final Exit Criteria for Phase 1.0

- [ ] All tests pass (`devtools::test()`)
- [ ] `devtools::check()` passes with 0 errors, 0 warnings, minimal notes
- [ ] Functions are documented with roxygen2
- [ ] Data files are in `inst/extdata/`
- [ ] DESCRIPTION has correct dependencies

## Files Created/Modified

**New Files**:
- `R/fct_data.R` - Data loading functions
- `R/utils_hierarchy.R` - Hierarchy parsing utilities
- `tests/testthat.R` - Test bootstrap
- `tests/testthat/test-fct_data.R` - Data function tests
- `tests/testthat/test-utils_hierarchy.R` - Hierarchy parsing tests
- `inst/extdata/cim.parquet` - ICD-10 data (copied)
- `inst/extdata/cim_hiera.rda` - Hierarchy lookup (copied)

**Modified Files**:
- `DESCRIPTION` - Add nanoparquet, testthat
- `NAMESPACE` - Export new functions
