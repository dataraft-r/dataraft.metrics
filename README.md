# dataraft.metrics

**Give recurring report numbers a definition and a traceable input.**

Use this experimental package when a report needs to retain what a measure meant, which checked release it used and the resulting value. It builds on DataRaft products and uses `dataraft.lake` for retained measurements and reports. It does not provide a general semantic modeling engine.

[`dataraft` overview](https://github.com/dataraft-r/dataraft) · [Metrics reference](https://dataraft-r.github.io/dataraft/components/dataraft.metrics/reference/index.html)

## Install

Requires R 4.2 or later. Install the development package from GitHub:

```r
install.packages("pak")
pak::pak("dataraft-r/dataraft.metrics")
```

## Define a measure

```r
library(dataraft.metrics)

reserve <- dr_metric(
  "risk.reserve",
  "risk.validated",
  expr = sum(reserve, na.rm = TRUE),
  dimensions = "company",
  time_column = "date",
  unit = "EUR",
  owner = "Risk",
  approved = TRUE,
  code_version = "metric-v1"
)
print(reserve)
```

The product `risk.validated` must exist as a checked release in a lake before you can evaluate this definition with `dr_measure(lake, reserve, at = as.Date("2026-08-31"))`. Approval is an explicit business declaration, not an automatic quality check. For a complete input-to-report workflow, see the [metrics guide](https://dataraft-r.github.io/dataraft/components/dataraft.metrics/reference/index.html) and the [DataRaft introduction](https://github.com/dataraft-r/dataraft).

## Further details

This component is not a full semantic layer: joins, time grains, additivity and
SQL semantics remain with the data product or an external semantic system.
`dr_commons_yaml()` exports explicit SQL with an unverified equivalence marker
and a definition binding; retaining that binding detects later definition drift.

`dr_report_verify(lake, "report.v1", metrics = original_metric)` compares saved
values with their hash and recalculates against the pinned input release using
a trusted original definition. It reports numerical integrity, environment
compatibility and replay results separately. Runtime metadata includes R,
computation package versions, DuckDB engine, locale, timezone and R RNG state.
Custom package dependencies, external services and database RNG state require
separate management. Matching hashes are integrity checks, not cryptographic
proof against an actor who can rewrite both evidence and hashes.
