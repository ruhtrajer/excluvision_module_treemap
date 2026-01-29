test_that("get_icd_data returns data frame with expected columns", {
  data <- get_icd_data()
  expect_s3_class(data, "data.frame")
  expect_named(data, c("code", "lib", "liblong", "hiera"))
})

test_that("get_icd_data returns all ICD-10 codes", {
  data <- get_icd_data()
  expect_gt(nrow(data), 40000)  # Should have 42k+ codes
})
