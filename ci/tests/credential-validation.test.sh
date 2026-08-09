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
  "release-helm.yml:release:Validate inputs"
  "scan-trivy.yml:images-scan:Validate credentials"
  "scan-trivy.yml:config-scan:Validate credentials"
  "dispatch-helm-chart.yml:dispatch:Validate inputs"
  "update-helm-chart.yml:update:Validate inputs"
)

# A superset of what any of the guards reads. Steps that do not use a value
# ignore it, which keeps this table from growing a special case per workflow.
guard_env() {
  export HAS_PARTIAL_APP_AUTH="false"
  export HAS_APP_AUTH="false"
  export HAS_PAT="false"
  export CHART_REPO="my-org/helm-charts"
  export RUN_MODE="called"
  export AUTOMERGE_METHOD="auto"
  export BASE_BRANCH="main"
  export BUILD_SECRET_GITHUB_TOKEN="none"
  # Values match the workflow defaults, so this table stays a stand-in for a
  # default invocation rather than a hand-tuned one: APP_VERSION is optional
  # and empty by default, PRERELEASE_IDENTIFIER defaults to 'rc'.
  export APP_VERSION=""
  export PRERELEASE_IDENTIFIER="rc"
  # release-helm.yml is the one deviation from "the defaults": both of its
  # distribution channels default to false, and that combination is rejected
  # by design. A valid minimal configuration is used instead, so these tests
  # keep exercising the App-credential guard rather than tripping over the
  # channel guard. The channel guard has its own tests in
  # release-helm-channels.test.sh.
  export PUBLISH_OCI="true"
  export CREATE_GITHUB_RELEASE="false"
  export REGISTRY="ghcr.io"
  export HAS_REGISTRY_AUTH="false"
  export SIGN_CHART="false"
  export SIGNING_KEY_ID=""
  export HAS_GPG_KEY="false"
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
