test_that("legacy and classed measurements expose identical diagnostics", {
  values <- data.frame(total = 4)
  attr(values, "dr_manifest") <- list(
    metric = "total", metric_version = "1", product = "orders",
    release_id = "rel_1", result_hash = report_fingerprint(values)
  )
  modern <- values
  class(modern) <- c("dr_measurement", class(modern))
  expect_identical(dataraft.core::dr_status(values), dataraft.core::dr_status(modern))
  expect_identical(dataraft.core::dr_quality(values), dataraft.core::dr_quality(modern))
  expect_identical(dataraft.core::dr_lineage(values), dataraft.core::dr_lineage(modern))
  expect_identical(dataraft.core::dr_lineage(modern)$to_id, "total")
})

test_that("unvalidated input supports exploration but cannot issue reports", {
  product <- dataraft.core::dr_product("orders", data.frame(amount = c(2, 3)))
  input <- dataraft.core::dr_run(product, write = FALSE, stop_on_failure = FALSE)
  expect_identical(input$status, "unvalidated")
  metric <- dr_metric("orders.total", "orders", expr = sum(amount),
    approved = TRUE, code_version = "1")
  value <- dr_measure(input, metric, record = FALSE)
  expect_equal(value$value, 5)
  manifest <- attr(value, "dr_manifest")
  expect_identical(manifest$input_published, FALSE)
  expect_identical(manifest$input_quality, "unvalidated")
  expect_identical(any(dataraft.core::dr_quality(value)$status == "unvalidated"), TRUE)
  expect_match(dataraft.core::dr_status(value)$message, "unpublished trial input")
  expect_error(dr_measure(input, metric, record = TRUE), class = "dataraft_error_metrics")
  expect_error(dr_report_release(value, "trial_report", code_version = "1"),
    class = "dataraft_error_metrics")
})
