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
