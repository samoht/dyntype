open OUnit
open Printf

let suites = [
  Test_value.suite;
  Test_type.suite;
]

let _ =
  let s = suites in
  run_test_tt_main ("Dyntype" >::: (List.flatten s))
