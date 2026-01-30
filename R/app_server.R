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
