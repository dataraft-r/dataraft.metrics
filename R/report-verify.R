# Capture only reproducibility metadata, never connection strings or process env.
report_environment <- function(lake = NULL) {
  packages <- c(
    "dataraft.core",
    "dataraft.metrics",
    "dataraft.lake",
    "DBI",
    "duckdb",
    "dbplyr",
    "dplyr",
    "rlang",
    "tibble",
    "digest",
    "jsonlite"
  )
  versions <- stats::setNames(
    lapply(packages, function(package) {
      tryCatch(
        as.character(utils::packageVersion(package)),
        error = function(e) NA_character_
      )
    }),
    packages
  )
  list(
    R = as.character(getRversion()),
    platform = R.version$platform,
    packages = versions,
    engine = if (is.null(lake)) {
      "R"
    } else {
      tryCatch(
        as.character(DBI::dbGetQuery(
          lake$con,
          "SELECT version() AS version"
        )$version[[1]]),
        error = function(e) "unknown"
      )
    },
    locale = Sys.getlocale(),
    timezone = Sys.timezone(),
    TZ = Sys.getenv("TZ", unset = NA_character_),
    rng_kind = RNGkind(),
    rng_seed = if (
      exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    ) {
      get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    } else {
      NULL
    }
  )
}

# A small data-only format. No unserialize(), eval(), or user-selected classes.
report_input_encode <- function(x) {
  if (is.null(x)) {
    return(list(type = "NULL"))
  }
  if (is.list(x) && !is.object(x)) {
    return(list(
      type = "list",
      names = names(x),
      values = lapply(x, report_input_encode)
    ))
  }
  allowed <- c("logical", "integer", "numeric", "character", "Date", "POSIXct")
  type <- if (inherits(x, "POSIXct")) "POSIXct" else class(x)[[1]]
  if (
    !type %in% allowed ||
      !is.null(dim(x)) ||
      anyNA(x) ||
      (is.numeric(x) && any(!is.finite(x)))
  ) {
    stop("Replay inputs must be finite atomic vectors or plain lists.")
  }
  list(
    type = type,
    names = names(x),
    values = unname(unclass(x)),
    timezone = if (type == "POSIXct") attr(x, "tzone") else NULL
  )
}

report_input_decode <- function(x) {
  values <- unlist(x$values, use.names = FALSE)
  result <- switch(
    x$type,
    NULL = NULL,
    list = lapply(x$values, report_input_decode),
    logical = as.logical(values),
    integer = as.integer(values),
    numeric = as.double(values),
    character = as.character(values),
    Date = as.Date(as.double(values), origin = "1970-01-01"),
    POSIXct = as.POSIXct(
      as.double(values),
      origin = "1970-01-01",
      tz = unlist(x$timezone, use.names = FALSE) %||% ""
    ),
    stop("Unsupported replay input type.")
  )
  if (!is.null(x$names)) {
    names(result) <- unlist(x$names, use.names = FALSE)
  }
  result
}

report_rng_restore <- function(kind, seed) {
  do.call(RNGkind, as.list(kind))
  if (is.null(seed)) {
    if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
  } else {
    assign(".Random.seed", as.integer(seed), envir = .GlobalEnv)
  }
}

