#!/usr/bin/env bash
# update-helm-chart.yml - called mode: 'Automerge chart update PR'

# shellcheck source=ci/tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

BLOCK=$(extract_run update-helm-chart.yml update "Automerge chart update PR")

automerge_env() {
  export GH_TOKEN="app-token"
  export METADATA_TOKEN="github-token"
  export GITHUB_REPOSITORY="my-org/helm-charts"
  export PR_NUMBER="17"
  export AUTOMERGE_METHOD="auto"
  export STUB_GH_REPO_JSON='{"allow_auto_merge": true}'
}

test_fails_when_no_credential_supplied() {
  automerge_env
  export GH_TOKEN=""

  run_block "$BLOCK"

  assert_status 1 "asking to merge and silently not merging is a broken release"
  assert_output_contains "::error::Automerge is enabled but no credential was supplied"
  assert_not_called "pr merge"
}

test_queues_auto_merge_when_allowed() {
  automerge_env

  run_block "$BLOCK"

  assert_status 0
  assert_called "gh|app-token|pr merge 17 --rebase --auto"
}

test_fails_when_auto_merge_not_enabled_on_repository() {
  automerge_env
  export STUB_GH_REPO_JSON='{"allow_auto_merge": false}'

  run_block "$BLOCK"

  assert_status 1
  assert_output_contains "requires 'Allow auto-merge'"
  assert_not_called "pr merge"
}

test_admin_force_merges_and_warns() {
  automerge_env
  export AUTOMERGE_METHOD="admin"

  run_block "$BLOCK"

  assert_status 0
  assert_output_contains "::warning::Force-merging PR #17"
  assert_called "gh|app-token|pr merge 17 --rebase --admin"
  assert_not_called "api repos/"
}

test_reads_repository_metadata_with_the_builtin_token() {
  automerge_env

  run_block "$BLOCK"

  assert_status 0
  assert_called "gh|github-token|api repos/my-org/helm-charts"
}

test_propagates_a_failed_merge() {
  automerge_env
  export STUB_GH_FAIL_ON="pr merge"
  export STUB_GH_FAIL_MESSAGE="pull request is not mergeable"

  run_block "$BLOCK"

  assert_status 1
}

test_gate_reads_the_resolved_flow_not_the_input() {
  # Structural: the step's `if:` must gate on the bump step's EFFECTIVE_TYPE
  # output. Under UPGRADE_TYPE=auto the input never says 'prerelease' even
  # when the bump is one, so an input-based gate would route every rc bump
  # through AUTOMERGE_RELEASE - inverting the standard "automerge the noisy
  # rc bumps, review the real releases" configuration.
  local gate
  gate=$(yq '.jobs.update.steps[] | select(.name == "Automerge chart update PR") | .if' \
    "$WORKFLOWS_DIR/update-helm-chart.yml")

  case "$gate" in
    *"steps.update-chart.outputs.EFFECTIVE_TYPE"*) ;;
    *)
      printf 'FAIL: the automerge gate does not read the resolved flow:\n%s\n' "$gate" >&2
      exit 1
      ;;
  esac

  case "$gate" in
    *"inputs.UPGRADE_TYPE"*)
      printf 'FAIL: the automerge gate still reads the raw input:\n%s\n' "$gate" >&2
      exit 1
      ;;
  esac
}

run_tests
