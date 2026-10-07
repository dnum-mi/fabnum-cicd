#!/usr/bin/env bash
# sync-prerelease-branch.yml - what the rebase does to release-please's
# starting point, against real git repositories.
#
# The stubbed suite (sync-prerelease-branch.test.sh) records calls. Conflicts on
# the files a release rewrites, the replayed release commit and the
# `last-release-sha` anchor only mean something against real history, so these
# tests build it: a release branch and a prerelease branch with two tagged
# prereleases, then a hotfix released on the release branch.

# shellcheck source=ci/tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# shellcheck disable=SC2016 # the Actions marker is meant to stay literal
BLOCK=$(extract_run sync-prerelease-branch.yml sync 'Ensure ${{ inputs.PRERELEASE_BRANCH }} is up to date with ${{ inputs.RELEASE_BRANCH }}')

use_real_git() {
  rm -f "$SANDBOX/bin/git"
  export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
  export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
}

# commit <message> <spec>...  where a spec is `path=content`, or `-path` to
# delete the file.
commit() {
  local message="$1" spec path
  shift
  for spec in "$@"; do
    if [[ "$spec" == -* ]]; then
      git rm -q -- "${spec#-}"
      continue
    fi
    path="${spec%%=*}"
    mkdir -p "$(dirname "$path")"
    printf '%s\n' "${spec#*=}" >"$path"
    git add -- "$path"
  done
  git commit -q -m "$message"
}

assert_equal() {
  if [ "$1" != "$2" ]; then
    printf 'FAIL: %s: expected %q, got %q\n' "$3" "$1" "$2" >&2
    exit 1
  fi
}

# The history every test starts from:
#
#   main:     1.0.0 released
#   develop:  1.1.0-rc and 1.1.0-rc.1 released on top of it, each tagged
#   main:     a hotfix, released as 1.0.1 (the release commit rewrites both
#             manifests, as release-please does on the release branch)
#
# Then a fresh clone of it, the way a CI job sees the repository. Knobs, set by
# the test before calling:
#   WITH_HOTFIX=false     leave the release branch where it was
#   WITH_PROMOTION=true   copy the prerelease series onto the release branch, the
#                         way a rebase-merge promotion does (new SHAs)
#   DEVELOP_EXTRA         extra `path=content` specs for a develop commit
#   HOTFIX_EXTRA          extra `path=content` specs for the hotfix commit
#   RC_MANIFEST           the prerelease manifest the last prerelease writes
build_history() {
  local with_hotfix="${WITH_HOTFIX:-true}" rc_manifest="${RC_MANIFEST:-}"
  [ -n "$rc_manifest" ] || rc_manifest='{".": "1.1.0-rc.1"}'

  ORIGIN="$SANDBOX/origin.git"
  local seed="$SANDBOX/seed"
  git init -q --bare -b main "$ORIGIN"
  git init -q -b main "$seed"
  cd "$seed" || exit 1
  git remote add origin "$ORIGIN"

  commit "chore(main): release 1.0.0" \
    app.txt=base \
    version.txt=1.0.0 \
    pins.txt=$'v=1.0.0\na\nb\nc\nd\ne\nf\ndep=old' \
    CHANGELOG.md="## 1.0.0" \
    .release-please-manifest.json='{".": "1.0.0"}' \
    .release-please-manifest-rc.json='{".": "1.0.0"}' \
    release-please-config-rc.json='{"packages": {".": {"extra-files": ["version.txt"]}}}'
  git tag v1.0.0
  git push -q origin main --tags

  git checkout -q -b develop
  commit "feat: new thing" feature.txt=new ${DEVELOP_EXTRA[@]+"${DEVELOP_EXTRA[@]}"}
  commit "chore(develop): release 1.1.0-rc" \
    CHANGELOG.md=$'## 1.1.0-rc\n## 1.0.0' \
    version.txt=1.1.0-rc \
    .release-please-manifest-rc.json='{".": "1.1.0-rc"}'
  git tag v1.1.0-rc
  commit "fix: other thing" fix.txt=other
  commit "chore(develop): release 1.1.0-rc.1" \
    CHANGELOG.md=$'## 1.1.0-rc.1\n## 1.0.0' \
    version.txt=1.1.0-rc.1 \
    .release-please-manifest-rc.json="$rc_manifest"
  git tag v1.1.0-rc.1
  git push -q origin develop --tags

  if [ "${WITH_PROMOTION:-false}" = "true" ]; then
    git checkout -q main
    # A later committer date, or an unchanged parent and timestamp would give
    # the copies the very same SHAs and there would be nothing to orphan.
    GIT_COMMITTER_DATE="2030-01-01T00:00:00Z" git cherry-pick v1.0.0..develop >/dev/null
    git push -q origin main
  fi

  if [ "$with_hotfix" = "true" ]; then
    git checkout -q main
    commit "fix: hotfix" hotfix.txt=urgent ${HOTFIX_EXTRA[@]+"${HOTFIX_EXTRA[@]}"}
    commit "chore(main): release 1.0.1" \
      CHANGELOG.md=$'## 1.0.1\n## 1.0.0' \
      version.txt=1.0.1 \
      .release-please-manifest.json='{".": "1.0.1"}' \
      .release-please-manifest-rc.json='{".": "1.0.1"}'
    git tag v1.0.1
    git push -q origin main --tags
  fi

  CI_CLONE="$SANDBOX/ci"
  git clone -q "$ORIGIN" "$CI_CLONE"
  cd "$CI_CLONE" || exit 1
}

