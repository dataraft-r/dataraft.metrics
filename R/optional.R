optional_lake <- function(name) {
  dataraft.core::dr_internal_need("dataraft.lake", "This metrics operation")
  getExportedValue("dataraft.lake", name)
}
