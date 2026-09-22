# dataraft.metrics 0.1.0.9000

* Keep stateless helpers private and prefix shared implementation interfaces with `dr_internal_`. Move component tests into their owning repository; add minimal and downstream CI.

* Explain the required date column for stock metrics and test metric definitions independently.

* Initial independent DataRaft package.

* Require lake/dbt integrations only when those optional operations are used.

* `dr_commons_yaml()` records an explicit unverified SQL equivalence status and
  accepts a saved definition binding to reject metric/SQL drift before export.
* `dr_measure()` captures runtime metadata and data-only replay arguments.
* `dr_report_verify()` checks stored numerical integrity and replays original
  approved definitions against pinned releases, reporting environment differences
  separately and restoring caller RNG state without changing saved evidence.

* `dr_report_release()` coordinates concurrent PostgreSQL issuance by report ID,
  keeping identical retries idempotent without locking metric calculation.
