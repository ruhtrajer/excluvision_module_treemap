#' Treemap Module UI
#'
#' @param id Module namespace id
#' @return Shiny UI tag list
#' @export
mod_treemap_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    r2d3::d3Output(ns("treemap_d3"), height = "500px")
  )
}

#' Treemap Module Server
#'
#' @param id Module namespace id
#' @param r Shared reactiveValues object with selected_codes slot
#' @return NULL (side effects only)
#' @export
mod_treemap_server <- function(id, r) {
  shiny::moduleServer(id, function(input, output, session) {
    # Load and enrich data once
    icd_data <- enrich_icd_data(get_icd_data())

    # Filter data based on selected codes from shared reactive
    filtered_data <- shiny::reactive({
      codes <- r$selected_codes
      if (is.null(codes) || length(codes) == 0) {
        return(icd_data[0, ])
      }
      icd_data[icd_data$code %in% codes, ]
    })

    # Build hierarchy for D3
    hierarchy_data <- shiny::reactive({
      data <- filtered_data()
      if (nrow(data) == 0) {
        return(NULL)
      }
      build_treemap_hierarchy(data)
    })

    # Render D3 treemap
    output$treemap_d3 <- r2d3::renderD3({
      data <- hierarchy_data()
      if (is.null(data)) {
        # Return empty visualization with message
        return(r2d3::r2d3(
          data = list(name = "root", children = list()),
          script = app_sys("d3/treemap.js"),
          options = list(inputId = session$ns("treemap"))
        ))
      }
      r2d3::r2d3(
        data = data,
        script = app_sys("d3/treemap.js"),
        options = list(inputId = session$ns("treemap"))
      )
    })

    # Observe drill-down events from D3
    shiny::observeEvent(input$treemap_drill, {
      drill_info <- input$treemap_drill
      # Can be used for additional R-side logic if needed
    })
  })
}
