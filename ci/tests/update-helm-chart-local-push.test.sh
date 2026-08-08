#!/usr/bin/env bash
# update-helm-chart.yml - local mode: 'Commit and push chart bump'

# shellcheck source=ci/tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

BLOCK=$(extract_run update-helm-chart.yml update "Commit and push chart bump")

push_env() {
  export CHART_DIR="./charts"
  export CHART_NAME="my-app"
  export NEXT_VERSION="1.2.3"
  export GITHUB_REF_NAME="develop"
}

test_commit_carries_no_skip_ci() {
  push_env

  run_block "$BLOCK"

  assert_status 0
  # This push already cannot trigger a new run - push or pull_request -
  # because it goes out on GITHUB_TOKEN (see the checkout step). [skip ci]
  # would add nothing to that here, while suppressing pull_request checks for
  # any pull request a human later opens FROM this branch.
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

run_tests
