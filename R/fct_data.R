#' Load ICD-10 data from parquet
#'
#' Loads the complete ICD-10 code dataset from the package's internal
#' parquet file.
#'
#' @return A data.frame with columns: code, lib, liblong, hiera
#' @export
get_icd_data <- function() {
  nanoparquet::read_parquet(
    app_sys("extdata/cim.parquet")
  )
}

#' Load ICD-10 hierarchy lookup
#'
#' Loads the hierarchy lookup table that maps hierarchy codes to
#' diagnostic code ranges and labels.
#'
#' @return A data.frame with columns: hiera, diag_deb, diag_fin, lib
#' @export
get_hierarchy_lookup <- function() {
  env <- new.env()
  load(app_sys("extdata/cim_hiera.rda"), envir = env)
  env$cim_hiera
}

#' Format ICD data as choices for selection input
#'
#' Creates a named character vector suitable for use with selectInput
#' or virtualSelectInput. Names are formatted as "CODE - Description"
#' for searchability, values are the ICD codes.
#'
#' @param data ICD data frame with columns: code, lib
#' @return Named character vector (names = labels, values = codes)
#' @export
format_icd_choices <- function(data) {
  if (nrow(data) == 0) {
    return(character(0))
  }

  # Create labels as "CODE - Description"
  labels <- paste(data$code, "-", data$lib)

  # Create named vector: names are display labels, values are codes
  choices <- stats::setNames(data$code, labels)

  choices
}
