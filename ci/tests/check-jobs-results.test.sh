#!/usr/bin/env bash
# check-jobs.yml - 'Check status of all required jobs'
#
# This gate is the one check a ruleset requires, so the case that matters most is
# not a failure it catches but a pass it hands out: every assertion here that
# expects a non-zero status is guarding against the check going green while the
# pipeline underneath it did not.

# shellcheck source=ci/tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

BLOCK=$(extract_run check-jobs.yml check-jobs 'Check status of all required jobs')

# The needs context as Actions serialises it: one entry per job, each with its
# result and its outputs.
needs_json() {
  local out="{" first=1 pair job result
  for pair in "$@"; do
    job=${pair%%=*}
    result=${pair#*=}
    [ "$first" -eq 1 ] || out+=","
    first=0
    out+="\"$job\":{\"result\":\"$result\",\"outputs\":{}}"
  done
  printf '%s}' "$out"
}

jobs_env() {
  NEEDS=$(needs_json "$@")
  export NEEDS
  export ALLOW_SKIPPED="true"
}

test_passes_when_every_job_succeeded() {
  jobs_env lint=success test=success build=success

  run_block "$BLOCK"

  assert_status 0
  assert_output_contains "All 3 jobs passed or were skipped."
}

test_fails_and_names_the_job_that_did_not() {
  jobs_env lint=success test=failure build=success

  run_block "$BLOCK"

  assert_status 1
  assert_output_contains "test (failure)"
  assert_output_contains "1 of 3 jobs did not pass"
}

test_names_every_failing_job_not_only_the_first() {
  jobs_env lint=failure test=failure build=success cross=timed_out

  run_block "$BLOCK"

  assert_status 1
  # Stopping at the first failure sends somebody back to the log for the rest,
  # and a run with three broken jobs is a different problem from one with one.
  assert_output_contains "3 of 4 jobs did not pass"
  assert_output_contains "lint (failure)"
  assert_output_contains "test (failure)"
  assert_output_contains "cross (timed_out)"
}

test_a_skipped_job_is_the_ordinary_answer_under_a_path_filter() {
  jobs_env changes=success lint=skipped test=success

  run_block "$BLOCK"

  # The whole reason this gate exists: the set of jobs that run varies, so a
  # skipped job cannot be a failure or nothing could be required at all.
  assert_status 0
  assert_output_contains "lint job result: skipped"
}

test_a_skipped_job_fails_when_the_caller_says_every_job_must_run() {
  jobs_env lint=success test=skipped
  export ALLOW_SKIPPED="false"

  run_block "$BLOCK"

  assert_status 1
  assert_output_contains "test (skipped, and ALLOW_SKIPPED is false)"
}

test_a_cancellation_is_reported_as_one() {
  jobs_env lint=success test=cancelled

  run_block "$BLOCK"

  assert_status 1
  # Named rather than folded into "did not pass": somebody pressing a button and
  # a job that broke are not read the same way.
  assert_output_contains "test (cancelled)"
}

test_an_empty_context_fails_instead_of_passing_vacuously() {
  export NEEDS="{}"
  export ALLOW_SKIPPED="true"

  run_block "$BLOCK"

  # A caller that forgets `needs:` gets {}, the loop runs zero times, and the
  # one check a ruleset requires reports success having verified nothing. This
  # is the failure mode the gate is least able to survive.
  assert_status 1
  assert_output_contains "there are no jobs to check"
  assert_output_contains "through toJson"
  assert_output_lacks "All 0 jobs"
}

test_an_unset_context_fails_the_same_way() {
  export NEEDS=""
  export ALLOW_SKIPPED="true"

  run_block "$BLOCK"

  assert_status 1
  assert_output_contains "there are no jobs to check"
}

test_something_that_is_not_a_needs_object_fails() {
  export NEEDS='["lint", "test"]'
  export ALLOW_SKIPPED="true"

  run_block "$BLOCK"

  # An array parses as JSON and yields no entries, so type has to be checked
  # rather than parseability.
  assert_status 1
  assert_output_contains "not a JSON object"
}

run_tests
