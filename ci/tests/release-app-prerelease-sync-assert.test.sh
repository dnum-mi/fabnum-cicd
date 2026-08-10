#!/usr/bin/env bash
# release-app.yml - 'Assert <prerelease> is in sync with <release>'
#
# The invariant: the prerelease branch is the release branch plus only the
# unreleased work. Every version computed on the prerelease branch depends on
# it, and what keeps it true is a job the CALLER schedules
# (sync-prerelease-branch.yml) - which no workflow can verify was wired up. So
# it is asserted here, at the point it is consumed, rather than assumed from
# configuration.

# shellcheck source=ci/tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# shellcheck disable=SC2016 # the Actions marker is meant to stay literal
BLOCK=$(extract_run release-app.yml release 'Assert ${{ inputs.PRERELEASE_BRANCH }} is in sync with ${{ inputs.RELEASE_BRANCH }}')

assert_env() {
  export GITHUB_REPOSITORY="my-org/my-app"
  export RELEASE_BRANCH="main"
  export PRERELEASE_BRANCH="develop"
}

# `compare/BASE...HEAD` reports HEAD relative to BASE. BASE is the prerelease
# branch, so 'behind'/'identical' mean the release branch holds nothing the
# prerelease branch lacks - the invariant.
compare_status() {
  export STUB_GH_COMPARE_JSON="{\"status\":\"$1\",\"ahead_by\":${2:-0},\"behind_by\":0}"
}

test_passes_when_the_branches_are_identical() {
  assert_env
  compare_status identical 0

  run_block "$BLOCK"

  assert_status 0
  assert_output_contains "contains everything released"
}

test_passes_when_the_prerelease_branch_is_ahead() {
  assert_env
  # The steady state between releases: the prerelease branch has unreleased
  # work, the release branch has nothing it is missing.
  compare_status behind 0

  run_block "$BLOCK"

  assert_status 0
}

test_fails_when_the_prerelease_branch_is_missing_released_commits() {
  assert_env
  compare_status ahead 1

  run_block "$BLOCK"

  # The whole point: a version computed from here would be derived from a
  # pre-release state and can land below what was already published.
  assert_status 1
  assert_output_contains "is missing 1 commit(s)"
  assert_output_contains "sync-prerelease-branch.yml"
}

test_fails_when_the_branches_have_diverged() {
  assert_env
  compare_status diverged 2

  run_block "$BLOCK"

  assert_status 1
  assert_output_contains "is missing 2 commit(s)"
}

test_names_the_concurrent_release_pipeline_as_a_cause() {
  assert_env
  compare_status ahead 1

  run_block "$BLOCK"

  # A release still running on the release branch produces this legitimately,
  # and re-running is the fix - the message has to say so, or the failure
  # reads as a broken repository.
  assert_output_contains "re-run once it completes"
}

test_skips_when_the_release_branch_does_not_exist_yet() {
  assert_env
  export STUB_GIT_FAIL_ON="ls-remote"

  run_block "$BLOCK"

  # A repository that has not created the release branch has nothing to be out
  # of sync with, and must not be blocked from cutting its first prereleases.
  assert_status 0
  assert_output_contains "does not exist yet"
  assert_not_called "gh|"
}

test_fails_closed_on_an_unrecognised_status() {
  assert_env
  compare_status something-new 0

  run_block "$BLOCK"

  # A status this does not understand must not be read as "in sync".
  assert_status 1
  assert_output_contains "Unexpected comparison status"
}

run_tests
