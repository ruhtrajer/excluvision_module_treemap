test_that("get_icd_data returns data frame with expected columns", {
  data <- get_icd_data()
  expect_s3_class(data, "data.frame")
  expect_named(data, c("code", "lib", "liblong", "hiera"))
})

test_that("get_icd_data returns all ICD-10 codes", {
  data <- get_icd_data()
  expect_gt(nrow(data), 40000)  # Should have 42k+ codes
})

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
