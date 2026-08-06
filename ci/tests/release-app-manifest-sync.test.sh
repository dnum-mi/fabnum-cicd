#!/usr/bin/env bash
# release-app.yml - 'Synchronize release-please-rc manifest'

# shellcheck source=ci/tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

BLOCK=$(extract_run release-app.yml release "Synchronize release-please-rc manifest")

sync_env() {
  export GH_TOKEN="github-token"
  export PUSH_TOKEN="app-token"
  export GITHUB_REF_NAME="main"
  export GITHUB_SERVER_URL="https://github.com"
  export RELEASE_MANIFEST_FILE=".release-please-manifest.json"
  export PRERELEASE_MANIFEST_FILE=".release-please-manifest-rc.json"
  export STUB_GH_PR_LIST_JSON='[
    {"headRefName": "release-please--branches--main", "isCrossRepository": false}
  ]'
  # Manifests differ, so a sync is needed.
  export STUB_GIT_FILES_MATCH="false"

  # The step reads and writes the working tree, so give it real files as a
  # checkout would; the `-f` guard and the `cat` both depend on them.
  printf '{"a": "1.2.3"}\n' >"$SANDBOX/$RELEASE_MANIFEST_FILE"
  printf '{"a": "1.2.2"}\n' >"$SANDBOX/$PRERELEASE_MANIFEST_FILE"
  cd "$SANDBOX" || exit 1
}

test_skips_when_no_open_release_pull_request() {
  sync_env
  export STUB_GH_PR_LIST_JSON='[]'

  run_block "$BLOCK"

  assert_status 0 "no release pull request is a normal outcome"
  assert_output_contains "skipping synchronization"
  assert_not_called "git|push"
}

test_amends_and_force_pushes_the_release_branch() {
  sync_env

  run_block "$BLOCK"

  assert_status 0
  assert_called "git|checkout -B release-please--branches--main origin/release-please--branches--main"
  assert_called "git|commit --amend --no-edit"
  assert_called "git|push --force-with-lease --force-if-includes origin release-please--branches--main"
}

test_synchronizes_every_component_branch() {
  sync_env
  # One branch per component under separate-pull-requests. The previous
  # `git branch -r | grep | xargs` form collapsed these into one string that
  # matched no branch, so monorepos silently never synchronized.
  export STUB_GH_PR_LIST_JSON='[
    {"headRefName": "release-please--branches--main--components--api", "isCrossRepository": false},
    {"headRefName": "release-please--branches--main--components--web", "isCrossRepository": false}
  ]'

  run_block "$BLOCK"

  assert_status 0
  assert_called "git|push --force-with-lease --force-if-includes origin release-please--branches--main--components--api"
  assert_called "git|push --force-with-lease --force-if-includes origin release-please--branches--main--components--web"
  assert_call_count "git|commit --amend --no-edit" 2
}

test_ignores_pull_requests_that_are_not_release_please_branches() {
  sync_env
  export STUB_GH_PR_LIST_JSON='[
    {"headRefName": "feat/some-feature", "isCrossRepository": false},
    {"headRefName": "release-please--branches--main", "isCrossRepository": false},
    {"headRefName": "release-please--branches--develop", "isCrossRepository": false}
  ]'

  run_block "$BLOCK"

  assert_status 0
  assert_call_count "git|commit --amend --no-edit" 1
  assert_called "origin release-please--branches--main"
}

test_does_nothing_when_the_manifests_already_match() {
  sync_env
  export STUB_GIT_FILES_MATCH="true"

  run_block "$BLOCK"

  assert_status 0
  assert_output_contains "Already in sync"
  assert_not_called "git|commit --amend"
  assert_not_called "git|push"
}

test_treats_a_missing_prerelease_manifest_as_out_of_sync() {
  sync_env
  # Even with the comparison reporting a match, an absent file must still be
  # created rather than skipped - `git diff --no-index` cannot compare it.
  export STUB_GIT_FILES_MATCH="true"
  rm -f "$SANDBOX/$PRERELEASE_MANIFEST_FILE"

  run_block "$BLOCK"

  assert_status 0
  assert_called "git|commit --amend --no-edit"
}

