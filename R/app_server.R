#' The application server-side
#'
#' @param input,output,session Internal parameters for {shiny}.
#'     DO NOT REMOVE.
#' @import shiny
#' @noRd
app_server <- function(input, output, session) {
  # For Phase 2.0: use sample codes for testing
  # This will be replaced with actual input selection in Phase 3.0
  sample_codes <- reactive({
    icd_data <- get_icd_data()
    # Return first 500 codes as sample
    icd_data$code[1:500]
  })

  mod_treemap_server("treemap", selected_codes = sample_codes)
}