sync_env() {
  export RELEASE_BRANCH="main"
  export PRERELEASE_BRANCH="develop"
  export CREATE_IF_MISSING="true"
  export HAS_PARTIAL_APP_AUTH="false"
  export PRERELEASE_CONFIG_FILE="release-please-config-rc.json"
  export PRERELEASE_MANIFEST_FILE=".release-please-manifest-rc.json"
  export RELEASE_MANIFEST_FILE=".release-please-manifest.json"
  # The caller's MANAGED_FILES input, nothing from the environment.
  export MANAGED_FILES="${1:-}"
}

remote_develop() {
  git -C "$ORIGIN" rev-parse develop
}

test_anchors_release_please_on_the_replayed_release_commit_after_a_hotfix() {
  use_real_git
  build_history
  sync_env

  run_block "$BLOCK"

  assert_status 0
  # The prerelease tag no longer points into the branch: the rebase replayed
  # that release commit under a new SHA, which is where release-please has to
  # start from.
  if git merge-base --is-ancestor v1.1.0-rc.1 HEAD; then
    echo "FAIL: the test is meaningless if the tag survived the rebase" >&2
    exit 1
  fi
  local replayed
  replayed=$(git log --format=%H --grep='^chore(develop): release 1.1.0-rc.1$' -1 HEAD)
  assert_equal "$replayed" "$(jq -r '.["last-release-sha"]' release-please-config-rc.json)" "last-release-sha"
  assert_equal "chore(develop): anchor release-please on 1.1.0-rc.1" "$(git log -1 --format=%s)" "anchor commit subject"
  assert_output_contains "Anchored release-please on $replayed"
}

test_the_rebased_branch_is_pushed_and_contains_the_release_branch() {
  use_real_git
  build_history
  sync_env

  run_block "$BLOCK"

  assert_status 0
  assert_equal "$(git rev-parse HEAD)" "$(remote_develop)" "pushed develop"
  git merge-base --is-ancestor v1.0.1 "$(remote_develop)" || {
    echo "FAIL: the hotfix release is not in develop" >&2
    exit 1
  }
}

