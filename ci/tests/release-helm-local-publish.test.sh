#!/usr/bin/env bash
# release-helm-local.yml - 'Package and push chart(s)': the published-charts
# output that attest-helm.yml consumes.
#
# The interesting part is where each entry's name and version come from. They
# are read back out of helm's own `Pushed:` line rather than split off the
# package filename, because '<name>-<version>.tgz' is ambiguous the moment a
# version carries a dash of its own - 'my-chart-1.2.3-rc.1.tgz' splits three
# different ways and only one of them is right. The stub therefore returns a
# prerelease reference throughout, so a regression to filename parsing fails
# here instead of shipping an attestation against the wrong version.

set -uo pipefail
# shellcheck source=ci/tests/lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

WORKFLOW="release-helm-local.yml"

# `package` writes a real (empty) file so the glob that follows it has something
# to find; `push` answers from STUB_HELM_PUSHED/STUB_HELM_DIGEST, and omits
# either line on demand to exercise the guard.
install_helm_stub() {
  cat >"$SANDBOX/bin/helm" <<'STUB'
#!/usr/bin/env bash
printf 'helm|%s\n' "$*" >>"$CALL_LOG"

case "$1" in
  package)
    chart="$2"
    dest="."
    prev=""
    for arg in "$@"; do
      [ "$prev" = "--destination" ] && dest="$arg"
      prev="$arg"
    done
    mkdir -p "$dest"
    # Holds the chart metadata so `show chart <package>` can answer from it.
    # `helm show chart` prints the keys in alphabetical order, so the indented
    # name: and version: lines of `dependencies:` come before the chart's own.
    printf 'apiVersion: v2\ndependencies:\n- condition: a-dependency.enabled\n  name: a-dependency\n  repository: https://example.com/charts\n  version: 9.9.9\nname: %s\nversion: %s%s%s\n' "$(basename "$chart")" "${STUB_HELM_QUOTE:-}" "${STUB_HELM_PACKAGE_VERSION:-1.2.3-rc.1}" "${STUB_HELM_QUOTE:-}" \
      >"$dest/$(basename "$chart")-${STUB_HELM_PACKAGE_VERSION:-1.2.3-rc.1}.tgz"
    ;;
  show)
    # `show chart <package>` reads the local package; `show chart oci://...`
    # is the "is this version published" probe. A chart named in
    # STUB_HELM_EXISTING is published; any other answers from STUB_HELM_SHOW
    # (missing | name-unknown | denied | garbage).
    ref="$3"
    if [ "${ref#oci://}" = "$ref" ]; then
      [ "${STUB_HELM_SHOW:-}" = "garbage" ] && { echo "not yaml: ["; exit 0; }
      cat "$ref"
      exit 0
    fi
    for existing in ${STUB_HELM_EXISTING:-}; do
      [ "${ref##*/}" = "$existing" ] && { printf 'name: %s\n' "$existing"; exit 0; }
    done
    case "${STUB_HELM_SHOW:-missing}" in
      missing) echo "Error: failed to perform \"FetchReference\" on source: ${ref#oci://}:$5: not found" >&2; exit 1 ;;
      name-unknown) echo "Error: GET https://ghcr.io/v2/x/manifests/1: NAME_UNKNOWN: name unknown to registry" >&2; exit 1 ;;
      denied) echo "Error: unexpected status from GET request: 401 Unauthorized: denied" >&2; exit 1 ;;
      garbage) echo "Error: failed to perform \"FetchReference\": not found" >&2; exit 1 ;;
    esac
    ;;
  push)
    [ "${STUB_HELM_PUSH_OMIT:-}" = "reference" ] || \
      printf 'Pushed: %s\n' "${STUB_HELM_PUSHED:-ghcr.io/owner/repo/my-chart:1.2.3-rc.1}"
    [ "${STUB_HELM_PUSH_OMIT:-}" = "digest" ] || \
      printf 'Digest: %s\n' "${STUB_HELM_DIGEST:-sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef}"
    ;;
esac
exit 0
STUB
  chmod +x "$SANDBOX/bin/helm"
}

# The step packages relative to the working directory and writes into
# .cr-release-packages, so every test runs inside its own sandbox rather than
# the checkout.
in_workspace() {
  mkdir -p "$SANDBOX/work"
  cd "$SANDBOX/work" || exit 1
}

make_chart() {
  mkdir -p "charts/$1"
  printf 'apiVersion: v2\nname: %s\nversion: 0.1.0\n' "$1" >"charts/$1/Chart.yaml"
}

