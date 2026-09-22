# replay input format preserves supported selections without code

    Code
      report_input_encode(list(f = identity))
    Condition
      Error in `FUN()`:
      ! Replay inputs must be finite atomic vectors or plain lists.

# SQL export binding detects drift without claiming equivalence

    Code
      dr_commons_yaml(metric, "reserves", "AVG(reserve)", path, expected_binding = binding)
    Condition
      Error in `dr_commons_yaml()`:
      ! Metric/SQL binding changed. Review both definitions before exporting.

