test_that("metric sets retain shared defaults without evaluating data", {
  definitions <- dr_metric_set(
    "orders",
    total = sum(amount),
    count = dplyr::n(),
    dimensions = "company",
    time_column = "date",
    time_behavior = c(total = "flow", count = "stock"),
    units = c(total = "EUR")
  )
  expect_named(definitions, c("total", "count"))
  expect_identical(definitions$total$id, "orders.total")
  expect_identical(definitions$count$unit, "")
  expect_identical(definitions$total$time_behavior, "flow")
  expect_identical(definitions$count$time_behavior, "stock")
  expect_null(definitions$total$code_version)
  expect_error(dr_metric_set("orders", sum(amount)), "uniquely named")
  expect_error(
    dr_metric_set(
      "orders",
      total = sum(amount),
      time_behavior = c(other = "stock")
    ),
    "named by metric"
  )
})

test_that("stock definitions explain the required date column", {
  expect_error(
    dr_metric("balance", "orders", expr = sum(amount), time_behavior = "stock"),
    "time_column =",
    class = "dataraft_error_metrics"
  )
})
