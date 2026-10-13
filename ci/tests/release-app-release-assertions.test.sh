#!/usr/bin/env bash
# release-app.yml - the two assertions around release-please
#
#   'Assert no abandoned release pull request blocks the run'   (before)
#   'Assert a merged release pull request was released'          (after)
#
# Both cover one failure: release-please reuses a single branch per target, so a
# pull request closed on that branch while still carrying an `autorelease:`
# label keeps its place in release-please's bookkeeping. The next run pushes the
# release commit, opens a new pull request, then fails trying to reopen the
# closed one - after the push, before labelling. `autorelease: pending` is the
# queue the release phase reads, so the unlabelled pull request merges and
# nothing tags it: a changelog and a manifest claiming a version that has no
# tag, no release and no artifacts, and a next release pull request with no
# floor to measure from, proposing the whole history as unreleased.
#
# The first assertion refuses to start in that state; the second refuses to let
# a release commit pass as released.

# shellcheck source=ci/tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

BEFORE=$(extract_run release-app.yml release 'Assert no abandoned release pull request blocks the run')
AFTER=$(extract_run release-app.yml release 'Assert a merged release pull request was released')

RELEASE_SHA="3d120657a839eb1e4f516caebd9ac8fb51dd7cf4"
OTHER_SHA="a0c409a7f1e0b2c3d4e5f60718293a4b5c6d7e8f"

# --- 'Assert no abandoned release pull request blocks the run' ----------------

before_env() {
  export GITHUB_REF_NAME="${1:-main}"
}

# One closed pull request, as `gh pr list --state closed` reports it - which
# includes merged ones, so the second argument says which this is. Only the
# nullness of `mergedAt` is ever read, never the timestamp, so a merged pull
# request carries an arbitrary fixed one.
closed_pr() {
  local number="$1" merged="$2" head="$3" labels="$4" merged_at="null"

  if [ "$merged" = "merged" ]; then
    merged_at='"2001-02-03T04:05:06Z"'
  fi

  export STUB_GH_PR_LIST_JSON="[{
    \"number\": $number,
    \"title\": \"chore(main): release 0.20.1\",
    \"mergedAt\": $merged_at,
    \"headRefName\": \"$head\",
    \"labels\": $labels
  }]"
}

labels() {
  local out="[" name
  for name in "$@"; do
    [ "$out" != "[" ] && out="$out,"
    out="$out{\"name\":\"$name\"}"
  done
  printf '%s]' "$out"
}

test_before_passes_when_no_release_pull_request_was_ever_closed() {
  before_env
  export STUB_GH_PR_LIST_JSON="[]"

  run_block "$BEFORE"

  assert_status 0
  assert_output_contains "no abandoned release pull request"
}

test_before_fails_on_a_closed_unmerged_pull_request_still_labelled() {
  before_env
  closed_pr 118 abandoned "release-please--branches--main" \
    "$(labels "autorelease: pending" "autorelease: snooze")"

  run_block "$BEFORE"

  # The state that makes release-please exit before labelling the next pull
  # request, which is what leaves a merged release untagged.
  assert_status 1
  assert_output_contains "#118"
  assert_output_contains "autorelease: pending"
  assert_output_contains "Remove every 'autorelease:' label"
}

test_before_fails_on_the_snooze_label_alone() {
  before_env
  closed_pr 118 abandoned "release-please--branches--main" \
    "$(labels "autorelease: snooze")"

  # `snooze` is the label that produces the reopen collision; `pending` having
  # been stripped by hand does not make the pull request harmless.
  run_block "$BEFORE"

  assert_status 1
  assert_output_contains "#118"
}

test_before_passes_for_a_merged_release_pull_request() {
  before_env
  # The normal end state: merged, and keeping `autorelease: tagged` for good.
  closed_pr 122 merged "release-please--branches--main" \
    "$(labels "autorelease: tagged")"

  run_block "$BEFORE"

  assert_status 0
  assert_output_contains "no abandoned release pull request"
}

test_before_passes_for_a_closed_pull_request_with_no_autorelease_label() {
  before_env
  closed_pr 118 abandoned "release-please--branches--main" "$(labels "chore")"

  # Closed and unlabelled is release-please's own "start fresh" state: it opens
  # a new pull request and never looks at this one again.
  run_block "$BEFORE"

  assert_status 0
}

test_before_ignores_a_branch_that_is_not_release_pleases() {
  before_env
  closed_pr 90 abandoned "feat/some-work" "$(labels "autorelease: pending")"

  run_block "$BEFORE"

  assert_status 0
}

