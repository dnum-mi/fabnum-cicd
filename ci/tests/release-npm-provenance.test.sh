#!/usr/bin/env bash
# release-npm.yml - 'Validate provenance inputs': the two combinations
# PROVENANCE can never fulfil regardless of which package manager runs it -
# a restricted package (the registry's own rule) and bun's own publish
# command (no OIDC/provenance support of its own) - are refused up front
# rather than left to fail opaquely partway through a publish attempt.

# shellcheck source=ci/tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

VALIDATE=$(extract_run release-npm.yml publish "Validate provenance inputs")

provenance_env() {
  export ACCESS="public"
  export PACKAGE_MANAGER="npm"
  export NPM_TOKEN_PROVIDED="true"
}

test_accepts_npm_with_public_access() {
  provenance_env

  run_block "$VALIDATE"

  assert_status 0
}

test_accepts_yarn_with_public_access() {
  provenance_env
  export PACKAGE_MANAGER="yarn"

  run_block "$VALIDATE"

  assert_status 0
}

test_accepts_pnpm_with_public_access() {
  provenance_env
  export PACKAGE_MANAGER="pnpm"

  run_block "$VALIDATE"

  assert_status 0
}

test_rejects_restricted_access() {
  provenance_env
  export ACCESS="restricted"

  run_block "$VALIDATE"

  assert_status 1
  assert_output_contains "ACCESS: public"
}

# The one combination neither bun path can fulfil: bun publish itself has no
# provenance support, and a supplied token means this workflow uses that
# direct path rather than the npm-CLI trusted-publishing fallback.
test_rejects_bun_with_a_token() {
  provenance_env
  export PACKAGE_MANAGER="bun"

  run_block "$VALIDATE"

  assert_status 1
  assert_output_contains "bun publish"
}

# Without a token, bun projects already publish through the npm CLI's OIDC
# fallback (see 'Publish package (bun, trusted publishing)'), which does
# support --provenance.
test_accepts_bun_without_a_token() {
  provenance_env
  export PACKAGE_MANAGER="bun"
  export NPM_TOKEN_PROVIDED="false"

  run_block "$VALIDATE"

  assert_status 0
}

run_tests