test_keeps_the_prerelease_side_of_the_files_a_release_rewrites() {
  use_real_git
  build_history
  sync_env

  run_block "$BLOCK"

  # Both branches rewrote these in their own release commits; what the
  # prerelease branch holds is the state its next version is computed from.
  assert_status 0
  assert_equal "1.1.0-rc.1" "$(cat version.txt)" "version.txt (an extra-file of the config)"
  assert_equal "1.1.0-rc.1" "$(jq -r '.["."]' .release-please-manifest-rc.json)" "prerelease manifest"
  assert_output_contains "merged hunk by hunk"
}

test_keeps_what_the_release_branch_changed_outside_the_conflicting_hunk() {
  use_real_git
  DEVELOP_EXTRA=(pins.txt=$'v=1.1.0-rc\na\nb\nc\nd\ne\nf\ndep=old')
  HOTFIX_EXTRA=(pins.txt=$'v=1.0.1\na\nb\nc\nd\ne\nf\ndep=SECURITY-FIX')
  build_history
  sync_env pins.txt

  run_block "$BLOCK"

  # Both changed the first line; only the hotfix changed the last one. Taking
  # the prerelease side of the whole file would silently drop the fix.
  assert_status 0
  assert_equal "v=1.1.0-rc" "$(head -n 1 pins.txt)" "the conflicting line goes to the prerelease side"
  assert_equal "dep=SECURITY-FIX" "$(tail -n 1 pins.txt)" "the hotfix's own hunk survives"
}

test_keeps_the_changelog_sections_of_both_branches() {
  use_real_git
  build_history
  sync_env

  run_block "$BLOCK"

  # A changelog records history: the hotfix's section must not disappear from
  # the prerelease branch, or the next promotion would remove it from main.
  assert_status 0
  grep -qx '## 1.0.1' CHANGELOG.md || {
    echo "FAIL: the 1.0.1 section is gone" >&2
    cat CHANGELOG.md >&2
    exit 1
  }
  grep -qx '## 1.1.0-rc.1' CHANGELOG.md || {
    echo "FAIL: the 1.1.0-rc.1 section is gone" >&2
    cat CHANGELOG.md >&2
    exit 1
  }
}

test_resolves_a_conflict_on_the_release_manifest_with_the_release_branch_side() {
  use_real_git
  DEVELOP_EXTRA=(.release-please-manifest.json='{".": "1.0.0-edited-on-develop"}')
  build_history
  sync_env

  run_block "$BLOCK"

  # It records what the release branch published: a stale copy promoted to
  # main would have release-please compute from a version below it.
  assert_status 0
  assert_equal "1.0.1" "$(jq -r '.["."]' .release-please-manifest.json)" "release manifest"
}

test_fails_when_a_managed_file_was_deleted_on_one_side() {
  use_real_git
  DEVELOP_EXTRA=(pins.txt=$'v=1.1.0-rc\na\nb\nc\nd\ne\nf\ndep=old')
  HOTFIX_EXTRA=(-pins.txt)
  build_history
  sync_env pins.txt
  local before
  before=$(remote_develop)

  run_block "$BLOCK"

  # There is no side to take when the other side removed the file.
  assert_status 1
  assert_output_contains "deleted on one side"
  assert_equal "$before" "$(remote_develop)" "remote develop is untouched"
}

test_resolves_a_managed_file_whose_name_has_glob_characters() {
  use_real_git
  DEVELOP_EXTRA=('docs/a b[1].md=develop')
  HOTFIX_EXTRA=('docs/a b[1].md=hotfix')
  build_history
  sync_env 'docs/a b[1].md'

  run_block "$BLOCK"

  # Listed as a plain path, matched as one, and handed to git as one.
  assert_status 0
  assert_equal "develop" "$(cat 'docs/a b[1].md')" "the file"
}

