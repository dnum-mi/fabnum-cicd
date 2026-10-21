#!/usr/bin/env bash
# release-helm.yml - 'Validate inputs': the two distribution channels and the
# registry credentials they need. The App-credential half of the same guard is
# covered centrally in credential-validation.test.sh.

# shellcheck source=ci/tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

BLOCK=$(extract_run release-helm.yml release "Validate inputs")

# Both channels off is rejected on purpose, so this baseline sets neither and
# each test opts in to what it exercises. Note this is NOT the workflow's
# default any more - CREATE_GITHUB_RELEASE ships true, asserted below.
channel_env() {
  export HAS_PARTIAL_APP_AUTH="false"
  export HAS_REGISTRY_AUTH="false"
  export PUBLISH_OCI="false"
  export CREATE_GITHUB_RELEASE="false"
  export REGISTRY="ghcr.io"
  # Signing off by default; release-helm-signing.test.sh opts in.
  export SIGN_CHART="false"
  export SIGNING_KEY_ID=""
  export HAS_GPG_KEY="false"
}

test_rejects_both_channels_disabled() {
  channel_env

  run_block "$BLOCK"

  # The whole point of the guard: packaging charts and publishing them nowhere
  # must not be a green run.
  assert_status 1
  assert_output_contains "Nothing to publish"
}

test_accepts_the_oci_channel_alone() {
  channel_env
  export PUBLISH_OCI="true"

  run_block "$BLOCK"

  assert_status 0
}

test_accepts_the_github_release_channel_alone() {
  channel_env
  export CREATE_GITHUB_RELEASE="true"

  run_block "$BLOCK"

  assert_status 0
}

test_accepts_both_channels_together() {
  channel_env
  export PUBLISH_OCI="true"
  export CREATE_GITHUB_RELEASE="true"

  run_block "$BLOCK"

  assert_status 0
}

test_ghcr_needs_no_explicit_registry_credentials() {
  channel_env
  export PUBLISH_OCI="true"

  run_block "$BLOCK"

  # ghcr.io falls back to the built-in GITHUB_TOKEN, so the absence of
  # REGISTRY_USERNAME/REGISTRY_PASSWORD is the normal case, not an error.
  assert_status 0
}

test_rejects_a_custom_registry_without_credentials() {
  channel_env
  export PUBLISH_OCI="true"
  export REGISTRY="registry.example.com"

  run_block "$BLOCK"

  # Without this the login step reaches `helm registry login` with an empty
  # password and fails on an opaque authentication error instead.
  assert_status 1
  assert_output_contains "REGISTRY_USERNAME and REGISTRY_PASSWORD are required"
  assert_output_contains "registry.example.com"
}

test_accepts_a_custom_registry_with_credentials() {
  channel_env
  export PUBLISH_OCI="true"
  export REGISTRY="registry.example.com"
  export HAS_REGISTRY_AUTH="true"

  run_block "$BLOCK"

  assert_status 0
}

test_ignores_registry_credentials_when_the_oci_channel_is_off() {
  channel_env
  export CREATE_GITHUB_RELEASE="true"
  export REGISTRY="registry.example.com"

  run_block "$BLOCK"

  # No login happens on the GitHub Release channel, so a custom registry with
  # no credentials is irrelevant rather than fatal.
  assert_status 0
}

# The declared defaults are load-bearing: a caller that names neither channel
# relies on them to publish anything at all, and flipping CREATE_GITHUB_RELEASE
# back to false would make every such caller fail the guard above instead.
test_ships_the_classic_channel_on_and_oci_off_by_default() {
  local defaults
  defaults=$(yq '
    .on.workflow_call.inputs
    | [.CREATE_GITHUB_RELEASE.default, .PUBLISH_OCI.default]
    | join(",")
  ' "$WORKFLOWS_DIR/release-helm.yml")

  if [ "$defaults" != "true,false" ]; then
    printf 'expected CREATE_GITHUB_RELEASE=true and PUBLISH_OCI=false, got %q\n' "$defaults"
    return 1
  fi
}

# chart-releaser-action passes its `skip_*` inputs on to cr.sh, which tests only
# whether they are non-empty: the string 'false' skips exactly as 'true' does. A
# bare `${{ inputs.SKIP_EXISTING }}` would therefore turn the default into "never
# upload a chart whose release already exists", with every run green. The
# expression has to yield the empty string when the input is off.
test_hands_chart_releaser_an_empty_skip_existing_not_the_string_false() {
  local expression
  expression=$(yq '
    .jobs.release.steps[]
    | select(.id == "chart-releaser")
    | .with.skip_existing
  ' "$WORKFLOWS_DIR/release-helm.yml")

  if [ "$expression" != "\${{ inputs.SKIP_EXISTING && 'true' || '' }}" ]; then
    printf 'FAIL: skip_existing must be empty, not the string false, when SKIP_EXISTING is off; got %q\n' \
      "$expression" >&2
    return 1
  fi
}

# `skip_upload` only ever skipped the index update: cr.sh runs `cr upload`, which
# creates the release, whatever it says. The OCI-only channel is now served by not
# running chart-releaser (ci/tests/release-helm-oci-only.test.sh), so the input has
# nothing left to do and must not come back looking like a way to avoid a release.
test_chart_releaser_is_not_asked_to_skip_upload() {
  local expression
  expression=$(yq '
    .jobs.release.steps[]
    | select(.id == "chart-releaser")
    | .with.skip_upload
  ' "$WORKFLOWS_DIR/release-helm.yml")

  if [ "$expression" != "null" ]; then
    printf 'FAIL: skip_upload does not stop cr upload creating a release; got %q\n' "$expression" >&2
    return 1
  fi
}

run_tests
