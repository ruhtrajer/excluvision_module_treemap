#' Treemap Module UI
#'
#' @param id Module namespace id
#' @return Shiny UI tag list
#' @export
mod_treemap_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::plotOutput(ns("treemap_plot"), height = "500px")
  )
}

#' Treemap Module Server
#'
#' @param id Module namespace id
#' @param selected_codes Reactive expression returning vector of selected ICD codes
#' @return NULL (side effects only)
#' @export
mod_treemap_server <- function(id, selected_codes) {
  shiny::moduleServer(id, function(input, output, session) {
    # Load and enrich data once
    icd_data <- enrich_icd_data(get_icd_data())

    # Filter data based on selected codes
    filtered_data <- shiny::reactive({
      codes <- selected_codes()
      if (is.null(codes) || length(codes) == 0) {
        return(icd_data[0, ])
      }
      icd_data[icd_data$code %in% codes, ]
    })

    # Prepare treemap data
    treemap_data <- shiny::reactive({
      prepare_treemap_data(filtered_data())
    })

    # Render treemap
    output$treemap_plot <- shiny::renderPlot({
      data <- treemap_data()
      if (nrow(data) == 0) {
        plot.new()
        text(0.5, 0.5, "Select ICD-10 codes to display treemap",
             cex = 1.5, col = "gray50")
        return()
      }
      render_treemap(data)
    })
  })
}
