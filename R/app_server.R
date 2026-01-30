#' The application server-side
#'
#' @param input,output,session Internal parameters for {shiny}.
#'     DO NOT REMOVE.
#' @import shiny
#' @noRd
app_server <- function(input, output, session) {

  # Shared reactive object ("petit r" technique from Engineering Shiny)
  # This allows modules to communicate through a common reactive state

  r <- shiny::reactiveValues(
    selected_codes = NULL
  )

  # ICD selector writes to r$selected_codes

  mod_icd_selector_server("icd_selector", r = r)

  # Treemap reads from r$selected_codes
  mod_treemap_server("treemap", r = r)
}
