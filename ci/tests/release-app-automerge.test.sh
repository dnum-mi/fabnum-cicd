#!/usr/bin/env bash
# release-app.yml - 'Automerge release PR'

# shellcheck source=ci/tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

BLOCK=$(extract_run release-app.yml release "Automerge release PR")

# Defaults mirror a healthy repository with one open release pull request.
# The fixture is what `gh pr list --json number,headRefName` returns; the
# workflow's own --jq filter runs against it.
automerge_env() {
  export GH_TOKEN="app-token"
  export METADATA_TOKEN="github-token"
  export GITHUB_REPOSITORY="my-org/my-app"
  export GITHUB_REF_NAME="main"
  export AUTOMERGE_METHOD="auto"
  export STUB_GH_PR_LIST_JSON='[
    {"number": 42, "headRefName": "release-please--branches--main", "isCrossRepository": false}
  ]'
  export STUB_GH_REPO_JSON='{"allow_auto_merge": true}'
}

test_fails_when_no_credential_supplied() {
  automerge_env
  export GH_TOKEN=""

  run_block "$BLOCK"

  assert_status 1 "missing credential must fail the job"
  assert_output_contains "::error::Automerge is enabled but no credential was supplied"
  assert_not_called "pr merge"
}

test_queues_auto_merge_when_allowed() {
  automerge_env

  run_block "$BLOCK"

  assert_status 0
  assert_called "gh|app-token|pr merge 42 --rebase --auto"
  assert_not_called "--admin"
}

test_fails_when_auto_merge_not_enabled_on_repository() {
  automerge_env
  export STUB_GH_REPO_JSON='{"allow_auto_merge": false}'

  run_block "$BLOCK"

  assert_status 1 "auto without 'Allow auto-merge' must fail rather than force-merge"
  assert_output_contains "requires 'Allow auto-merge'"
  # The whole point of the input: never silently fall back to a force-merge.
  assert_not_called "pr merge"
}

test_reads_repository_metadata_with_the_builtin_token() {
  automerge_env

  run_block "$BLOCK"

  assert_status 0
  # A narrowly scoped App token may not carry repo metadata access, so the
  # allow_auto_merge lookup has to use GITHUB_TOKEN.
  assert_called "gh|github-token|api repos/my-org/my-app"
}

test_admin_force_merges_and_warns() {
  automerge_env
  export AUTOMERGE_METHOD="admin"

  run_block "$BLOCK"

  assert_status 0
  assert_output_contains "::warning::Force-merging PR #42"
  assert_called "gh|app-token|pr merge 42 --rebase --admin"
  # admin must not consult the repository setting at all.
  assert_not_called "api repos/"
}

test_skips_when_no_open_release_pull_request() {
  automerge_env
  export STUB_GH_PR_LIST_JSON='[]'

  run_block "$BLOCK"

  assert_status 0 "nothing to merge is a normal outcome, not a failure"
  assert_output_contains "skipping automerge"
  assert_not_called "pr merge"
}

test_merges_every_component_pull_request() {
  automerge_env
  # release-please with separate-pull-requests opens one PR per component.
  # Matching remote branch names and collapsing them into a single --head value
  # is what used to make monorepos silently never automerge.
  export STUB_GH_PR_LIST_JSON='[
    {"number": 42, "headRefName": "release-please--branches--main--components--api", "isCrossRepository": false},
    {"number": 43, "headRefName": "release-please--branches--main--components--web", "isCrossRepository": false},
    {"number": 44, "headRefName": "release-please--branches--main--components--cli", "isCrossRepository": false}
  ]'

  run_block "$BLOCK"

  assert_status 0
  assert_called "pr merge 42 --rebase --auto"
  assert_called "pr merge 43 --rebase --auto"
  assert_called "pr merge 44 --rebase --auto"
  assert_call_count "pr merge" 3
}

test_ignores_pull_requests_that_are_not_release_please_branches() {
  automerge_env
  # Ordinary pull requests target the release branch too. Only release-please
  # heads may be merged - the base-branch filter alone is not enough.
  export STUB_GH_PR_LIST_JSON='[
    {"number": 7,  "headRefName": "feat/some-feature", "isCrossRepository": false},
    {"number": 42, "headRefName": "release-please--branches--main", "isCrossRepository": false},
    {"number": 9,  "headRefName": "renovate/actions-checkout", "isCrossRepository": false},
    {"number": 11, "headRefName": "release-please--branches--develop", "isCrossRepository": false}
  ]'

  run_block "$BLOCK"

  assert_status 0
  assert_called "pr merge 42 --rebase --auto"
  assert_call_count "pr merge" 1
}

test_constrains_the_query_to_open_pull_requests_on_the_target_branch() {
  automerge_env

  run_block "$BLOCK"

  assert_status 0
  assert_called "--state open"
  assert_called "--base main"
}

test_propagates_a_failed_merge() {
  automerge_env
  export STUB_GH_FAIL_ON="pr merge"
  export STUB_GH_FAIL_MESSAGE="pull request is not mergeable"

  run_block "$BLOCK"

  assert_status 1 "a failed merge must fail the job, not be swallowed"
}

