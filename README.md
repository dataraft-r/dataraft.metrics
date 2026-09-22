# dataraft.metrics

**Experimental: governed metrics and frozen report evidence.**

Define metrics with `dr_metric()`, evaluate them with `dr_measure()` and retain report evidence. Persisted measurements and reports use dataraft.lake.

This is an independently installable DataRaft component. The `dataraft`
metapackage provides the shared introduction and re-exports the family API.
See `help(package = "dataraft.metrics")` for the component reference.

Install the development version:

```r
install.packages("pak")
pak::pak("dataraft-r/dataraft.metrics")
```

[Get started with DataRaft](https://github.com/dataraft-r/dataraft).

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
