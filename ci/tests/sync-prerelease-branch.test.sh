#!/usr/bin/env bash
# sync-prerelease-branch.yml - the rebase that keeps the prerelease branch
# equal to the release branch plus only the unreleased work.

# shellcheck source=ci/tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# shellcheck disable=SC2016 # the Actions marker is meant to stay literal
BLOCK=$(extract_run sync-prerelease-branch.yml sync 'Ensure ${{ inputs.PRERELEASE_BRANCH }} is up to date with ${{ inputs.RELEASE_BRANCH }}')

rebase_env() {
  export RELEASE_BRANCH="main"
  export PRERELEASE_BRANCH="develop"
  export CREATE_IF_MISSING="true"
  export HAS_PARTIAL_APP_AUTH="false"
  # No release-please files in the sandbox: the anchoring has nothing to read,
  # and the rebase itself is what these tests cover. The real-git behaviour is
  # in sync-prerelease-branch-rebase.test.sh.
  export PRERELEASE_CONFIG_FILE="$SANDBOX/missing-config.json"
  export PRERELEASE_MANIFEST_FILE="$SANDBOX/missing-manifest.json"
  export RELEASE_MANIFEST_FILE="$SANDBOX/missing-release-manifest.json"
  export MANAGED_FILES=""
}

test_unshallows_before_fetching_when_the_clone_is_shallow() {
  rebase_env
  export STUB_GIT_IS_SHALLOW="true"

  run_block "$BLOCK"

  assert_status 0
  # Without this, git has no shared history to compute a merge-base from, and
  # the rebase below replays the whole branch instead of just what actually
  # diverged - see the comment above this step in the workflow. Must run
  # BEFORE the branch fetch, or $PRERELEASE_BRANCH still comes down shallow -
  # asserting both calls happened is not enough to catch that reordering.
  assert_called "git|fetch --unshallow origin main develop"
  assert_called_before "git|fetch --unshallow origin main develop" "git|fetch origin main develop"
}

test_does_not_unshallow_an_already_complete_clone() {
  rebase_env
  export STUB_GIT_IS_SHALLOW="false"

  run_block "$BLOCK"

  assert_status 0
  # --unshallow errors outright ("does not make sense") on a repository that
  # is already complete.
  assert_not_called "fetch --unshallow"
}

test_rebases_and_force_pushes_when_the_branch_exists() {
  rebase_env

  run_block "$BLOCK"

  assert_status 0
  assert_output_contains "branch exists. Attempting rebase"
  assert_called "git|checkout develop"
  assert_called "git|reset --hard origin/develop"
  assert_called "git|rebase origin/main"
  # The lease names the tip it was computed from: the default one follows the
  # remote-tracking branch, which any later fetch moves, and would let a
  # commit landing meanwhile be overwritten.
  assert_called "git|push --force-with-lease=develop:0123456789abcdef0123456789abcdef01234567 origin develop"
}

test_does_not_fetch_tags_when_there_is_no_prerelease_manifest() {
  rebase_env

  run_block "$BLOCK"

  # A repository without release-please files on the prerelease branch has no
  # anchor to maintain, and must not pay for a tag fetch on every sync.
  assert_status 0
  assert_not_called "fetch --quiet origin +refs/tags"
  assert_not_called "git|commit"
}

test_creates_the_branch_from_release_branch_when_missing() {
  rebase_env
  export STUB_GIT_FAIL_ON="ls-remote"

  run_block "$BLOCK"

  assert_status 0
  assert_output_contains "does not exist. Creating from"
  assert_called "git|fetch origin main"
  assert_called "git|checkout -b develop origin/main"
  assert_called "git|push origin develop"
  assert_not_called "rebase"
}

test_creation_never_fetches_the_missing_branch() {
  rebase_env
  # The default checkout is shallow, and a real `git fetch` naming a branch
  # that does not exist fails hard - the stub cannot fail on the fetch and the
  # probe at once, so this asserts the fix structurally: on the bootstrap
  # path, no fetch may name $PRERELEASE_BRANCH, unshallow or otherwise.
  export STUB_GIT_IS_SHALLOW="true"
  export STUB_GIT_FAIL_ON="ls-remote"

  run_block "$BLOCK"

  assert_status 0 "bootstrap must survive a shallow clone"
  assert_not_called "fetch --unshallow"
  assert_not_called "git|fetch origin main develop"
}

test_aborts_and_fails_when_the_rebase_conflicts() {
  rebase_env
  export STUB_GIT_FAIL_ON="rebase origin/main"
  export STUB_GIT_FAIL_MESSAGE="CONFLICT (content): Merge conflict"

  run_block "$BLOCK"

  assert_status 1 "a rebase conflict must fail the job, not push a broken branch"
  assert_output_contains "failed due to conflicts"
  assert_called "git|rebase --abort"
  assert_not_called "push"
}

test_skips_a_missing_branch_when_creation_is_disabled() {
  rebase_env
  export CREATE_IF_MISSING="false"
  export STUB_GIT_FAIL_ON="ls-remote"

  run_block "$BLOCK"

  assert_status 0
  assert_output_contains "nothing to do"
  assert_not_called "checkout -b"
  assert_not_called "push"
}

# 'Validate inputs' - the two branch names name the two ends of the
# synchronisation, so a caller collapsing them onto one branch would rebase a
# branch onto itself and never see a synchronisation happen.
VALIDATE=$(extract_run sync-prerelease-branch.yml sync 'Validate inputs')

test_validate_accepts_two_distinct_branches() {
  rebase_env

  run_block "$VALIDATE"

  assert_status 0
}

test_validate_rejects_the_two_branches_being_equal() {
  rebase_env
  export PRERELEASE_BRANCH="main"

  run_block "$VALIDATE"

  assert_status 1
  assert_output_contains "must differ"
}

test_validate_rejects_an_empty_branch_name() {
  rebase_env
  export PRERELEASE_BRANCH=""

  run_block "$VALIDATE"

  assert_status 1
  assert_output_contains "must both be set"
}

# Which credential the push goes out on. Without App credentials it must stay
# GITHUB_TOKEN: that is what stops moving the prerelease branch from starting the
# caller's CD pipeline. The App token is only ever an explicit opt-in.
test_checkout_pushes_with_the_app_token_when_minted_and_github_token_otherwise() {
  local token
  token=$(yq '.jobs.sync.steps[] | select(.name == "Checks-out repository") | .with.token' \
    "$WORKFLOWS_DIR/sync-prerelease-branch.yml")

  # shellcheck disable=SC2016 # the Actions expression is meant to stay literal
  if [ "$token" != '${{ steps.app-token.outputs.token || github.token }}' ]; then
    # shellcheck disable=SC2016
    printf 'FAIL: checkout token is %q, expected the App token with a GITHUB_TOKEN fallback\n' "$token" >&2
    exit 1
  fi
}

test_the_app_token_is_only_minted_when_both_credentials_are_present() {
  local condition
  condition=$(yq '.jobs.sync.steps[] | select(.name == "Generate GitHub App token") | .if' \
    "$WORKFLOWS_DIR/sync-prerelease-branch.yml")

  # shellcheck disable=SC2016 # the Actions expression is meant to stay literal
  if [ "$condition" != '${{ env.HAS_APP_AUTH == '"'true'"' }}' ]; then
    printf 'FAIL: mint step condition is %q\n' "$condition" >&2
    exit 1
  fi
}

run_tests
