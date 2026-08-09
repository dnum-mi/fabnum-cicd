#!/usr/bin/env bash
# attest-helm.yml - 'Read charts to attest': what it accepts as a chart list,
# and the capability guard. The digest check is the important one - attesting a
# tag would bind the claim to whatever that tag resolves to later, which is the
# guarantee attestation exists to remove.

# shellcheck source=ci/tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

BLOCK=$(extract_run attest-helm.yml prepare "Read charts to attest")

# The exact shape release-helm.yml's 'published-charts' output produces.
PUBLISHED='[{"name":"my-chart","version":"1.2.3","repository":"ghcr.io/my-org/my-repo/my-chart","digest":"sha256:aaa"},{"name":"other","version":"2.0.0-rc.1","repository":"ghcr.io/my-org/my-repo/other","digest":"sha256:bbb"}]'

attest_env() {
  export SIGN="true"
  export PROVENANCE="false"
}

test_accepts_the_published_charts_output() {
  attest_env
  export CHARTS="$PUBLISHED"

  run_block "$BLOCK"

  assert_status 0
  assert_file_contains "$GITHUB_OUTPUT" "COUNT=2"
  assert_file_contains "$GITHUB_OUTPUT" "REGISTRY=ghcr.io"
}

test_accepts_provenance_without_signing() {
  attest_env
  export SIGN="false"
  export PROVENANCE="true"
  export CHARTS="$PUBLISHED"

  run_block "$BLOCK"

  # The two capabilities are independent, as they are in attest-docker.yml.
  assert_status 0
}

test_rejects_neither_capability_enabled() {
  attest_env
  export SIGN="false"
  export PROVENANCE="false"
  export CHARTS="$PUBLISHED"

  run_block "$BLOCK"

  # Would otherwise fan out a matrix of jobs that log in and do nothing, green
  # and indistinguishable from a run that attested everything.
  assert_status 1
  assert_output_contains "Nothing to attest"
}

test_treats_an_empty_list_as_a_no_op() {
  attest_env
  export CHARTS="[]"

  run_block "$BLOCK"

  # PUBLISH_OCI false, or no chart changed. The caller wires this workflow up
  # unconditionally, so an empty list must not be an error.
  assert_status 0
  assert_output_contains "No chart to attest"
  assert_file_contains "$GITHUB_OUTPUT" "COUNT=0"
}

test_rejects_an_entry_without_a_digest() {
  attest_env
  export CHARTS='[{"name":"c","version":"1.0.0","repository":"ghcr.io/my-org/my-repo/c"}]'

  run_block "$BLOCK"

  assert_status 1
  assert_output_contains "sha256:"
}

test_rejects_a_digest_that_is_not_a_sha256() {
  attest_env
  export CHARTS='[{"name":"c","version":"1.0.0","repository":"ghcr.io/my-org/my-repo/c","digest":"1.0.0"}]'

  run_block "$BLOCK"

  # A tag smuggled into the digest field is the failure worth catching.
  assert_status 1
  assert_output_contains "sha256:"
}

test_rejects_an_entry_without_a_repository() {
  attest_env
  export CHARTS='[{"name":"c","version":"1.0.0","digest":"sha256:aaa"}]'

  run_block "$BLOCK"

  assert_status 1
  assert_output_contains "repository"
}

test_rejects_charts_spread_across_registries() {
  attest_env
  export CHARTS='[{"repository":"ghcr.io/my-org/a","digest":"sha256:aaa"},{"repository":"registry.example.com/my-org/b","digest":"sha256:bbb"}]'

  run_block "$BLOCK"

  # A single login is performed per job, so the second chart would fail to
  # authenticate halfway through rather than up front.
  assert_status 1
  assert_output_contains "same registry"
}

test_rejects_input_that_is_not_a_json_array() {
  attest_env
  export CHARTS="not json at all"

  run_block "$BLOCK"

  assert_status 1
  assert_output_contains "must be a JSON array"
}

run_tests
