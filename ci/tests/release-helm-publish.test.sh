#!/usr/bin/env bash
# release-helm.yml - 'Publish charts to OCI registry': what is pushed, what is
# left alone, and the published-charts output that attest-helm.yml consumes.
#
# chart-releaser packages every chart that changed since the last tag, a change
# that does not bump the version included. Such a package carries a version the
# registry already holds, and pushing it again would silently change what that
# version means (a consumer pins by version, and its signature is bound to the
# digest first pushed). So the step looks each version up first: it leaves it
# alone with SKIP_EXISTING and stops the run without.
#
# The stub answers a prerelease version throughout, so a regression to parsing
# the file name ('my-chart-1.2.3-rc.1.tgz' splits three different ways, and only
# one of them is right) fails here instead of attesting the wrong version.

set -uo pipefail
# shellcheck source=ci/tests/lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

WORKFLOW="release-helm.yml"

# `show chart <package>` reads the metadata the package fixture holds, and
# `show chart oci://...` is the "is this version published" probe: a chart named
# in STUB_HELM_EXISTING is published, any other answers from STUB_HELM_SHOW
# (missing | name-unknown | denied | garbage). `push` answers from
# STUB_HELM_DIGEST and echoes the reference it was given, so each chart gets its
# own Pushed: line; STUB_HELM_PUSH_OMIT drops either line to exercise the guard.
install_helm_stub() {
  cat >"$SANDBOX/bin/helm" <<'STUB'
#!/usr/bin/env bash
printf 'helm|%s\n' "$*" >>"$CALL_LOG"

case "$1" in
  show)
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
    package=$(basename "$2" .tgz)
    chart="${package%-"${STUB_HELM_PACKAGE_VERSION:-1.2.3-rc.1}"}"
    [ "${STUB_HELM_PUSH_OMIT:-}" = "reference" ] || \
      printf 'Pushed: %s/%s:%s\n' "${3#oci://}" "$chart" "${STUB_HELM_PACKAGE_VERSION:-1.2.3-rc.1}"
    [ "${STUB_HELM_PUSH_OMIT:-}" = "digest" ] || \
      printf 'Digest: %s\n' "${STUB_HELM_DIGEST:-sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef}"
    ;;
esac
exit 0
STUB
  chmod +x "$SANDBOX/bin/helm"
}

# The step reads .cr-release-packages relative to the working directory, so every
# test runs inside its own sandbox rather than the checkout.
in_workspace() {
  mkdir -p "$SANDBOX/work"
  cd "$SANDBOX/work" || exit 1
}

# A package holds the chart metadata `helm show chart` prints, keys in
# alphabetical order: the indented name: and version: lines of `dependencies:`
# come before the chart's own, which the step has to step over.
make_package() {
  mkdir -p .cr-release-packages
  printf 'apiVersion: v2\ndependencies:\n- condition: a-dependency.enabled\n  name: a-dependency\n  repository: https://example.com/charts\n  version: 9.9.9\nname: %s\nversion: %s%s%s\n' \
    "$1" "${STUB_HELM_QUOTE:-}" "${STUB_HELM_PACKAGE_VERSION:-1.2.3-rc.1}" "${STUB_HELM_QUOTE:-}" \
    >".cr-release-packages/$1-${STUB_HELM_PACKAGE_VERSION:-1.2.3-rc.1}.tgz"
}

publish_env() {
  export SKIP_EXISTING="false"
  export REGISTRY="ghcr.io"
  export OCI_REPOSITORY=""
  export GITHUB_REPOSITORY="owner/repo"
}

run_publish() { run_block "$(extract_run "$WORKFLOW" release 'Publish charts to OCI registry')"; }

# Reads the published-charts value back out of the step's GITHUB_OUTPUT.
published() {
  sed -n 's/^published-charts=//p' "$GITHUB_OUTPUT"
}

assert_entry() {
  local index="$1" field="$2" expected="$3" actual
  actual=$(published | jq -r ".[$index].$field")
  if [ "$actual" != "$expected" ]; then
    printf 'FAIL: expected [%s].%s to be %q, got %q\n---- published ----\n%s\n-------------------\n' \
      "$index" "$field" "$expected" "$actual" "$(published)" >&2
    exit 1
  fi
}

assert_published_count() {
  local actual
  actual=$(published | jq 'length')
  if [ "$actual" != "$1" ]; then
    printf 'FAIL: expected %s published charts, got %s\n---- published ----\n%s\n-------------------\n' \
      "$1" "$actual" "$(published)" >&2
    exit 1
  fi
}

# --- what each entry records ------------------------------------------------

test_reads_name_and_version_from_helm_not_the_filename() {
  install_helm_stub
  in_workspace
  make_package my-chart
  publish_env

  run_publish

  assert_status 0
  # Splitting 'my-chart-1.2.3-rc.1.tgz' on the last dash would yield version
  # '1' and name 'my-chart-1.2.3-rc'; on the first, name 'my'.
  assert_entry 0 name "my-chart"
  assert_entry 0 version "1.2.3-rc.1"
}

