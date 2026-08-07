#!/usr/bin/env bash
# Every job that mints a GitHub App token guards against half-configured
# credentials. The guard is duplicated across seven jobs by necessity - reusable
# workflows cannot share a script - so it is verified in one place instead.

# shellcheck source=ci/tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# <workflow>:<job>:<step name>
GUARDED_JOBS=(
  "build-docker.yml:build:Validate credentials"
  "release-app.yml:release:Validate inputs"
  "release-helm.yml:release:Validate credentials"
  "scan-trivy.yml:images-scan:Validate credentials"
  "scan-trivy.yml:config-scan:Validate credentials"
  "update-helm-chart.yml:caller:Validate inputs"
  "update-helm-chart.yml:called:Validate inputs"
)

# A superset of what any of the guards reads. Steps that do not use a value
# ignore it, which keeps this table from growing a special case per workflow.
guard_env() {
  export HAS_PARTIAL_APP_AUTH="false"
  export HAS_APP_AUTH="false"
  export HAS_PAT="false"
  export CHART_REPO="my-org/helm-charts"
  export AUTOMERGE_METHOD="auto"
  export BASE_BRANCH="main"
  export BUILD_SECRET_GITHUB_TOKEN="none"
  # Values match the workflow defaults, so this table stays a stand-in for a
  # default invocation rather than a hand-tuned one: APP_VERSION is optional
  # and empty by default, PRERELEASE_IDENTIFIER defaults to 'rc'.
  export APP_VERSION=""
  export PRERELEASE_IDENTIFIER="rc"
}

test_partial_credentials_fail_every_guarded_job() {
  local entry workflow job step block
  for entry in "${GUARDED_JOBS[@]}"; do
    IFS=: read -r workflow job step <<<"$entry"
    block=$(extract_run "$workflow" "$job" "$step")

    guard_env
    export HAS_PARTIAL_APP_AUTH="true"
    run_block "$block"

    assert_status 1 "$workflow job '$job' must reject partial App credentials"
    assert_output_contains "must be supplied together"
  done
}

test_complete_credentials_pass_every_guarded_job() {
  local entry workflow job step block
  for entry in "${GUARDED_JOBS[@]}"; do
    IFS=: read -r workflow job step <<<"$entry"
    block=$(extract_run "$workflow" "$job" "$step")

    guard_env
    run_block "$block"

    assert_status 0 "$workflow job '$job' must accept a complete configuration"
  done
}

test_absent_credentials_pass_every_guarded_job() {
  local entry workflow job step block
  for entry in "${GUARDED_JOBS[@]}"; do
    IFS=: read -r workflow job step <<<"$entry"
    block=$(extract_run "$workflow" "$job" "$step")

    # No App credentials at all is a supported mode, not a misconfiguration:
    # the workflows fall through to GH_PAT or GITHUB_TOKEN.
    guard_env
    export HAS_PARTIAL_APP_AUTH="false"
    run_block "$block"

    assert_status 0 "$workflow job '$job' must accept GH_PAT/GITHUB_TOKEN-only setups"
  done
}

run_tests
