#' @export
#' @importFrom dataraft.core dr_diagnostic_measurements
dr_diagnostic_measurements.dr_measurement_set <- function(x, ...) {
  diagnostic_measurements(x, ...)
}

#' @export
#' @importFrom dataraft.core dr_diagnostic_measurements
dr_diagnostic_measurements.data.frame <- function(x, ...) {
  diagnostic_measurements(x, ...)
}

#' @export
#' @importFrom dataraft.core dr_measurement_quality
dr_measurement_quality.dr_measurement_set <- function(x, ...) {
  measurement_quality(x, ...)
}

#' @export
#' @importFrom dataraft.core dr_measurement_quality
dr_measurement_quality.list <- function(x, ...) measurement_quality(x, ...)
