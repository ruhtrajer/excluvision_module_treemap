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
