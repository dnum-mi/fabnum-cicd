#!/usr/bin/env bash
# release-app.yml - 'Assert the <prerelease> release anchor is reachable'
#
# release-please starts from the release named after the version in the
# prerelease manifest, found by its tag, and reads the branch history down to
# that tag's commit. After a rebase the tag is no longer in the branch, and
# release-please - which says nothing about it - falls back on the 500 most
# recent commits and proposes a wrong version. `last-release-sha` in the
# prerelease config is the supported way to start from another commit; this
# asserts that either the tag or that key is in the history of the branch.

# shellcheck source=ci/tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# shellcheck disable=SC2016 # the Actions marker is meant to stay literal
BLOCK=$(extract_run release-app.yml release 'Assert the ${{ inputs.PRERELEASE_BRANCH }} release anchor is reachable')

TAG_SHA="1111111111111111111111111111111111111111"
PEELED_SHA="2222222222222222222222222222222222222222"
ANCHOR_SHA="3333333333333333333333333333333333333333"

# One `git ls-remote --tags` line.
tag_line() {
  printf '%s\trefs/tags/%s\n' "$1" "$2"
}

assert_env() {
  export GITHUB_REPOSITORY="my-org/my-app"
  export PRERELEASE_BRANCH="develop"
  export PRERELEASE_MANIFEST_FILE="$SANDBOX/manifest-rc.json"
  export PRERELEASE_CONFIG_FILE="$SANDBOX/config-rc.json"
  printf '{".": "1.1.0-rc.1"}\n' >"$PRERELEASE_MANIFEST_FILE"
  printf '{"packages": {".": {}}}\n' >"$PRERELEASE_CONFIG_FILE"
  export STUB_GIT_TAGS="${TAG_SHA}	refs/tags/v1.1.0-rc.1
"
}

# `compare/BASE...HEAD` reports HEAD relative to BASE: with a commit as BASE,
# 'ahead' or 'identical' mean the commit is in the history of the branch.
in_history() {
  export "STUB_GH_COMPARE_JSON_$1={\"status\":\"ahead\",\"ahead_by\":3,\"behind_by\":0}"
}

not_in_history() {
  export "STUB_GH_COMPARE_JSON_$1={\"status\":\"diverged\",\"ahead_by\":3,\"behind_by\":2}"
}

set_anchor() {
  printf '{"last-release-sha": "%s", "packages": {".": {}}}\n' "$1" >"$PRERELEASE_CONFIG_FILE"
}

test_passes_when_the_release_tag_is_in_the_branch() {
  assert_env
  in_history "$TAG_SHA"

  run_block "$BLOCK"

  assert_status 0
  assert_output_contains "release-please starts from v1.1.0-rc.1"
}

test_fails_when_the_tag_left_the_branch_and_nothing_anchors_release_please() {
  assert_env
  not_in_history "$TAG_SHA"

  run_block "$BLOCK"

  # The silent case: nothing else says the version is about to be wrong.
  assert_status 1
  assert_output_contains "would start from 'v1.1.0-rc.1'"
  assert_output_contains "last-release-sha"
  assert_output_contains "sync-prerelease-branch job"
}

test_passes_when_the_tag_left_the_branch_but_the_anchor_is_in_it() {
  assert_env
  not_in_history "$TAG_SHA"
  set_anchor "$ANCHOR_SHA"
  in_history "$ANCHOR_SHA"

  run_block "$BLOCK"

  assert_status 0
  assert_output_contains "starts from last-release-sha $ANCHOR_SHA"
}

test_fails_when_the_anchor_is_not_in_the_branch_either() {
  assert_env
  not_in_history "$TAG_SHA"
  set_anchor "$ANCHOR_SHA"
  not_in_history "$ANCHOR_SHA"

  run_block "$BLOCK"

  # A key left behind by an earlier rebase names a commit that no longer
  # exists in the branch: as good as no anchor.
  assert_status 1
}

test_fails_when_the_anchor_is_an_unknown_commit() {
  assert_env
  not_in_history "$TAG_SHA"
  set_anchor "$ANCHOR_SHA"
  export "STUB_GH_COMPARE_FAIL_$ANCHOR_SHA=1"

  run_block "$BLOCK"

  # The API answers 404 for a commit it does not have.
  assert_status 1
}

test_uses_the_commit_an_annotated_tag_peels_to() {
  assert_env
  # An annotated tag is listed twice: the tag object, then the commit it
  # points at (`^{}`). Only the commit can be compared with the branch.
  export STUB_GIT_TAGS="${TAG_SHA}	refs/tags/v1.1.0-rc.1
${PEELED_SHA}	refs/tags/v1.1.0-rc.1^{}
"
  export "STUB_GH_COMPARE_FAIL_$TAG_SHA=1"
  in_history "$PEELED_SHA"

  run_block "$BLOCK"

  assert_status 0
  assert_called "compare/$PEELED_SHA...develop"
  assert_not_called "compare/$TAG_SHA...develop"
}