test_keeps_repository_and_digest_apart() {
  install_helm_stub
  in_workspace
  make_package my-chart
  publish_env

  run_publish

  assert_status 0
  # attest-helm.yml feeds these to actions/attest-build-provenance as separate
  # subject-name and subject-digest inputs, so a pre-joined 'repo@sha256:...'
  # would have to be taken apart again there.
  assert_entry 0 repository "ghcr.io/owner/repo/my-chart"
  assert_entry 0 digest "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
}

test_publishes_every_package_that_is_not_in_the_registry() {
  install_helm_stub
  in_workspace
  make_package first
  make_package second
  publish_env

  run_publish

  assert_status 0
  assert_published_count 2
  assert_call_count "helm|push" 2
}

# A digest is the whole point of the output: attesting a tag would bind the
# claim to whatever that tag resolves to at verification time. An entry without
# one must stop the run, not reach attest-helm.yml to be rejected there.
test_fails_when_helm_reports_no_digest() {
  install_helm_stub
  in_workspace
  make_package my-chart
  publish_env
  export STUB_HELM_PUSH_OMIT="digest"

  run_publish

  assert_status 1
  assert_output_contains "Could not read the reference and digest"
}

test_fails_when_helm_reports_no_reference() {
  install_helm_stub
  in_workspace
  make_package my-chart
  publish_env
  export STUB_HELM_PUSH_OMIT="reference"

  run_publish

  assert_status 1
  assert_output_contains "Could not read the reference and digest"
}

test_fails_when_chart_releaser_produced_no_package() {
  install_helm_stub
  in_workspace
  publish_env

  run_publish

  assert_status 1
  assert_output_contains "produced no package"
  assert_not_called "helm|push"
}

# --- never over a published version -------------------------------------------

test_refuses_a_version_that_is_already_published() {
  install_helm_stub
  in_workspace
  make_package my-chart
  publish_env
  export STUB_HELM_EXISTING="my-chart"

  run_publish

  assert_status 1 "a published version must not be pushed again"
  assert_output_contains "my-chart 1.2.3-rc.1 is already published"
  assert_output_contains "SKIP_EXISTING"
  assert_output_lacks "cannot tell"
  assert_not_called "helm|push"
}

test_probes_the_name_and_version_of_the_package() {
  install_helm_stub
  in_workspace
  export STUB_HELM_PACKAGE_VERSION="0.4.0"
  make_package my-chart
  publish_env

  run_publish

  assert_status 0
  assert_called "helm|show chart oci://ghcr.io/owner/repo/my-chart --version 0.4.0"
  assert_called_before "helm|show chart oci://ghcr.io/owner/repo/my-chart --version 0.4.0" "helm|push"
}

test_probes_the_repository_it_was_given() {
  install_helm_stub
  in_workspace
  make_package my-chart
  publish_env
  export REGISTRY="registry.example.com"
  export OCI_REPOSITORY="My_Org/Helm_Charts"

  run_publish

  assert_status 0
  # Lowercased and with '_' replaced, exactly as the push target is.
  assert_called "helm|show chart oci://registry.example.com/my-org/helm-charts/my-chart --version 1.2.3-rc.1"
  assert_called "helm|push .cr-release-packages/my-chart-1.2.3-rc.1.tgz oci://registry.example.com/my-org/helm-charts"
}

test_a_registry_that_does_not_know_the_name_lets_the_push_through() {
  install_helm_stub
  in_workspace
  make_package my-chart
  publish_env
  export STUB_HELM_SHOW="name-unknown"

  run_publish

  assert_status 0
  assert_called "helm|push"
}

test_any_other_registry_answer_stops_before_pushing() {
  install_helm_stub
  in_workspace
  make_package my-chart
  publish_env
  export STUB_HELM_SHOW="denied"

  run_publish

  assert_status 1 "an error that is not 'not found' says nothing about the version"
  assert_output_contains "cannot tell whether my-chart 1.2.3-rc.1 is published"
  assert_not_called "helm|push"
}

# Leaving a version alone is for a version the registry says it holds. A registry
# that cannot be asked is not a reason to push, whatever the caller opted into.
test_skip_existing_does_not_turn_an_unreadable_answer_into_a_push() {
  install_helm_stub
  in_workspace
  make_package my-chart
  publish_env
  export SKIP_EXISTING="true"
  export STUB_HELM_SHOW="denied"

  run_publish

  assert_status 1
  assert_output_contains "cannot tell whether my-chart 1.2.3-rc.1 is published"
  assert_not_called "helm|push"
}

test_checks_every_package_before_pushing_any() {
  install_helm_stub
  in_workspace
  make_package first
  make_package second
  publish_env
  export STUB_HELM_EXISTING="second"

  run_publish

  assert_status 1 "a run must not publish half of its charts"
  assert_output_contains "second 1.2.3-rc.1 is already published"
  assert_not_called "helm|push"
}