test_propagates_a_failed_pull_request_lookup() {
  automerge_env
  export STUB_GH_FAIL_ON="pr list"
  export STUB_GH_FAIL_MESSAGE="API rate limit exceeded"

  run_block "$BLOCK"

  # `mapfile -t x < <(gh ...)` would hide this: a process substitution's exit
  # status reaches neither `set -e` nor `pipefail`, so the array would come back
  # empty and the step would report "nothing to merge" and pass - leaving the
  # release unmerged with a green run.
  assert_status 1 "a failed lookup must fail the job, not read as 'no pull requests'"
  assert_output_lacks "skipping automerge"
  assert_not_called "pr merge"
}

test_refuses_to_merge_a_fork_pull_request() {
  automerge_env
  # A head branch name is chosen by whoever opened the PR; for a fork it is just
  # a branch in their own repository. Merging on that alone let any GitHub user
  # get arbitrary code into the release branch - under `admin`, past branch
  # protection entirely.
  export STUB_GH_PR_LIST_JSON='[
    {"number": 99, "headRefName": "release-please--branches--main", "isCrossRepository": true, "author": {"login": "outsider"}}
  ]'

  run_block "$BLOCK"

  assert_status 0 "a hostile PR is not an error, it is simply not ours to merge"
  assert_not_called "pr merge"
  assert_output_contains "skipping automerge"
}

test_refuses_a_branch_that_only_extends_the_release_prefix() {
  automerge_env
  # `startswith` also accepted `<prefix>-anything`, so a collaborator could
  # craft a branch that is not a release-please branch at all.
  export STUB_GH_PR_LIST_JSON='[
    {"number": 98, "headRefName": "release-please--branches--main-evil", "isCrossRepository": false, "author": {"login": "insider"}},
    {"number": 97, "headRefName": "release-please--branches--mainly", "isCrossRepository": false, "author": {"login": "insider"}}
  ]'

  run_block "$BLOCK"

  assert_status 0
  assert_not_called "pr merge"
}

test_still_merges_the_two_shapes_release_please_really_produces() {
  automerge_env
  export STUB_GH_PR_LIST_JSON='[
    {"number": 42, "headRefName": "release-please--branches--main", "isCrossRepository": false, "author": {"login": "app/my-ci"}},
    {"number": 43, "headRefName": "release-please--branches--main--components--api", "isCrossRepository": false, "author": {"login": "app/my-ci"}}
  ]'

  run_block "$BLOCK"

  assert_status 0
  assert_called "pr merge 42 --rebase --auto"
  assert_called "pr merge 43 --rebase --auto"
  assert_call_count "pr merge" 2
}

test_pins_the_author_when_release_pr_author_is_set() {
  automerge_env
  export RELEASE_PR_AUTHOR="app/my-ci"
  export STUB_GH_PR_LIST_JSON='[
    {"number": 42, "headRefName": "release-please--branches--main", "isCrossRepository": false, "author": {"login": "app/my-ci"}},
    {"number": 66, "headRefName": "release-please--branches--main--components--x", "isCrossRepository": false, "author": {"login": "someone-with-push-access"}}
  ]'

  run_block "$BLOCK"

  assert_status 0
  assert_called "pr merge 42 --rebase --auto"
  assert_call_count "pr merge" 1
}

test_a_pull_request_with_no_fork_information_is_refused() {
  automerge_env
  # The guard must fail CLOSED. `select(.isCrossRepository | not)` passed a
  # record where the field was absent, because `null | not` is true - so
  # dropping the field from `--json` would have silently disabled it while every
  # other test still passed.
  export STUB_GH_PR_LIST_JSON='[
    {"number": 42, "headRefName": "release-please--branches--main",
     "author": {"login": "app/github-actions"}}
  ]'

  run_block "$BLOCK"

  assert_status 0
  assert_not_called "pr merge"
}

test_wildcard_author_skips_the_author_check() {
  automerge_env
  # `*` is what the workflow resolves to under a PAT, where the author is the
  # token owner and cannot be derived. The fork and exact-branch guards still
  # apply; only the author check is skipped.
  export RELEASE_PR_AUTHOR="*"
  export STUB_GH_PR_LIST_JSON='[
    {"number": 42, "headRefName": "release-please--branches--main", "isCrossRepository": false,
     "author": {"login": "some-human"}},
    {"number": 99, "headRefName": "release-please--branches--main", "isCrossRepository": true,
     "author": {"login": "outsider"}}
  ]'

  run_block "$BLOCK"

  assert_status 0
  assert_called "pr merge 42 --rebase --auto"
  # The fork is still refused even with the author check off.
  assert_call_count "pr merge" 1
}

test_raises_the_pull_request_page_size() {
  automerge_env

  run_block "$BLOCK"

  assert_status 0
  # The release-please filter is applied client-side, so gh's default page size
  # of 30 could hide the release pull requests in a busy repository.
  assert_called "--limit 100"
}

run_tests