publish_env() {
  export ALLOW_OVERWRITE="false"
  export CHART_PATH=""
  export CHARTS_DIR="./charts"
  export CHART_NAME="my-chart"
  export CHART_VERSION=""
  export APP_VERSION=""
  export REGISTRY="ghcr.io"
  export OCI_REPOSITORY=""
  export GITHUB_REPOSITORY="owner/repo"
}

run_publish() { run_block "$(extract_run "$WORKFLOW" release 'Package and push chart(s)')"; }

# Reads the published-charts value back out of the step's GITHUB_OUTPUT.
published() {
  sed -n 's/^published-charts=//p' "$GITHUB_OUTPUT"
}

assert_entry() {
  local field="$1" expected="$2" actual
  actual=$(published | jq -r ".[0].$field")
  if [ "$actual" != "$expected" ]; then
    printf 'FAIL: expected .%s to be %q, got %q\n---- published ----\n%s\n-------------------\n' \
      "$field" "$expected" "$actual" "$(published)" >&2
    exit 1
  fi
}

# --- what each entry records ------------------------------------------------

test_reads_name_and_version_from_helm_not_the_filename() {
  install_helm_stub
  in_workspace
  make_chart my-chart
  publish_env

  run_publish

  assert_status 0
  # Splitting 'my-chart-1.2.3-rc.1.tgz' on the last dash would yield version
  # '1' and name 'my-chart-1.2.3-rc'; on the first, name 'my'.
  assert_entry name "my-chart"
  assert_entry version "1.2.3-rc.1"
}

test_keeps_repository_and_digest_apart() {
  install_helm_stub
  in_workspace
  make_chart my-chart
  publish_env

  run_publish

  assert_status 0
  # attest-helm.yml feeds these to actions/attest-build-provenance as separate
  # subject-name and subject-digest inputs, so a pre-joined 'repo@sha256:...'
  # would have to be taken apart again there.
  assert_entry repository "ghcr.io/owner/repo/my-chart"
  assert_entry digest "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
}

test_publishes_every_chart_when_no_chart_name_is_given() {
  install_helm_stub
  in_workspace
  make_chart first
  make_chart second
  publish_env
  export CHART_NAME=""

  run_publish

  assert_status 0
  local count
  count=$(published | jq 'length')
  if [ "$count" != "2" ]; then
    printf 'FAIL: expected 2 published charts, got %s\n---- published ----\n%s\n-------------------\n' \
      "$count" "$(published)" >&2
    exit 1
  fi
}

# --- the guard --------------------------------------------------------------

# A digest is the whole point of the output: attesting a tag would bind the
# claim to whatever that tag resolves to at verification time. An entry without
# one must stop the run, not reach attest-helm.yml to be rejected there.
test_fails_when_helm_reports_no_digest() {
  install_helm_stub
  in_workspace
  make_chart my-chart
  publish_env
  export STUB_HELM_PUSH_OMIT="digest"

  run_publish

  assert_status 1
  assert_output_contains "Could not read the reference and digest"
}

test_fails_when_helm_reports_no_reference() {
  install_helm_stub
  in_workspace
  make_chart my-chart
  publish_env
  export STUB_HELM_PUSH_OMIT="reference"

  run_publish

  assert_status 1
  assert_output_contains "Could not read the reference and digest"
}

# --- the wiring -------------------------------------------------------------