test_pushes_as_the_app_so_the_amended_commit_re_runs_ci() {
  sync_env

  run_block "$BLOCK"

  assert_status 0
  # actions/checkout stores its credential as an http.extraheader, so the push
  # identity only changes if that header is overridden. Without this the
  # amended commit gets no pull_request run and AUTOMERGE_METHOD=auto stalls.
  assert_called "git|config --local http.https://github.com/.extraheader AUTHORIZATION: basic"
  assert_output_contains "::add-mask::"
}

test_restores_the_checkout_credential_afterwards() {
  sync_env
  export STUB_GIT_EXISTING_HEADER="AUTHORIZATION: basic Y2hlY2tvdXQ="

  run_block "$BLOCK"

  assert_status 0
  # Later steps in the job must not inherit the elevated credential.
  assert_called "git|config --local http.https://github.com/.extraheader AUTHORIZATION: basic Y2hlY2tvdXQ="
}

test_unsets_the_header_when_there_was_none_to_restore() {
  sync_env

  run_block "$BLOCK"

  assert_status 0
  assert_called "git|config --local --unset http.https://github.com/.extraheader"
}

test_warns_when_only_github_token_is_available() {
  sync_env
  export PUSH_TOKEN=""

  run_block "$BLOCK"

  assert_status 0 "the sync must still happen, just without triggering CI"
  assert_output_contains "::warning::"
  assert_output_contains "will not re-run against the amended commit"
  assert_called "git|push --force-with-lease --force-if-includes origin release-please--branches--main"
  # No credential to install, so nothing to override or restore.
  assert_not_called "extraheader AUTHORIZATION"
}

test_propagates_a_failed_push() {
  sync_env
  export STUB_GIT_FAIL_ON="push"
  export STUB_GIT_FAIL_MESSAGE="stale info; force-with-lease rejected"

  run_block "$BLOCK"

  assert_status 1 "a rejected force-push must fail the job"
}

test_propagates_a_failed_pull_request_lookup() {
  sync_env
  export STUB_GH_FAIL_ON="pr list"
  export STUB_GH_FAIL_MESSAGE="API rate limit exceeded"

  run_block "$BLOCK"

  # `mapfile -t x < <(gh ...)` would hide this: a process substitution's exit
  # status reaches neither `set -e` nor `pipefail`, so the array would come back
  # empty and the step would report "nothing to synchronize" and pass, leaving
  # the prerelease manifest stale with a green run.
  assert_status 1 "a failed lookup must fail the job, not read as 'no pull requests'"
  assert_output_lacks "skipping synchronization"
  assert_not_called "git|push"
}

test_refuses_to_push_to_a_fork_pull_request() {
  sync_env
  # This step force-pushes an amended commit to the head branch. Under a fork PR
  # that would be a write into someone else's repository, driven by a branch
  # name they chose.
  export STUB_GH_PR_LIST_JSON='[
    {"headRefName": "release-please--branches--main", "isCrossRepository": true, "author": {"login": "outsider"}}
  ]'

  run_block "$BLOCK"

  assert_status 0
  assert_not_called "git|push"
  assert_output_contains "skipping synchronization"
}

test_refuses_a_branch_that_only_extends_the_release_prefix() {
  sync_env
  export STUB_GH_PR_LIST_JSON='[
    {"headRefName": "release-please--branches--main-evil", "isCrossRepository": false, "author": {"login": "insider"}}
  ]'

  run_block "$BLOCK"

  assert_status 0
  assert_not_called "git|push"
}

test_pins_the_author_when_release_pr_author_is_set() {
  sync_env
  export RELEASE_PR_AUTHOR="app/my-ci"
  export STUB_GH_PR_LIST_JSON='[
    {"headRefName": "release-please--branches--main", "isCrossRepository": false, "author": {"login": "someone-with-push-access"}}
  ]'

  run_block "$BLOCK"

  assert_status 0
  assert_not_called "git|push"
}

test_raises_the_pull_request_page_size() {
  sync_env

  run_block "$BLOCK"

  assert_status 0
  # The release-please filter is applied client-side, so gh's default page size
  # of 30 could hide the release pull requests in a busy repository.
  assert_called "--limit 100"
}

run_tests