test_before_catches_a_monorepo_component_branch() {
  before_env
  closed_pr 118 abandoned "release-please--branches--main--components--pg" \
    "$(labels "autorelease: pending")"

  # One branch per package under the same prefix, all carrying the same hazard -
  # which is why this matches on the prefix instead of the exact branch.
  run_block "$BEFORE"

  assert_status 1
  assert_output_contains "#118"
}

test_before_scopes_the_hazard_to_the_branch_being_built() {
  before_env develop
  closed_pr 118 abandoned "release-please--branches--main" \
    "$(labels "autorelease: pending")"

  # A prerelease run computes against its own branch's release-please branch; a
  # poisoned pull request on main is main's run to fail, not this one's.
  run_block "$BEFORE"

  assert_status 0
}

# --- 'Assert a merged release pull request was released' ---------------------

after_env() {
  export GITHUB_REF_NAME="main"
  export GITHUB_SHA="$RELEASE_SHA"
  export RELEASES_CREATED=""
  export RELEASE_CREATED=""
  export TAG_NAME=""
}

# One merged pull request, as `gh pr list --state merged` reports it.
merged_pr() {
  local number="$1" sha="$2" head="$3"
  export STUB_GH_PR_LIST_JSON="[{
    \"number\": $number,
    \"title\": \"chore(main): release 0.21.0\",
    \"mergeCommit\": { \"oid\": \"$sha\" },
    \"headRefName\": \"$head\"
  }]"
}

test_after_is_a_noop_for_an_ordinary_commit() {
  after_env
  merged_pr 121 "$OTHER_SHA" "plugin-sweeps"

  run_block "$AFTER"

  assert_status 0
  assert_output_contains "not a merged release pull request"
}

test_after_passes_when_the_release_was_created() {
  after_env
  export RELEASES_CREATED="true"
  export TAG_NAME="v0.21.0"
  merged_pr 122 "$RELEASE_SHA" "release-please--branches--main"

  run_block "$AFTER"

  assert_status 0
  assert_output_contains "#122"
  assert_output_contains "v0.21.0"
}

test_after_accepts_the_root_component_output_on_its_own() {
  after_env
  # A single-package repository sets `release_created`; `releases_created` is
  # the mode-independent one. Either being true means the release happened.
  export RELEASE_CREATED="true"
  export TAG_NAME="v0.21.0"
  merged_pr 122 "$RELEASE_SHA" "release-please--branches--main"

  run_block "$AFTER"

  assert_status 0
}

test_after_fails_when_a_release_commit_produced_no_release() {
  after_env
  merged_pr 122 "$RELEASE_SHA" "release-please--branches--main"

  run_block "$AFTER"

  # The whole point: `release_created` false reads identically for an ordinary
  # commit and for a release commit that was never tagged, and every downstream
  # job gated on it skips either way.
  assert_status 1
  assert_output_contains "#122"
  assert_output_contains "no tag and no release exist"
  assert_output_contains "autorelease: pending"
}

test_after_names_the_whole_history_changelog_as_the_next_symptom() {
  after_env
  merged_pr 122 "$RELEASE_SHA" "release-please--branches--main"

  run_block "$AFTER"

  # The consequence that actually gets noticed, days later, on the next run:
  # with no tag to measure from there is no floor, so everything reads as
  # unreleased. Saying so is what connects the two.
  assert_output_contains "covering the whole history"
}

test_after_fails_when_release_please_itself_failed() {
  after_env
  unset RELEASES_CREATED RELEASE_CREATED TAG_NAME
  merged_pr 122 "$RELEASE_SHA" "release-please--branches--main"

  # The step runs under `!cancelled()`, so it also reports on a run where
  # release-please crashed and set no outputs at all - which is the most likely
  # way to get here, and where a raw API error is the only other clue.
  run_block "$AFTER"

  assert_status 1
  assert_output_contains "#122"
}

test_after_ignores_a_release_merged_by_a_concurrent_run() {
  after_env
  # Merged, unreleased, but not this run's commit: the run built from its own
  # merge is the one that has to answer for it.
  merged_pr 122 "$OTHER_SHA" "release-please--branches--main"

  run_block "$AFTER"

  assert_status 0
  assert_output_contains "not a merged release pull request"
}

test_after_matches_a_monorepo_component_branch() {
  after_env
  merged_pr 122 "$RELEASE_SHA" "release-please--branches--main--components--pg"

  run_block "$AFTER"

  assert_status 1
  assert_output_contains "#122"
}

run_tests