test_prefers_the_plain_version_tag_over_a_prefixed_one() {
  assert_env
  # A lockstep chart tag also ends in the version, and sorts after it.
  local tags
  tags="$(tag_line "$TAG_SHA" v1.1.0-rc.1; tag_line "$PEELED_SHA" webapp-1.1.0-rc.1)"
  export STUB_GIT_TAGS="$tags"$'\n'
  in_history "$TAG_SHA"
  not_in_history "$PEELED_SHA"

  run_block "$BLOCK"

  assert_status 0
  assert_output_contains "starts from v1.1.0-rc.1"
  assert_not_called "compare/$PEELED_SHA"
}

test_does_not_guess_between_several_prefixed_tags() {
  assert_env
  local tags
  tags="$(tag_line "$TAG_SHA" api-1.1.0-rc.1; tag_line "$PEELED_SHA" webapp-1.1.0-rc.1)"
  export STUB_GIT_TAGS="$tags"$'\n'
  not_in_history "$TAG_SHA"
  not_in_history "$PEELED_SHA"

  run_block "$BLOCK"

  # Checking the wrong one would fail a healthy branch.
  assert_status 0
  assert_output_contains "Several tags end with the version 1.1.0-rc.1"
  assert_not_called "gh|"
}

test_says_so_when_the_api_cannot_be_queried_rather_than_blaming_the_rebase() {
  assert_env
  export "STUB_GH_COMPARE_ERROR_$TAG_SHA=1"

  run_block "$BLOCK"

  # A 502 says nothing about the history: it must not read as an orphaned tag.
  assert_status 1
  assert_output_contains "Could not ask the GitHub API"
  assert_output_lacks "would start from"
}

test_says_so_when_the_api_cannot_be_queried_about_the_anchor() {
  assert_env
  not_in_history "$TAG_SHA"
  set_anchor "$ANCHOR_SHA"
  export "STUB_GH_COMPARE_ERROR_$ANCHOR_SHA=1"

  run_block "$BLOCK"

  assert_status 1
  assert_output_contains "Could not ask the GitHub API"
  assert_output_lacks "would start from"
}

test_matches_a_tag_that_carries_a_component_prefix() {
  assert_env
  export STUB_GIT_TAGS="${TAG_SHA}	refs/tags/my-app-v1.1.0-rc.1
"
  in_history "$TAG_SHA"

  run_block "$BLOCK"

  assert_status 0
  assert_output_contains "starts from my-app-v1.1.0-rc.1"
}

test_does_not_take_a_longer_version_for_the_released_one() {
  assert_env
  # 11.1.0-rc.1 contains 1.1.0-rc.1 as a suffix: it is another release.
  export STUB_GIT_TAGS="${TAG_SHA}	refs/tags/v11.1.0-rc.1
"

  run_block "$BLOCK"

  assert_status 0
  assert_output_contains "No tag for the version 1.1.0-rc.1"
  assert_not_called "gh|"
}

test_warns_and_passes_when_the_version_has_no_tag() {
  assert_env
  export STUB_GIT_TAGS=""

  run_block "$BLOCK"

  # release-please has its own lookup for that; this assertion is about the
  # case where the tag exists and has been orphaned.
  assert_status 0
  assert_output_contains "No tag for the version 1.1.0-rc.1"
}

test_skips_a_manifest_that_tracks_several_packages() {
  assert_env
  printf '{".": "1.1.0-rc.1", "other": "0.1.0"}\n' >"$PRERELEASE_MANIFEST_FILE"

  run_block "$BLOCK"

  # last-release-sha is a single commit for the whole repository.
  assert_status 0
  assert_output_contains "does not track exactly one package"
  assert_not_called "gh|"
}

test_skips_when_the_manifest_does_not_exist_yet() {
  assert_env
  rm -f "$PRERELEASE_MANIFEST_FILE"

  run_block "$BLOCK"

  assert_status 0
  assert_output_contains "does not exist yet"
}

# When it runs, and what runs after it.
test_only_runs_on_the_prerelease_branch_with_prerelease_enabled_and_something_to_release() {
  local condition
  # shellcheck disable=SC2016 # the Actions marker is meant to stay literal
  condition=$(yq '.jobs.release.steps[] | select(.name == "Assert the ${{ inputs.PRERELEASE_BRANCH }} release anchor is reachable") | .if' \
    "$WORKFLOWS_DIR/release-app.yml")

  # shellcheck disable=SC2016 # the Actions expression is meant to stay literal
  if [ "$condition" != '${{ inputs.ENABLE_PRERELEASE && github.ref_name == inputs.PRERELEASE_BRANCH && steps.sync-state.outputs.identical != '"'true'"' }}' ]; then
    printf 'FAIL: anchor assertion condition is %q\n' "$condition" >&2
    exit 1
  fi
}

test_release_please_is_skipped_when_the_prerelease_branch_is_identical_to_the_release_branch() {
  local condition
  condition=$(yq '.jobs.release.steps[] | select(.name == "Release new version") | .if' \
    "$WORKFLOWS_DIR/release-app.yml")

  # Empty on every other branch and when prereleases are off, so those still
  # run; only the explicit `identical=true` of the sync assertion skips it.
  # shellcheck disable=SC2016 # the Actions expression is meant to stay literal
  if [ "$condition" != '${{ steps.sync-state.outputs.identical != '"'true'"' }}' ]; then
    printf 'FAIL: release-please step condition is %q\n' "$condition" >&2
    exit 1
  fi
}

run_tests
