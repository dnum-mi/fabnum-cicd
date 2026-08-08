#!/usr/bin/env bash
# clean-cache.yml - 'Clean cache for branch'

# shellcheck source=ci/tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

BLOCK=$(extract_run clean-cache.yml cleanup-cache 'Clean cache for branch')

cache_env() {
  export GH_TOKEN="github-token"
  export REPO="owner/repo"
  export BRANCH_NAME=""
  export PR_NUMBER=""
  # Two keys, tab separated, as `gh cache list` prints them without --json.
  STUB_GH_CACHE_LIST=$(printf 'cache-key-one\t1MiB\ncache-key-two\t2MiB')
  export STUB_GH_CACHE_LIST
}

test_sweeps_the_pull_request_ref_not_the_head_branch() {
  cache_env
  export PR_NUMBER="42"
  export BRANCH_NAME="feat/some-branch"

  run_block "$BLOCK"

  assert_status 0
  # A pull request's caches live under refs/pull/<N>/merge. Looking the head
  # branch up instead finds nothing and reports success, which is how caches
  # for every closed pull request accumulated indefinitely.
  assert_called "gh|github-token|cache list -R owner/repo -r refs/pull/42/merge"
}

test_sweeps_both_refs_when_given_both() {
  cache_env
  export PR_NUMBER="42"
  export BRANCH_NAME="feat/some-branch"

  run_block "$BLOCK"

  assert_status 0
  # A branch can hold caches of its own when a workflow ran on `push`, so
  # neither ref may be dropped in favour of the other.
  assert_called "gh|github-token|cache list -R owner/repo -r refs/pull/42/merge"
  assert_called "gh|github-token|cache list -R owner/repo -r feat/some-branch"
}

test_falls_back_to_the_branch_when_there_is_no_pull_request() {
  cache_env
  export BRANCH_NAME="develop"

  run_block "$BLOCK"

  assert_status 0
  assert_called "gh|github-token|cache list -R owner/repo -r develop"
  assert_not_called "refs/pull"
}

test_deletes_every_key_it_finds() {
  cache_env
  export PR_NUMBER="42"

  run_block "$BLOCK"

  assert_status 0
  assert_called "gh|github-token|cache delete cache-key-one -R owner/repo"
  assert_called "gh|github-token|cache delete cache-key-two -R owner/repo"
  assert_output_contains "2 deleted"
}

test_reports_no_keys_without_failing() {
  cache_env
  export PR_NUMBER="42"
  export STUB_GH_CACHE_LIST=""

  run_block "$BLOCK"

  assert_status 0 "an empty cache list is a normal outcome"
  assert_output_contains "No cache keys found"
  assert_not_called "cache delete"
}

test_survives_a_key_evicted_between_the_list_and_the_delete() {
  cache_env
  export PR_NUMBER="42"
  export STUB_GH_CACHE_DELETE_FAIL_ON="cache-key-one"

  run_block "$BLOCK"

  # A concurrent run can evict a key after it was listed. That must not fail
  # the job or stop the remaining keys from being deleted.
  assert_status 0
  assert_output_contains "Failed to delete cache key: cache-key-one"
  assert_called "gh|github-token|cache delete cache-key-two -R owner/repo"
  assert_output_contains "1 deleted"
}

test_fails_when_given_neither_ref() {
  cache_env

  run_block "$BLOCK"

  assert_status 1 "with nothing to scope the deletion to, this must not guess"
  assert_output_contains "Neither BRANCH_NAME nor PR_NUMBER provided"
  assert_not_called "cache delete"
}

run_tests