# The step can keep writing a perfectly good published-charts to GITHUB_OUTPUT
# while the workflow forgets to surface it, and every test above would still
# pass with the output invisible to callers.
test_surfaces_published_charts_to_callers() {
  local declared
  declared=$(yq '
    [.on.workflow_call.outputs."published-charts".value, .jobs.release.outputs."published-charts"]
    | join(" ")
  ' "$WORKFLOWS_DIR/$WORKFLOW")

  # shellcheck disable=SC2016 # the Actions markers are meant to stay literal
  if [ "$declared" != '${{ jobs.release.outputs.published-charts }} ${{ steps.publish.outputs.published-charts }}' ]; then
    printf 'FAIL: published-charts is not wired from the publish step to the workflow output, got %q\n' \
      "$declared" >&2
    exit 1
  fi
}

# --- CHART_PATH: a chart whose directory is not named after it ---------------

test_chart_path_packages_that_directory() {
  install_helm_stub
  in_workspace
  mkdir -p utils/helm
  printf 'apiVersion: v2\nname: ohmlab\nversion: 0.1.0\n' >utils/helm/Chart.yaml
  publish_env
  export CHART_NAME=""
  export CHART_PATH="utils/helm/"
  export STUB_HELM_PUSHED="ghcr.io/owner/repo/ohmlab:0.1.0"

  run_publish

  assert_status 0
  assert_called "helm|package utils/helm --destination .cr-release-packages"
  assert_entry name "ohmlab"
}

test_chart_path_and_chart_name_together_fail() {
  install_helm_stub
  in_workspace
  make_chart my-chart
  publish_env
  export CHART_PATH="charts/my-chart"

  run_publish

  assert_status 1 "two ways to name the chart must not silently pick one"
  assert_output_contains "CHART_PATH and CHART_NAME are mutually exclusive"
  assert_not_called "helm|package"
}

test_chart_path_without_a_chart_fails_naming_the_path() {
  install_helm_stub
  in_workspace
  mkdir -p not-a-chart
  publish_env
  export CHART_NAME=""
  export CHART_PATH="not-a-chart"

  run_publish

  assert_status 1
  assert_output_contains "Chart.yaml not found in not-a-chart"
  assert_not_called "helm|package"
}

# --- never over a published version -------------------------------------------

# A consumer pins a chart by version and attest-helm.yml signs the digest it was
# pushed with: pushing again under the same version silently swaps what that
# version means and orphans its signature. So every package is checked first,
# and only a clear "not found" from the registry lets a push through.
test_refuses_a_version_that_is_already_published() {
  install_helm_stub
  in_workspace
  make_chart my-chart
  publish_env
  export STUB_HELM_EXISTING="my-chart"

  run_publish

  assert_status 1 "a published version must not be pushed again"
  assert_output_contains "my-chart 1.2.3-rc.1 is already published"
  assert_output_lacks "cannot tell"
  assert_not_called "helm|push"
}

test_probes_the_name_and_version_of_the_package() {
  install_helm_stub
  in_workspace
  make_chart my-chart
  publish_env
  export STUB_HELM_PACKAGE_VERSION="0.4.0"

  run_publish

  assert_status 0
  assert_called "helm|show chart oci://ghcr.io/owner/repo/my-chart --version 0.4.0"
  assert_called_before "helm|show chart oci://ghcr.io/owner/repo/my-chart --version 0.4.0" "helm|push"
}

test_a_registry_that_does_not_know_the_name_lets_the_push_through() {
  install_helm_stub
  in_workspace
  make_chart my-chart
  publish_env
  export STUB_HELM_SHOW="name-unknown"

  run_publish

  assert_status 0
  assert_called "helm|push"
}

test_any_other_registry_answer_stops_before_pushing() {
  install_helm_stub
  in_workspace
  make_chart my-chart
  publish_env
  export STUB_HELM_SHOW="denied"

  run_publish

  assert_status 1 "an error that is not 'not found' says nothing about the version"
  assert_output_contains "cannot tell whether my-chart 1.2.3-rc.1 is published"
  assert_not_called "helm|push"
}

test_checks_every_chart_before_pushing_any() {
  install_helm_stub
  in_workspace
  make_chart first
  make_chart second
  publish_env
  export CHART_NAME=""
  export STUB_HELM_EXISTING="second"

  run_publish

  assert_status 1 "a run must not publish half of its charts"
  assert_output_contains "second 1.2.3-rc.1 is already published"
  assert_not_called "helm|push"
}

test_allow_overwrite_pushes_without_probing() {
  install_helm_stub
  in_workspace
  make_chart my-chart
  publish_env
  export ALLOW_OVERWRITE="true"
  export STUB_HELM_EXISTING="my-chart"

  run_publish

  assert_status 0
  assert_not_called "helm|show chart oci://"
  assert_called "helm|push"
}

test_a_quoted_version_in_the_package_is_read() {
  install_helm_stub
  in_workspace
  make_chart my-chart
  publish_env
  export STUB_HELM_PACKAGE_VERSION="0.4.0"

  for quote in '"' "'"; do
    : >"$CALL_LOG"
    rm -rf .cr-release-packages
    export STUB_HELM_QUOTE="$quote"
    run_publish
    assert_status 0
    assert_called "helm|show chart oci://ghcr.io/owner/repo/my-chart --version 0.4.0"
  done
}

test_a_package_without_a_name_and_version_stops() {
  install_helm_stub
  in_workspace
  make_chart my-chart
  publish_env
  export STUB_HELM_SHOW="garbage"

  run_publish

  assert_status 1
  assert_output_contains "cannot read the name and version"
  assert_not_called "helm|push"
}

run_tests
