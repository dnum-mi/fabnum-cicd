#!/usr/bin/env bash
# update-helm-chart.yml - local mode: 'Commit and push chart bump'

# shellcheck source=ci/tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

BLOCK=$(extract_run update-helm-chart.yml update "Commit and push chart bump")

push_env() {
  export CHART_PATH="utils/helm"
  export CHART_NAME="my-app"
  export NEXT_VERSION="1.2.3"
  export GITHUB_REF_NAME="develop"
}

test_commit_carries_no_skip_ci() {
  push_env

  run_block "$BLOCK"

  assert_status 0
  # On the GITHUB_TOKEN path this push cannot trigger a new run - push or
  # pull_request - so [skip ci] would add nothing, while suppressing
  # pull_request checks for any pull request a human later opens FROM this
  # branch. On the App token path re-entry is a trade the caller opted into by
  # supplying the credentials, not one to paper over here either.
  assert_not_called "skip ci"
  assert_called "commit -m chore(chart): release my-app 1.2.3"
}

test_pushes_to_the_current_branch() {
  push_env

  run_block "$BLOCK"

  assert_status 0
  assert_called "pull --rebase origin develop"
  assert_called "push origin HEAD:develop"
}

# What this push can and cannot set off is decided by the checkout's credential,
# not by anything in the block above - so the invariant is asserted on the step
# that actually carries it.
test_the_checkout_follows_the_app_token_then_github_token() {
  # shellcheck disable=SC2016 # the Actions marker is meant to stay literal
  local token expected='${{ steps.app-token.outputs.token || github.token }}'

  token=$(yq '
    .jobs.update.steps[]
    | select(.name == "Checks-out repository")
    | .with.token
  ' "$WORKFLOWS_DIR/update-helm-chart.yml")

  # GH_PAT is deliberately absent from the precedence: it can trigger workflow
  # runs just like the App token, so folding it in would make the `local` push
  # of every caller that supplies one for `called` mode start re-entering their
  # CD pipeline without them asking for it.
  if [ "$token" != "$expected" ]; then
    printf 'FAIL: expected the checkout token to be %q, got %q\n' "$expected" "$token" >&2
    exit 1
  fi
}

test_stages_the_resolved_chart_path() {
  push_env

  run_block "$BLOCK"

  assert_status 0
  assert_called "git|add utils/helm"
}

test_pull_request_names_the_resolved_chart() {
  local title commit v
  title=$(yq '.jobs.update.steps[] | select(.id == "create-pr") | .with.title' "$WORKFLOWS_DIR/update-helm-chart.yml")
  commit=$(yq '.jobs.update.steps[] | select(.id == "create-pr") | .with."commit-message"' "$WORKFLOWS_DIR/update-helm-chart.yml")
  # inputs.CHART_NAME is empty in CHART_PATH mode: the PR would read "Update chart  to v1.2.3".
  for v in "$title" "$commit"; do
    if [[ "$v" == *"inputs.CHART_NAME"* ]] || [[ "$v" != *"steps.update-chart.outputs.CHART_NAME"* ]]; then
      printf 'FAIL: expected the resolved chart name, got %q\n' "$v" >&2
      exit 1
    fi
  done
}

run_tests
