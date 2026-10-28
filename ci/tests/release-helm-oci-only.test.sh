#!/usr/bin/env bash
# release-helm.yml with CREATE_GITHUB_RELEASE off, and the token that pushes the
# pages branch when it is on.
#
# chart-releaser-action cannot be told not to create a release: cr.sh runs
# `cr upload` unconditionally, so the only way to publish to the OCI registry
# without a GitHub Release (and without the tag) is not to run it. That leaves
# two things to pin: the action is skipped exactly when the input is off, and the
# step that packages in its place finds the same charts cr.sh would.
#
# The second half is the token. `cr index --push` pushes through `origin`, and git
# sends a credential persisted by actions/checkout in preference to the one
# chart-releaser puts in the push URL. So the token the checkout is given is the
# token that pushes, whatever CR_TOKEN says - the two expressions have to stay the
# same, or an App token creates the releases while GITHUB_TOKEN pushes the pages.

set -uo pipefail
# shellcheck source=ci/tests/lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

WORKFLOW="$WORKFLOWS_DIR/release-helm.yml"
JOB="release"

step_field() { # step name, yq path under the step
  yq -r ".jobs.$JOB.steps[] | select(.name == \"$1\") | $2" "$WORKFLOW"
}

# --- which step runs -------------------------------------------------------

test_chart_releaser_runs_only_when_a_release_is_wanted() {
  # shellcheck disable=SC2016 # the Actions marker is meant to stay literal
  [ "$(step_field 'Run chart-releaser' '.if')" = '${{ inputs.CREATE_GITHUB_RELEASE }}' ] || {
    echo "FAIL: 'Run chart-releaser' must be gated on CREATE_GITHUB_RELEASE, got: $(step_field 'Run chart-releaser' '.if')" >&2
    exit 1
  }
}

test_the_oci_only_packaging_runs_exactly_when_chart_releaser_does_not() {
  # shellcheck disable=SC2016
  [ "$(step_field 'Package the changed charts' '.if')" = '${{ !inputs.CREATE_GITHUB_RELEASE }}' ] || {
    echo "FAIL: 'Package the changed charts' must be gated on !CREATE_GITHUB_RELEASE, got: $(step_field 'Package the changed charts' '.if')" >&2
    exit 1
  }
}

# --- which token pushes ----------------------------------------------------

test_the_checkout_is_given_the_token_chart_releaser_pushes_with() {
  local checkout cr
  checkout=$(step_field 'Checks-out repository' '.with.token')
  cr=$(step_field 'Run chart-releaser' '.env.CR_TOKEN')
  if [ -z "$checkout" ] || [ "$checkout" = "null" ] || [ "$checkout" != "$cr" ]; then
    printf 'FAIL: the checkout token and CR_TOKEN must be the same expression.\n  checkout: %s\n  CR_TOKEN: %s\n' "$checkout" "$cr" >&2
    exit 1
  fi
}

test_the_credential_is_only_kept_when_chart_releaser_runs() {
  # shellcheck disable=SC2016
  [ "$(step_field 'Checks-out repository' '.with."persist-credentials"')" = '${{ inputs.CREATE_GITHUB_RELEASE }}' ] || {
    echo "FAIL: persist-credentials must follow CREATE_GITHUB_RELEASE" >&2
    exit 1
  }
}

# --- the packaging step ----------------------------------------------------

# The sandbox puts a stub git on PATH; this step needs the real thing, against a
# real repository, because what it decides is read off git's own answers.
use_real_git() { rm -f "$SANDBOX/bin/git"; }

install_helm_stub() {
  cat >"$SANDBOX/bin/helm" <<'STUB'
#!/usr/bin/env bash
printf 'helm|%s\n' "$*" >>"$CALL_LOG"
if [ "$1" = "package" ]; then
  chart="$2"; shift 2
  dest="."
  while [ "$#" -gt 0 ]; do
    [ "$1" = "--destination" ] && dest="$2"
    shift
  done
  mkdir -p "$dest"
  : >"$dest/$(basename "$chart")-0.1.0.tgz"
fi
STUB
  chmod +x "$SANDBOX/bin/helm"
}