test_refuses_to_overwrite_a_commit_that_lands_while_it_runs() {
  use_real_git
  build_history
  sync_env
  local real_git racer
  real_git=$(command -v git)

  # A commit reaches develop after the rebase, just before the tags are
  # fetched. A lease that followed the remote-tracking branch would be moved by
  # that fetch (any fetch that updates branches) and let the push overwrite it.
  racer=$(git -C "$ORIGIN" commit-tree -p develop -m "fix: landed meanwhile" "develop^{tree}")
  cat >"$SANDBOX/bin/git" <<SHIM
#!/usr/bin/env bash
case " \$* " in
  *refs/tags*|*" --tags "*) "$real_git" --git-dir="$ORIGIN" update-ref refs/heads/develop "$racer" ;;
esac
exec "$real_git" "\$@"
SHIM
  chmod +x "$SANDBOX/bin/git"

  run_block "$BLOCK"

  assert_status 1
  assert_equal "$racer" "$(remote_develop)" "the commit that landed meanwhile is still there"
}

test_a_second_sync_adds_no_further_anchor_commit() {
  use_real_git
  build_history
  sync_env

  run_block "$BLOCK"
  assert_status 0
  local first
  first=$(git rev-parse HEAD)

  run_block "$BLOCK"

  # Nothing moved on the release branch: the rebase has nothing to replay, the
  # tag is still orphaned, and the key already names the replayed commit.
  assert_status 0
  assert_equal "$first" "$(git rev-parse HEAD)" "develop after a second sync"
  assert_equal "$first" "$(remote_develop)" "remote develop after a second sync"
}

test_a_later_rebase_refreshes_the_anchor() {
  use_real_git
  build_history
  sync_env

  run_block "$BLOCK"
  assert_status 0

  # A second hotfix lands on the release branch: the rebase replays the whole
  # series again, so the commit the key names is gone.
  git -C "$SANDBOX/seed" checkout -q main
  (
    cd "$SANDBOX/seed" || exit 1
    commit "fix: another hotfix" hotfix2.txt=again
    git push -q origin main
  )
  run_block "$BLOCK"

  assert_status 0
  local replayed
  replayed=$(git log --format=%H --grep='^chore(develop): release 1.1.0-rc.1$' -1 HEAD)
  assert_equal "$replayed" "$(jq -r '.["last-release-sha"]' release-please-config-rc.json)" "refreshed last-release-sha"
  git cat-file -e "$replayed^{commit}"
}

test_anchors_on_the_promoted_copy_of_the_release_commit_after_a_rebase_merge_promotion() {
  use_real_git
  WITH_HOTFIX=false WITH_PROMOTION=true build_history
  sync_env

  run_block "$BLOCK"

  # The promotion copied the whole series onto the release branch, so the
  # rebase finds every prerelease commit already upstream and drops it: the
  # prerelease branch equals the release branch, and the prerelease tags still
  # point at the originals. The manifest keeps naming the last prerelease until
  # the stable release lands, so a first commit on the prerelease branch in
  # between would leave release-please without a starting point.
  assert_status 0
  if git merge-base --is-ancestor v1.1.0-rc.1 HEAD; then
    echo "FAIL: the test is meaningless if the tag survived the promotion" >&2
    exit 1
  fi
  local promoted
  promoted=$(git log --format=%H --grep='^chore(develop): release 1.1.0-rc.1$' -1 origin/main)
  assert_equal "$promoted" "$(jq -r '.["last-release-sha"]' release-please-config-rc.json)" "last-release-sha"
  assert_equal "1" "$(git rev-list --count origin/main..HEAD)" "the anchor is the only commit of its own"
  assert_equal "chore(develop): anchor release-please on 1.1.0-rc.1" "$(git log -1 --format=%s)" "anchor commit subject"
}

