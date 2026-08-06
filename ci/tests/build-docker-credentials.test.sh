#!/usr/bin/env bash
# build-docker.yml - 'Validate credentials'
#
# The build secret is readable by everything the Dockerfile executes, and only
# the App path can be narrowed by the workflow. Each mode must therefore fail
# rather than widen to the next credential on its own.

# shellcheck source=ci/tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

BLOCK=$(extract_run build-docker.yml build "Validate credentials")

creds_env() {
  export HAS_PARTIAL_APP_AUTH="false"
  export HAS_APP_AUTH="false"
  export HAS_PAT="false"
  export BUILD_SECRET_GITHUB_TOKEN="none"
}

test_default_mode_needs_no_credential() {
  creds_env

  run_block "$BLOCK"

  assert_status 0 "'none' must work with no secrets configured at all"
  assert_output_lacks "::warning::"
}

test_rejects_an_unknown_mode() {
  creds_env
  export BUILD_SECRET_GITHUB_TOKEN="true"

  run_block "$BLOCK"

  # 'true' was the old boolean spelling; it must fail loudly rather than be
  # coerced into injecting something.
  assert_status 1
  assert_output_contains "must be 'none', 'app', 'pat' or 'job-token'"
}

test_app_mode_requires_app_credentials() {
  creds_env
  export BUILD_SECRET_GITHUB_TOKEN="app"

  run_block "$BLOCK"

  assert_status 1 "'app' must never silently fall back to a token it cannot narrow"
  assert_output_contains "requires APP_CLIENT_ID and APP_PRIVATE_KEY"
}

test_app_mode_accepts_app_credentials() {
  creds_env
  export BUILD_SECRET_GITHUB_TOKEN="app"
  export HAS_APP_AUTH="true"

  run_block "$BLOCK"

  assert_status 0
}

test_app_mode_does_not_accept_a_pat_instead() {
  creds_env
  export BUILD_SECRET_GITHUB_TOKEN="app"
  export HAS_PAT="true"

  run_block "$BLOCK"

  assert_status 1 "a PAT cannot be narrowed, so 'app' must not accept one"
}

test_pat_mode_accepts_either_credential() {
  creds_env
  export BUILD_SECRET_GITHUB_TOKEN="pat"
  export HAS_PAT="true"

  run_block "$BLOCK"

  assert_status 0

  creds_env
  export BUILD_SECRET_GITHUB_TOKEN="pat"
  export HAS_APP_AUTH="true"

  run_block "$BLOCK"

  assert_status 0
}

test_pat_mode_refuses_to_fall_back_to_the_job_token() {
  creds_env
  export BUILD_SECRET_GITHUB_TOKEN="pat"

  run_block "$BLOCK"

  assert_status 1 "'pat' must not reach GITHUB_TOKEN, which carries packages:write"
  assert_output_contains "requires APP_CLIENT_ID/APP_PRIVATE_KEY or GH_PAT"
}

test_job_token_mode_warns_when_it_actually_uses_the_job_token() {
  creds_env
  export BUILD_SECRET_GITHUB_TOKEN="job-token"

  run_block "$BLOCK"

  assert_status 0 "opting in explicitly is allowed"
  assert_output_contains "::warning::"
  assert_output_contains "packages: write"
}

test_job_token_mode_is_quiet_when_a_narrower_credential_answers() {
  creds_env
  export BUILD_SECRET_GITHUB_TOKEN="job-token"
  export HAS_APP_AUTH="true"

  run_block "$BLOCK"

  assert_status 0
  # The App token wins, so there is nothing to warn about.
  assert_output_lacks "::warning::"
}

test_partial_app_credentials_fail_in_every_mode() {
  local mode
  for mode in none app pat job-token; do
    creds_env
    export BUILD_SECRET_GITHUB_TOKEN="$mode"
    export HAS_PARTIAL_APP_AUTH="true"

    run_block "$BLOCK"

    assert_status 1 "mode '$mode' must reject half-configured App credentials"
    assert_output_contains "must be supplied together"
  done
}

run_tests