new_repo() {
  mkdir -p "$SANDBOX/repo"
  cd "$SANDBOX/repo" || exit 1
  git init -q
  git config user.email t@example.com
  git config user.name t
}

commit() { git add -A && git commit -q -m "$1"; }

chart() { mkdir -p "$1" && printf 'name: %s\nversion: 0.1.0\n' "$(basename "$1")" >"$1/Chart.yaml"; }

package_step() {
  export CHARTS_DIR="${1:-charts}"
  run_block "$(extract_run release-helm.yml "$JOB" 'Package the changed charts')"
}

changed_charts() { sed -n 's/^changed_charts=//p' "$GITHUB_OUTPUT"; }

test_it_packages_only_the_charts_that_changed_since_the_latest_tag() {
  use_real_git; install_helm_stub; new_repo
  chart charts/a; chart charts/b; commit one
  git tag v0.1.0
  echo x >charts/b/values.yaml; commit two

  package_step

  assert_status 0
  assert_called "helm|package charts/b --dependency-update --destination .cr-release-packages"
  assert_not_called "charts/a"
  [ "$(changed_charts)" = "charts/b" ] || { echo "FAIL: changed_charts = $(changed_charts)" >&2; exit 1; }
  [ -f .cr-release-packages/b-0.1.0.tgz ] || { echo "FAIL: no package written" >&2; exit 1; }
}

test_a_change_made_before_the_latest_tag_is_not_packaged_again() {
  use_real_git; install_helm_stub; new_repo
  chart charts/a; commit one
  echo x >charts/a/values.yaml; commit two
  git tag v0.1.0
  echo y >README.md; commit three

  package_step

  assert_status 0
  assert_not_called "helm|package"
  [ -z "$(changed_charts)" ] || { echo "FAIL: expected nothing, got $(changed_charts)" >&2; exit 1; }
}

test_without_any_tag_it_measures_from_the_first_commit() {
  use_real_git; install_helm_stub; new_repo
  chart charts/a; commit one
  chart charts/b; commit two

  package_step

  assert_status 0
  [ "$(changed_charts)" = "charts/b" ] || { echo "FAIL: expected charts/b, got $(changed_charts)" >&2; exit 1; }
}

test_several_changed_charts_are_listed_comma_separated() {
  use_real_git; install_helm_stub; new_repo
  chart charts/a; chart charts/b; chart charts/c; commit one
  git tag v0.1.0
  echo x >charts/c/values.yaml; echo x >charts/a/values.yaml; commit two

  package_step

  assert_status 0
  [ "$(changed_charts)" = "charts/a,charts/c" ] || { echo "FAIL: changed_charts = $(changed_charts)" >&2; exit 1; }
  assert_call_count "helm|package" 2
}

test_a_directory_without_a_chart_yaml_is_not_a_chart() {
  use_real_git; install_helm_stub; new_repo
  chart charts/a; commit one
  git tag v0.1.0
  mkdir -p charts/notes && echo x >charts/notes/README.md; commit two

  package_step

  assert_status 0
  assert_not_called "helm|package"
}

test_a_dot_slash_charts_directory_is_read_the_same() {
  use_real_git; install_helm_stub; new_repo
  chart charts/a; commit one
  git tag v0.1.0
  echo x >charts/a/values.yaml; commit two

  package_step ./charts

  assert_status 0
  [ "$(changed_charts)" = "charts/a" ] || { echo "FAIL: changed_charts = $(changed_charts)" >&2; exit 1; }
}

test_a_nested_charts_directory_is_one_level_deeper() {
  use_real_git; install_helm_stub; new_repo
  chart deploy/charts/a; commit one
  git tag v0.1.0
  echo x >deploy/charts/a/values.yaml; commit two

  package_step deploy/charts

  assert_status 0
  [ "$(changed_charts)" = "deploy/charts/a" ] || { echo "FAIL: changed_charts = $(changed_charts)" >&2; exit 1; }
}

run_tests