# --- SKIP_EXISTING --------------------------------------------------------------

test_skip_existing_leaves_a_published_version_alone() {
  install_helm_stub
  in_workspace
  make_package my-chart
  publish_env
  export SKIP_EXISTING="true"
  export STUB_HELM_EXISTING="my-chart"

  run_publish

  assert_status 0
  assert_output_contains "my-chart 1.2.3-rc.1 is already published"
  assert_output_contains "leaving it as it is"
  assert_not_called "helm|push"
}

# An empty list, not a missing output: attest-helm.yml documents `[]` as its
# no-op, and the version left alone keeps the signature of the digest it was
# first pushed with, so it must not reach attestation a second time.
test_skip_existing_publishes_nothing_when_every_version_is_published() {
  install_helm_stub
  in_workspace
  make_package first
  make_package second
  publish_env
  export SKIP_EXISTING="true"
  export STUB_HELM_EXISTING="first second"

  run_publish

  assert_status 0
  assert_published_count 0
  assert_not_called "helm|push"
}

test_skip_existing_still_publishes_the_others() {
  install_helm_stub
  in_workspace
  make_package first
  make_package second
  publish_env
  export SKIP_EXISTING="true"
  export STUB_HELM_EXISTING="first"

  run_publish

  assert_status 0
  assert_published_count 1
  assert_entry 0 name "second"
  assert_call_count "helm|push" 1
  assert_not_called "helm|push .cr-release-packages/first-"
}

# Only the literal "true" opts in, so a typo or an empty value cannot weaken the
# guard: it would leave a published version alone silently.
test_anything_but_true_keeps_the_refusal() {
  install_helm_stub
  in_workspace
  make_package my-chart
  publish_env
  export STUB_HELM_EXISTING="my-chart"

  for value in "" "false" "1" "yes"; do
    export SKIP_EXISTING="$value"
    run_publish
    assert_status 1 "SKIP_EXISTING='$value'"
    assert_output_contains "refusing to push over it"
  done
  assert_not_called "helm|push"
}

# --- reading the package ------------------------------------------------------

test_a_quoted_version_in_the_package_is_read() {
  install_helm_stub
  in_workspace
  export STUB_HELM_PACKAGE_VERSION="0.4.0"
  publish_env

  for quote in '"' "'"; do
    : >"$CALL_LOG"
    export STUB_HELM_QUOTE="$quote"
    make_package my-chart
    run_publish
    assert_status 0
    assert_called "helm|show chart oci://ghcr.io/owner/repo/my-chart --version 0.4.0"
  done
}

test_a_package_without_a_name_and_version_stops() {
  install_helm_stub
  in_workspace
  make_package my-chart
  publish_env
  export STUB_HELM_SHOW="garbage"

  run_publish

  assert_status 1
  assert_output_contains "cannot read the name and version"
  assert_not_called "helm|push"
}

# --- the wiring -------------------------------------------------------------

# The step can honour SKIP_EXISTING perfectly while the workflow never hands it
# the value, and every test above would still pass.
test_hands_skip_existing_to_the_publish_step() {
  local declared
  declared=$(yq '
    .jobs.release.steps[]
    | select(.id == "publish")
    | .env.SKIP_EXISTING
  ' "$WORKFLOWS_DIR/$WORKFLOW")

  # shellcheck disable=SC2016 # the Actions markers are meant to stay literal
  if [ "$declared" != '${{ inputs.SKIP_EXISTING }}' ]; then
    printf 'FAIL: the publish step does not receive SKIP_EXISTING, got %q\n' "$declared" >&2
    exit 1
  fi
}

# chart-releaser-action hands skip_existing to cr.sh, which only tests whether it
# is non-empty: the string 'false' would switch the skip ON. The expression has
# to yield the empty string when the input is off.
test_asks_chart_releaser_to_skip_existing_releases_only_when_asked() {
  local expression
  expression=$(yq '
    .jobs.release.steps[]
    | select(.id == "chart-releaser")
    | .with.skip_existing
  ' "$WORKFLOWS_DIR/$WORKFLOW")

  if [ "$expression" != "\${{ inputs.SKIP_EXISTING && 'true' || '' }}" ]; then
    printf 'FAIL: skip_existing must be empty, not the string false, when SKIP_EXISTING is off; got %q\n' \
      "$expression" >&2
    exit 1
  fi
}

test_ships_skip_existing_off_by_default() {
  local default
  default=$(yq '.on.workflow_call.inputs.SKIP_EXISTING.default' "$WORKFLOWS_DIR/$WORKFLOW")

  if [ "$default" != "false" ]; then
    printf 'FAIL: SKIP_EXISTING must default to false, got %q\n' "$default" >&2
    exit 1
  fi
}

run_tests