test_warns_when_the_release_commit_is_nowhere_to_be_found() {
  use_real_git
  build_history
  sync_env
  # A prerelease tag on a commit that is on no branch, with a subject nothing
  # else carries: its release commit cannot be found anywhere.
  local orphan
  orphan=$(git -C "$SANDBOX/seed" commit-tree -m "chore(develop): release 1.1.0-rc.1 (orphan)" "main^{tree}")
  git -C "$SANDBOX/seed" tag -f v1.1.0-rc.1 "$orphan" >/dev/null
  git -C "$SANDBOX/seed" push -q -f origin v1.1.0-rc.1
  git fetch -q --tags --force origin

  run_block "$BLOCK"

  assert_status 0
  assert_output_contains "Could not find the release commit of 1.1.0-rc.1"
  assert_equal "null" "$(jq -r '.["last-release-sha"]' release-please-config-rc.json)" "no anchor key"
}

test_does_not_anchor_when_no_prerelease_tag_was_orphaned() {
  use_real_git
  WITH_HOTFIX=false build_history
  sync_env
  local before
  before=$(remote_develop)

  run_block "$BLOCK"

  # The release branch has not moved: the rebase is a no-op, every tag is
  # still in the branch, and there is nothing to anchor.
  assert_status 0
  assert_equal "$before" "$(git rev-parse HEAD)" "develop is unchanged"
  assert_equal "null" "$(jq -r '.["last-release-sha"]' release-please-config-rc.json)" "no anchor key"
}

test_fails_on_a_conflict_in_a_file_a_release_does_not_rewrite() {
  use_real_git
  DEVELOP_EXTRA=(app.txt=develop-change)
  HOTFIX_EXTRA=(app.txt=hotfix-change)
  build_history
  sync_env
  local before
  before=$(remote_develop)

  run_block "$BLOCK"

  # That one is real work: silently keeping develop's version would drop the
  # hotfix from the branch.
  assert_status 1
  assert_output_contains "'app.txt' conflicts"
  assert_output_contains "failed due to conflicts"
  assert_equal "$before" "$(remote_develop)" "remote develop is untouched"
  [ ! -d "$(git rev-parse --git-path rebase-merge)" ] || {
    echo "FAIL: the rebase was left in progress" >&2
    exit 1
  }
}

test_fails_on_a_file_that_is_not_listed_as_managed() {
  use_real_git
  DEVELOP_EXTRA=(helm/Chart.yaml=develop)
  HOTFIX_EXTRA=(helm/Chart.yaml=hotfix)
  build_history
  sync_env

  run_block "$BLOCK"

  assert_status 1
  assert_output_contains "'helm/Chart.yaml' conflicts"
}

test_resolves_a_conflict_on_a_file_the_caller_lists_as_managed() {
  use_real_git
  DEVELOP_EXTRA=(helm/Chart.yaml=develop)
  HOTFIX_EXTRA=(helm/Chart.yaml=hotfix)
  build_history
  sync_env $'helm/*.yaml\nhelm/README.md'

  run_block "$BLOCK"

  assert_status 0
  assert_equal "develop" "$(cat helm/Chart.yaml)" "helm/Chart.yaml"
}

test_does_not_maintain_an_anchor_for_a_manifest_with_several_packages() {
  use_real_git
  RC_MANIFEST='{".": "1.1.0-rc.1", "other": "0.1.0"}' build_history
  sync_env

  run_block "$BLOCK"

  # last-release-sha is a single commit for the whole repository: it cannot
  # stand for the starting point of two packages.
  assert_status 0
  assert_output_contains "does not track exactly one package"
  assert_equal "null" "$(jq -r '.["last-release-sha"]' release-please-config-rc.json)" "no anchor key"
}

test_aborts_the_rebase_and_pushes_nothing_when_it_cannot_resolve() {
  use_real_git
  DEVELOP_EXTRA=(app.txt=develop-change)
  HOTFIX_EXTRA=(app.txt=hotfix-change)
  build_history
  sync_env
  local before
  before=$(remote_develop)

  run_block "$BLOCK"

  assert_status 1
  assert_equal "$before" "$(remote_develop)" "remote develop"
  assert_output_lacks "Pushing updated"
}

run_tests
