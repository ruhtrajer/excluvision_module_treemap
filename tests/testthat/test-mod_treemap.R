test_that("mod_treemap_ui returns shiny tag list", {
  ui <- mod_treemap_ui("test")
  expect_s3_class(ui, "shiny.tag.list")
})

test_that("mod_treemap_ui contains plot output", {
  ui <- mod_treemap_ui("test")
  ui_html <- as.character(ui)
  expect_true(grepl("test-treemap_plot", ui_html))
})
