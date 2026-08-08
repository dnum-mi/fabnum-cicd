#!/usr/bin/env bash
# dispatch-helm-chart.yml - input validation, coordinate resolution and the
# cross-repository dispatch.

# shellcheck source=ci/tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

VALIDATE=$(extract_run dispatch-helm-chart.yml dispatch "Validate inputs")
RESOLVE=$(extract_run dispatch-helm-chart.yml dispatch "Resolve chart repository coordinates")
DISPATCH=$(extract_run dispatch-helm-chart.yml dispatch "Trigger helm-charts update")

validate_env() {
  export HAS_PARTIAL_APP_AUTH="false"
  export CHART_REPO="my-org/helm-charts"
  export AUTOMERGE_METHOD="auto"
  export BASE_BRANCH="main"
}

dispatch_env() {
  export GH_TOKEN="app-token"
  export CHART_DIR="./charts/"
  export CHART_REPO="my-org/helm-charts"
  export WORKFLOW_NAME="update-app-version.yml"
  export CHART_NAME="my-app"
  export APP_VERSION="1.4.0"
  export UPGRADE_TYPE="minor"
  export PRERELEASE_IDENTIFIER="rc"
  export AUTOMERGE_PRERELEASE="false"
  export AUTOMERGE_RELEASE="true"
  export AUTOMERGE_METHOD="auto"
  export BASE_BRANCH="main"
}

test_validate_accepts_a_well_formed_configuration() {
  validate_env

  run_block "$VALIDATE"

  assert_status 0
}

test_validate_rejects_half_configured_app_credentials() {
  validate_env
  export HAS_PARTIAL_APP_AUTH="true"

  run_block "$VALIDATE"

  assert_status 1 "one App secret without the other must fail, not downgrade silently"
  assert_output_contains "must be supplied together"
}

test_validate_rejects_missing_chart_repo() {
  validate_env
  export CHART_REPO=""

  run_block "$VALIDATE"

  assert_status 1
  assert_output_contains "CHART_REPO is required"
}

test_validate_rejects_chart_repo_with_a_trailing_newline_payload() {
  validate_env
  # `grep -Eq` matched line by line, so a well-formed first line let anything
  # follow it. The owner is split off this value and handed to the token mint.
  export CHART_REPO='my-org/helm-charts
evil'

  run_block "$VALIDATE"

  assert_status 1 "a multi-line CHART_REPO must not pass validation"
  assert_output_contains "CHART_REPO must be"
}

test_validate_rejects_chart_repo_without_owner() {
  validate_env
  # Without a slash both ${CHART_REPO%%/*} and ${CHART_REPO##*/} yield the same
  # string, so the App token would be minted for an owner named after the repo.
  export CHART_REPO="helm-charts"

  run_block "$VALIDATE"

  assert_status 1
  assert_output_contains "CHART_REPO must be"
}

test_validate_rejects_chart_repo_with_extra_path_segments() {
  validate_env
  export CHART_REPO="my-org/group/helm-charts"

  run_block "$VALIDATE"

  assert_status 1
  assert_output_contains "CHART_REPO must be"
}

test_validate_rejects_unknown_automerge_method() {
  validate_env
  export AUTOMERGE_METHOD="force"

  run_block "$VALIDATE"

  assert_status 1 "an unrecognised merge method must fail closed"
  assert_output_contains "must be 'auto' or 'admin'"
}

test_validate_rejects_base_branch_with_whitespace() {
  validate_env
  # BASE_BRANCH becomes `gh workflow run --ref`'s value verbatim; a value with
  # embedded whitespace is always a caller mistake.
  export BASE_BRANCH="main evil"

  run_block "$VALIDATE"

  assert_status 1 "a BASE_BRANCH with embedded whitespace must fail closed"
  assert_output_contains "BASE_BRANCH must be"
}

test_resolve_splits_owner_and_repository() {
  export CHART_REPO="my-org/helm-charts"

  run_block "$RESOLVE"

  assert_status 0
  assert_file_contains "$GITHUB_OUTPUT" "owner=my-org"
  assert_file_contains "$GITHUB_OUTPUT" "name=helm-charts"
}

test_resolve_never_writes_a_token_to_github_output() {
  export CHART_REPO="my-org/helm-charts"

  run_block "$RESOLVE"

  assert_status 0
  # Only the two non-secret coordinates belong in GITHUB_OUTPUT.
  [ "$(wc -l <"$GITHUB_OUTPUT")" -eq 2 ] || {
    printf 'FAIL: unexpected GITHUB_OUTPUT contents\n%s\n' "$(cat "$GITHUB_OUTPUT")" >&2
    exit 1
  }
}

test_dispatch_fails_without_a_credential() {
  dispatch_env
  export GH_TOKEN=""

  run_block "$DISPATCH"

  assert_status 1 "GITHUB_TOKEN cannot dispatch across repositories, so this must fail loudly"
  assert_output_contains "::error::Dispatching a workflow in another repository"
  assert_not_called "workflow "
}

test_dispatch_forwards_automerge_method() {
  dispatch_env
  export AUTOMERGE_METHOD="admin"

  run_block "$DISPATCH"

  assert_status 0
  assert_called "AUTOMERGE_METHOD=admin"
  assert_output_contains "Dispatched with AUTOMERGE_METHOD=admin"
}

test_dispatch_targets_base_branch() {
  dispatch_env
  export BASE_BRANCH="develop"

  run_block "$DISPATCH"

  assert_status 0
  # Without --ref, `gh workflow run` would try to resolve CHART_REPO's default
  # branch itself via a GraphQL query this token's `actions: write` scope
  # cannot satisfy - see the comment above this dispatch in the workflow.
  assert_called "--ref develop"
}

test_dispatch_strips_trailing_slashes_from_chart_dir() {
  dispatch_env
  export CHART_DIR="./charts///"

  run_block "$DISPATCH"

  assert_status 0
  assert_called "CHART_DIR=./charts "
}

test_dispatch_retries_without_automerge_method_on_older_chart_repos() {
  dispatch_env
  # A chart repository whose entry-point workflow predates AUTOMERGE_METHOD does
  # not declare the input, and the API rejects the entire dispatch rather than
  # ignoring the extra value.
  export STUB_GH_FAIL_ON="AUTOMERGE_METHOD"
  export STUB_GH_FAIL_MESSAGE="HTTP 422: Unexpected inputs provided: [\"AUTOMERGE_METHOD\"]"

  run_block "$DISPATCH"

  assert_status 0 "an older chart repository must still get its dispatch"
  assert_output_contains "::warning::"
  assert_output_contains "does not declare an AUTOMERGE_METHOD input"
  assert_call_count "workflow " 2
  # The retry must carry everything except the rejected input - including
  # --ref, on its own separate `gh workflow run` invocation.
  assert_called "CHART_NAME=my-app"
  assert_called "RUN_MODE=called"
  assert_call_count "--ref main" 2
}

test_dispatch_does_not_retry_on_unrelated_failures() {
  dispatch_env
  export STUB_GH_FAIL_ON="workflow"
  export STUB_GH_FAIL_MESSAGE="HTTP 404: Not Found"

  run_block "$DISPATCH"

  assert_status 1 "a genuine dispatch failure must not be masked by the retry path"
  assert_output_contains "HTTP 404: Not Found"
  assert_call_count "workflow " 1
}

run_tests
