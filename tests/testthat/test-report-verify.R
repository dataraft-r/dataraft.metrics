test_that("replay input format preserves supported selections without code", {
  inputs <- list(
    by = c("company", "region"),
    at = as.Date("2026-09-01"),
    filters = list(x = c(1L, 2L)),
    params = list(when = as.POSIXct("2026-09-01", tz = "UTC"))
  )
  expect_identical(
    report_input_decode(jdecode(report_json(report_input_encode(inputs)))),
    inputs
  )
  expect_snapshot(error = TRUE, report_input_encode(list(f = identity)))
})

test_that("report verification pins input and preserves report and random state", {
  f <- fixture()
  on.exit(fixture_cleanup(f))
  dr_run(f$pipeline, f$lake)
  metric <- reserve_metric()
  value <- dr_measure(f$lake, metric, at = as.Date("2026-08-31"))
  dr_report_release(f$lake, "verify", list(total = value), "v1")
  before <- dr_report_read(f$lake, "verify")
  changed <- f$good
  changed$reserve <- changed$reserve * 2
  f$write(changed)
  dr_run(f$pipeline, f$lake)
  withr::local_seed(79)
  seed <- .Random.seed
  result <- dr_report_verify(f$lake, "verify", metric)
  expect_identical(result$integrity, "match")
  expect_identical(result$environment, "match")
  expect_identical(result$replay, "match")
  expect_identical(.Random.seed, seed)
  expect_identical(dr_report_read(f$lake, "verify"), before)
  expect_identical(
    dr_report_verify(f$lake, "verify")$reason,
    "original_definition_unavailable_or_changed"
  )
  metric$code_version <- "changed"
  expect_identical(
    dr_report_verify(f$lake, "verify", metric)$reason,
    "original_definition_unavailable_or_changed"
  )
})

test_that("environment differences and value corruption are separate outcomes", {
  f <- fixture()
  on.exit(fixture_cleanup(f))
  dr_run(f$pipeline, f$lake)
  metric <- reserve_metric()
  value <- dr_measure(f$lake, metric, at = as.Date("2026-08-31"))
  dr_report_release(f$lake, "verify", list(total = value), "v1")
  original_environment <- report_environment
  local_mocked_bindings(report_environment = function(lake = NULL) {
    env <- original_environment(lake)
    env$R <- "different"
    env
  })
  strict <- dr_report_verify(f$lake, "verify", metric)
  expect_identical(strict$reason, "environment_mismatch")
  permissive <- dr_report_verify(
    f$lake,
    "verify",
    metric,
    strict_environment = FALSE
  )
  expect_identical(permissive$environment, "mismatch")
  expect_identical(permissive$replay, "match")
  original_read <- dr_report_read
  local_mocked_bindings(dr_report_read = function(...) {
    manifest <- original_read(...)
    manifest$measures$total$values$value <- -123
    manifest
  })
  expect_identical(
    dr_report_verify(f$lake, "verify", metric)$integrity,
    "mismatch"
  )
})

test_that("SQL export binding detects drift without claiming equivalence", {
  skip_if_not_installed("yaml")
  path <- tempfile(fileext = ".yaml")
  on.exit(unlink(path))
  metric <- reserve_metric()
  exported <- dr_commons_yaml(metric, "reserves", "SUM(reserve)", path)
  binding <- attr(exported, "definition_binding")
  expect_match(readLines(path)[2], "equivalence: unverified")
  expect_identical(
    attr(
      dr_commons_yaml(
        metric,
        "reserves",
        "SUM(reserve)",
        path,
        expected_binding = binding
      ),
      "definition_binding"
    ),
    binding
  )
  expect_snapshot(
    error = TRUE,
    dr_commons_yaml(
      metric,
      "reserves",
      "AVG(reserve)",
      path,
      expected_binding = binding
    )
  )
})


