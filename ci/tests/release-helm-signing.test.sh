#!/usr/bin/env bash
# release-helm.yml - 'Validate inputs': the SIGN_CHART preconditions. Signing
# that silently produces nothing is the failure mode these guard against, since
# an unsigned chart published as if it were signed is worse than a failed run.

# shellcheck source=ci/tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

BLOCK=$(extract_run release-helm.yml release "Validate inputs")

# A configuration that signs successfully; each test breaks one part of it.
signing_env() {
  export HAS_PARTIAL_APP_AUTH="false"
  export HAS_REGISTRY_AUTH="false"
  export REGISTRY="ghcr.io"
  export PUBLISH_OCI="false"
  export CREATE_GITHUB_RELEASE="true"
  export SIGN_CHART="true"
  export SIGNING_KEY_ID="Jane Doe <jane@example.com>"
  export HAS_GPG_KEY="true"
}

test_accepts_a_complete_signing_configuration() {
  signing_env

  run_block "$BLOCK"

  assert_status 0
}

test_rejects_signing_without_the_github_release_channel() {
  signing_env
  export CREATE_GITHUB_RELEASE="false"
  export PUBLISH_OCI="true"

  run_block "$BLOCK"

  # `helm push` does not carry the .prov to an OCI registry, so signing on the
  # OCI channel alone generates provenance that nothing publishes.
  assert_status 1
  assert_output_contains "SIGN_CHART requires CREATE_GITHUB_RELEASE"
}

test_rejects_signing_without_a_key() {
  signing_env
  export HAS_GPG_KEY="false"

  run_block "$BLOCK"

  # chart-releaser does not fail on a missing key - it packages unsigned.
  assert_status 1
  assert_output_contains "GPG_PRIVATE_KEY"
}

test_rejects_signing_without_a_key_id() {
  signing_env
  export SIGNING_KEY_ID=""

  run_block "$BLOCK"

  assert_status 1
  assert_output_contains "SIGNING_KEY_ID"
}

test_ignores_signing_configuration_when_signing_is_off() {
  signing_env
  export SIGN_CHART="false"
  export SIGNING_KEY_ID=""
  export HAS_GPG_KEY="false"

  run_block "$BLOCK"

  # Nothing about signing should be required when it is not requested.
  assert_status 0
}

run_tests
