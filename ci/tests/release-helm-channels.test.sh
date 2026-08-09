#!/usr/bin/env bash
# release-helm.yml - 'Validate inputs': the two distribution channels and the
# registry credentials they need. The App-credential half of the same guard is
# covered centrally in credential-validation.test.sh.

# shellcheck source=ci/tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

BLOCK=$(extract_run release-helm.yml release "Validate inputs")

# Both channels off is the workflow's default, and is rejected on purpose -
# so this baseline sets neither, and each test opts in to what it exercises.
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

run_tests
