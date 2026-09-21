# Test bindings for this package; unavailable optional packages are not loaded.
family_owners <- c(
  "dr_catalog_export" = "dataraft.catalog",
  "dr_catalog_app" = "dataraft.catalog",
  "dr_source_release" = "dataraft.lake",
  "dr_add_source" = "dataraft.core",
  "dr_set_target" = "dataraft.core",
  "dr_contract" = "dataraft.core",
  "dr_publish" = "dataraft.core",
  "dr_collect" = "dataraft.core",
  "dr_ingest" = "dataraft.lake",
  "measurement_set_table" = "dataraft.metrics",
  "print.dr_measurement_set" = "dataraft.metrics",
  "report_connection" = "dataraft.metrics",
  "dr_metric_set" = "dataraft.metrics",
  "dr_metric" = "dataraft.metrics",
  "dr_measure" = "dataraft.metrics",
  "dr_report_release" = "dataraft.metrics",
  "dr_report_read" = "dataraft.metrics",
  "dr_run" = "dataraft.core",
  "dr_product" = "dataraft.core",
  "dr_quality_reference" = "dataraft.core",
  "dr_registry" = "dataraft.lake",
  "dr_setup_lake" = "dataraft.lake",
  "dr_lake_config" = "dataraft.lake",
  "dr_connect_lake" = "dataraft.lake",
  "dr_disconnect_lake" = "dataraft.lake",
  "dr_open_lake" = "dataraft.lake",
  "dr_close_lake" = "dataraft.lake",
  "dr_write_data" = "dataraft.lake",
  "canonical" = "dataraft.core",
  "fingerprint" = "dataraft.core",
  "query" = "dataraft.lake",
  "meta" = "dataraft.lake"
)
for (name in names(family_owners)) {
  owner <- family_owners[[name]]
  if (requireNamespace(owner, quietly = TRUE)) {
    assign(name, get(name, asNamespace(owner), inherits = FALSE))
  }
}
local_family_bindings <- function(..., .package = NULL, .env = parent.frame()) {
  bindings <- list(...)
  if (
    !is.null(.package) && !.package %in% c("dataraft", unique(family_owners))
  ) {
    return(do.call(
      testthat::local_mocked_bindings,
      c(bindings, list(.package = .package, .env = .env))
    ))
  }
  owners <- unname(family_owners[names(bindings)])
  if (anyNA(owners)) {
    stop("Unknown mocked family binding")
  }
  for (owner in unique(owners)) {
    package_bindings <- bindings[owners == owner]
    aliases <- paste0("dr_internal_", names(package_bindings))
    shared <- aliases %in% getNamespaceExports(owner)
    package_bindings <- c(
      package_bindings,
      stats::setNames(package_bindings[shared], aliases[shared])
    )
    do.call(
      testthat::local_mocked_bindings,
      c(package_bindings, list(.package = owner, .env = .env))
    )
  }
}
