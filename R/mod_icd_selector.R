#' ICD Selector Module UI
#'
#' Creates a virtual select input for choosing ICD-10 codes.
#' Uses virtualSelectInput for performance with 40k+ items.
#'
#' @param id Module namespace id
#' @return Shiny UI tag list
#' @export
mod_icd_selector_ui <- function(id) {
  ns <- shiny::NS(id)

  shiny::tagList(
    shinyWidgets::virtualSelectInput(
      inputId = ns("icd_codes"),
      label = "Select ICD-10 codes:",
      choices = NULL,
      multiple = TRUE,
      search = TRUE,
      placeholder = "Search and select codes...",
      showValueAsTags = TRUE,
      searchPlaceholderText = "Type to search (code or description)...",
      noOptionsText = "No matching codes",
      noSearchResultsText = "No results found",
      selectAllOnlyVisible = TRUE,
      optionsSelectedText = "codes selected",
      allOptionsSelectedText = "All codes selected",
      showSelectedOptionsFirst = TRUE,
      zIndex = 9999,
      position = "bottom"
    )
  )
}

#' ICD Selector Module Server
#'
#' Server logic for ICD code selector. Loads ICD data and updates
#' virtualSelectInput choices.
#'
#' @param id Module namespace id
#' @return Reactive expression returning vector of selected ICD codes
#' @export
mod_icd_selector_server <- function(id) {
  shiny::moduleServer(id, function(input, output, session) {
    # Load ICD data once
    icd_data <- get_icd_data()
    choices <- format_icd_choices(icd_data)

    # Update choices in virtualSelectInput
    shinyWidgets::updateVirtualSelect(
      session = session,
      inputId = "icd_codes",
      choices = choices
    )

    # Return reactive with selected codes
    shiny::reactive({
      input$icd_codes
    })
  })
}
