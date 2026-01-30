test_that("mod_icd_selector_ui returns shiny tag list", {
  ui <- mod_icd_selector_ui("test")
  expect_s3_class(ui, "shiny.tag.list")
})

test_that("mod_icd_selector_ui contains virtualSelectInput", {
  ui <- mod_icd_selector_ui("test")
  ui_html <- as.character(ui)
  expect_true(grepl("test-icd_codes", ui_html))
})
