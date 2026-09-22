#' @export
#' @importFrom dataraft.core dr_status
dr_status.dr_measurement_set <- function(x, asset = NULL, ...) {
  x <- diagnostic_measurements(x)
  return(dplyr::bind_rows(lapply(x, function(value) {
    manifest <- attr(value, "dr_manifest")
    tibble::tibble(
      engine = "dataraft",
      id = manifest$metric,
      status = "completed",
      outcome = "succeeded",
      success = TRUE,
      release_id = manifest$release_id,
      asset = manifest$product,
      message = paste(
        manifest$metric,
        "was calculated from",
        manifest$product,
        if (identical(manifest$input_published, FALSE)) {
          "using its unpublished trial input."
        } else {
          "using its pinned published input."
        }
      )
    )
  })))
}

#' @export
#' @importFrom dataraft.core dr_status
dr_status.dr_measurement <- function(x, asset = NULL, ...) {
  dr_status.dr_measurement_set(x, asset, ...)
}

#' @export
#' @importFrom dataraft.core dr_quality
dr_quality.dr_measurement_set <- function(x, run_id = NULL, asset = NULL, release = NULL, ...) {
  measurement_quality(x)
}

#' @export
#' @importFrom dataraft.core dr_quality
dr_quality.dr_measurement <- function(x, run_id = NULL, asset = NULL, release = NULL, ...) {
  measurement_quality(list(x))
}

#' @export
#' @importFrom dataraft.core dr_lineage_edges
dr_lineage_edges.dr_measurement_set <- function(x, ...) {
  x <- diagnostic_measurements(x)
  edges <- unique(dplyr::bind_rows(lapply(x, function(value) {
    manifest <- attr(value, "dr_manifest")
    tibble::tibble(
      run_id = NA_character_,
      from_id = manifest$product,
      from_version = manifest$release_id,
      to_id = manifest$metric,
      to_version = manifest$metric_version,
      relation = "measured_from"
    )
  })))
  edges
}

#' @export
#' @importFrom dataraft.core dr_lineage_edges
dr_lineage_edges.dr_measurement <- function(x, ...) {
  dr_lineage_edges.dr_measurement_set(x, ...)
}

