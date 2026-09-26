# dataraft.metrics

**Give recurring report numbers a definition and a traceable input.**

Use this experimental package when a report needs to retain what a measure meant, which checked release it used and the resulting value. It builds on DataRaft products and uses `dataraft.lake` for retained measurements and reports. It does not provide a general semantic modeling engine.

[`dataraft` overview](https://github.com/dataraft-r/dataraft) · [Metrics reference](https://dataraft-r.github.io/dataraft/packages/dataraft.metrics/)

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
```

The product `risk.validated` must exist as a checked release in a lake before you can evaluate this definition with `dr_measure(lake, reserve, at = as.Date("2026-08-31"))`. Approval is an explicit business declaration, not an automatic quality check. For a complete input-to-report workflow, see the [metrics guide](https://dataraft-r.github.io/dataraft/packages/dataraft.metrics/) and the [DataRaft introduction](https://github.com/dataraft-r/dataraft).

Install the development package with `pak::pak("dataraft-r/dataraft.metrics")`.
