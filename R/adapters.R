#' Export an explicit declarative definition for data-dict and commons
#' @param metric Registered metric definition for business metadata.
#' @param table Physical table or governed product view name in the consumer
#'   environment.
#' @param sql_expr Explicit single-table aggregate expression, e.g.
#'   SUM(reserve).
#' @param path Output YAML file.
#' @param expected_binding Optional hash from the returned path's
#'   `definition_binding` attribute, saved after independent SQL review. A changed
#'   metric, table or SQL expression fails before writing. This does not prove
#'   equivalence of the R and SQL computations.
#' @return Path. This adapter exports metadata; it does not execute or install
#'   commons.
#' @export
#' @examplesIf requireNamespace("yaml", quietly = TRUE)
#' metric <- dr_metric(
#'   "orders.total", "orders", expr = sum(amount), time_behavior = "flow",
#'   unit = "EUR", owner = "Analytics", description = "Total order value",
#'   approved = TRUE, code_version = "v1"
#' )
#' path <- tempfile(fileext = ".yml")
#' dr_commons_yaml(metric, "orders", "SUM(amount)", path)
#' cat(readLines(path), sep = "\n")
#' unlink(path)
dr_commons_yaml <- function(
  metric,
  table,
  sql_expr,
  path,
  expected_binding = NULL
) {
  dataraft.core::dr_internal_need("yaml")
  dataraft.core::dr_internal_scalar(table, "table")
  dataraft.core::dr_internal_scalar(sql_expr, "sql_expr")
  if (grepl(";|--|/\\*", sql_expr)) {
    dataraft.core::dr_internal_abort(
      subclass = "dataraft_error_metrics",
      "Supply one expression, not a SQL statement or comments."
    )
  }
  if (!metric$approved) {
    dataraft.core::dr_internal_abort(
      subclass = "dataraft_error_metrics",
      "Export only approved metrics."
    )
  }
  # SQL is explicit: arbitrary R cannot be translated faithfully into data-dict expressions.
  x <- list(
    tables = list(list(
      name = table,
      definitions = list(list(
        name = gsub("\\.", "_", metric$id),
        label = metric$id,
        description = paste(
          metric$description,
          "Unit:",
          metric$unit,
          "Time:",
          metric$time_behavior
        ),
        expr = sql_expr
      ))
    ))
  )
  binding <- fingerprint(list(metric = metric, table = table, sql = sql_expr))
  if (!is.null(expected_binding) && !identical(expected_binding, binding)) {
    dataraft.core::dr_internal_abort(
      "Metric/SQL binding changed. Review both definitions before exporting.",
      subclass = "dr_commons_definition_drift"
    )
  }
  header <- c(
    "# DataRaft exports business metadata, not a semantic equivalence proof.",
    "# SQL equivalence: unverified; independently review or compare results.",
    paste0("# definition_binding: ", binding),
    paste0("# metric_definition_hash: ", fingerprint(metric))
  )
  writeLines(c(header, yaml::as.yaml(x)), path)
  attr(path, "definition_binding") <- binding
  invisible(path)
}