test_that("random replay restores the captured seed and caller state on failure", {
  f <- fixture()
  on.exit(fixture_cleanup(f))
  dr_run(f$pipeline, f$lake)
  metric <- dr_metric(
    "random",
    "risk.validated",
    approved = TRUE,
    code_version = "v1",
    compute = function(data, dimensions, params) {
      if (isTRUE(getOption("dataraft.test.fail"))) {
        stop("private error text")
      }
      data.frame(value = stats::runif(1) + getOption("dataraft.test.offset", 0))
    }
  )
  withr::local_seed(17)
  value <- dr_measure(f$lake, metric)
  dr_report_release(f$lake, "random", list(total = value), "v1")
  seed <- .Random.seed
  expect_identical(dr_report_verify(f$lake, "random", metric)$replay, "match")
  expect_identical(.Random.seed, seed)
  withr::local_options(dataraft.test.offset = 1)
  mismatch <- dr_report_verify(f$lake, "random", metric)
  expect_identical(mismatch$integrity, "match")
  expect_identical(mismatch$replay, "mismatch")
  expect_identical(.Random.seed, seed)
  withr::local_options(dataraft.test.fail = TRUE)
  failed <- dr_report_verify(f$lake, "random", metric)
  expect_identical(failed$replay, "error")
  expect_identical(failed$reason, "recalculation_failed")
  expect_identical(.Random.seed, seed)
})

test_that("legacy evidence does not masquerade as replayable", {
  f <- fixture()
  on.exit(fixture_cleanup(f))
  dr_run(f$pipeline, f$lake)
  metric <- reserve_metric()
  value <- dr_measure(f$lake, metric, at = as.Date("2026-08-31"))
  attr(value, "dr_manifest")$execution <- NULL
  attr(value, "dr_manifest")$replay_inputs <- NULL
  dr_report_release(f$lake, "legacy", list(total = value), "v1")
  result <- dr_report_verify(f$lake, "legacy", metric)
  expect_identical(result$integrity, "match")
  expect_identical(result$replay, "unavailable")
  expect_identical(result$reason, "replay_evidence_unavailable")
})


test_that("legacy closure fingerprint formats are explicitly unsupported", {
  f <- fixture()
  on.exit(fixture_cleanup(f))
  dr_run(f$pipeline, f$lake)
  metric <- reserve_metric()
  value <- dr_measure(f$lake, metric, at = as.Date("2026-08-31"))
  attr(value, "dr_manifest")$fingerprint_format <- NULL
  dr_report_release(f$lake, "old-hash", list(total = value), "v1")
  result <- dr_report_verify(f$lake, "old-hash", metric)
  expect_identical(result$integrity, "match")
  expect_identical(result$reason, "unsupported_definition_fingerprint_format")
})

test_that("report retries coordinate by identity before reading or inserting", {
  f <- fixture()
  on.exit(fixture_cleanup(f))
  dr_run(f$pipeline, f$lake)
  metric <- reserve_metric()
  value <- dr_measure(f$lake, metric, at = as.Date("2026-08-31"))
  acquired <- character()
  testthat::local_mocked_bindings(
    dr_internal_acquire_lake_writer = function(lake, frame, asset) {
      acquired <<- c(acquired, asset)
      expect_type(frame, "environment")
    },
    .package = "dataraft.lake"
  )
  original_query <- getExportedValue("dataraft.lake", "dr_internal_query")
  testthat::local_mocked_bindings(
    dr_internal_query = function(lake, sql, params = NULL) {
      if (grepl("SELECT manifest FROM", sql, fixed = TRUE)) {
        expect_identical(tail(acquired, 1L), "report:coordinated")
      }
      original_query(lake, sql, params)
    },
    .package = "dataraft.lake"
  )
  first <- dr_report_release(f$lake, "coordinated", list(total = value), "v1")
  second <- dr_report_release(f$lake, "coordinated", list(total = value), "v1")
  expect_identical(first, second)
  expect_identical(acquired, rep("report:coordinated", 2L))
  expect_equal(nrow(dr_registry(f$lake, "reports")), 1L)
})