#' Verify saved evidence and replay trusted metric definitions
#'
#' Checks stored numerical hashes, then optionally recalculates each measure on
#' its exact input release. Supply original approved metric objects: stored code
#' is never evaluated. Verification writes neither reports nor metric registry
#' entries. A result match demonstrates this execution only, not universal
#' reproducibility of external services, SQL random functions or custom code.
#'
#' Runtime evidence records R and computation package versions, database engine,
#' locale, timezone and the R random generator state immediately before execution.
#' Replay restores that R generator state temporarily; it does not install old
#' packages or change locale or timezone. Additional packages, external resources,
#' database settings and SQL random generators used by custom computations remain
#' the caller's responsibility. Reports created before runtime capture, and inputs
#' with unsupported classes, have no automatic replay evidence.
#' @param lake Connected lake, configuration or local lake folder.
#' @param id Immutable report id.
#' @param metrics Original metric object or list of metric objects. Definitions
#'   must exactly match the saved hash, identity and approval. `NULL` checks only
#'   stored numerical integrity and explicitly reports replay as unavailable.
#' @param strict_environment Skip replay when runtime versions, engine, locale or
#'   timezone differ. RNG state is restored separately and excluded from this
#'   comparison. With `FALSE`, replay can match despite environment differences.
#' @return A tibble with one row per measure. `integrity` checks saved values;
#'   `environment` is `match`, `mismatch` or `unavailable`; `replay` is `match`,
#'   `mismatch`, `unavailable` or `error`. `reason` explains an unavailable or
#'   failed replay without exposing custom computation error messages.
#' @export
#' @examples
#' # dr_report_verify(lake, "report.v1", metrics = original_metric)
dr_report_verify <- function(
  lake,
  id,
  metrics = NULL,
  strict_environment = TRUE
) {
  dataraft.core::dr_internal_flag(strict_environment, "strict_environment")
  if (!inherits(lake, "dr_lake")) {
    lake <- report_connection(lake, read_only = TRUE)
    on.exit(optional_lake("dr_disconnect_lake")(lake), add = TRUE)
  }
  saved <- dr_report_read(lake, id)
  if (inherits(metrics, "dr_metric")) {
    metrics <- list(metrics)
  }
  if (
    !is.null(metrics) &&
      (!is.list(metrics) ||
        !all(vapply(metrics, inherits, logical(1), "dr_metric")))
  ) {
    dataraft.core::dr_internal_abort(
      "metrics must contain original metric objects.",
      subclass = "dr_report_definition_invalid"
    )
  }
  current <- report_environment(lake)
  original_kind <- RNGkind()
  original_seed <- current$rng_seed
  on.exit(report_rng_restore(original_kind, original_seed), add = TRUE)
  rows <- lapply(names(saved$measures), function(name) {
    measure <- saved$measures[[name]]
    m <- measure$manifest
    row <- tibble::tibble(
      measure = name,
      metric = m$metric,
      release_id = m$release_id,
      integrity = "mismatch",
      environment = "unavailable",
      replay = "unavailable",
      reason = ""
    )
    # The JSON values are already the canonical column representation.
    if (identical(report_fingerprint(measure$values), m$result_hash)) {
      row$integrity <- "match"
    } else {
      row$reason <- "stored_result_hash_mismatch"
      return(row)
    }
    if (is.null(m$fingerprint_format) || m$fingerprint_format != 3L) {
      row$reason <- "unsupported_definition_fingerprint_format"
      return(row)
    }
    if (is.null(m$execution) || is.null(m$replay_inputs)) {
      row$reason <- "replay_evidence_unavailable"
      return(row)
    }
    if (
      !identical(report_fingerprint(m$execution), m$environment_fingerprint)
    ) {
      row$reason <- "environment_evidence_hash_mismatch"
      return(row)
    }
    previous <- m$execution
    previous$rng_seed <- NULL
    comparison <- current
    comparison$rng_seed <- NULL
    row$environment <- if (
      identical(report_fingerprint(previous), report_fingerprint(comparison))
    ) {
      "match"
    } else {
      "mismatch"
    }
    candidates <- Filter(
      function(metric) {
        identical(metric$id, m$metric) &&
          identical(metric$version, m$metric_version) &&
          isTRUE(metric$approved) &&
          identical(fingerprint(metric), m$metric_hash)
      },
      metrics
    )
    if (length(candidates) != 1L) {
      row$reason <- "original_definition_unavailable_or_changed"
      return(row)
    }
    if (strict_environment && row$environment != "match") {
      row$reason <- paste0("environment_", row$environment)
      return(row)
    }
    result <- tryCatch(
      {
        report_rng_restore(
          unlist(m$execution$rng_kind, use.names = FALSE),
          unlist(m$execution$rng_seed, use.names = FALSE)
        )
        inputs <- report_input_decode(m$replay_inputs)
        # Reject unexpected argument injection in modified manifests.
        if (!identical(names(inputs), c("by", "at", "filters", "params"))) {
          stop("Invalid replay arguments.")
        }
        do.call(
          dr_measure,
          c(
            list(
              x = lake,
              metric = candidates[[1]],
              release = m$release_id,
              record = FALSE
            ),
            inputs
          )
        )
      },
      error = function(e) NULL
    )
    if (is.null(result)) {
      row$replay <- "error"
      row$reason <- "recalculation_failed"
    } else {
      row$replay <- if (
        identical(attr(result, "dr_manifest")$result_hash, m$result_hash)
      ) {
        "match"
      } else {
        "mismatch"
      }
      if (row$replay == "mismatch") {
        row$reason <- "recalculated_result_hash_mismatch"
      }
    }
    row
  })
  dplyr::bind_rows(rows)
}
