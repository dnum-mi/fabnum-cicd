#!/usr/bin/env bash
# scan-gitleaks.yml / scan-trivy.yml - 'Build the report link'
#
# Both scan workflows point their pull request comment at the same place,
# so the block is extracted from each and every case runs against all of them.
# A fix landing in one and not the others is the failure mode this guards.

# shellcheck source=ci/tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

GITLEAKS_BLOCK=$(extract_run scan-gitleaks.yml scan-notif 'Build the report link')
TRIVY_BLOCK=$(extract_run scan-trivy.yml scan-notif 'Build the report link')

link_env() {
  export GITHUB_SECURITY_TAB="true"
  export FORMAT="sarif"
  export REPOSITORY="owner/repo"
  export RUN_ID="123456"
  export REF="refs/heads/main"
}

# Runs both workflows' blocks and asserts the same link came out of each.
assert_link() {
  local expected="$1" block

  for block in "$GITLEAKS_BLOCK" "$TRIVY_BLOCK"; do
    : >"$GITHUB_OUTPUT"
    run_block "$block"
    assert_status 0
    assert_file_contains "$GITHUB_OUTPUT" "link=$expected"
  done
}

test_a_pull_request_ref_filters_on_the_pull_request() {
  link_env
  export REF="refs/pull/42/merge"

  # The SARIF of a pull_request run is uploaded under refs/pull/<N>/merge, and
  # `pr:` is the only filter that reaches it.
  assert_link "[the GitHub Security Tab](https://github.com/owner/repo/security/code-scanning?query=is%3Aopen+pr%3A42)"
}

test_a_pull_request_head_ref_filters_on_the_pull_request() {
  link_env
  export REF="refs/pull/42/head"

  assert_link "[the GitHub Security Tab](https://github.com/owner/repo/security/code-scanning?query=is%3Aopen+pr%3A42)"
}

test_a_branch_ref_filters_on_the_branch() {
  link_env
  export REF="refs/heads/main"

  # A caller scanning on `push` uploads against the branch. Filtering on
  # `pr:<N>` there - which the caller may still have passed by hand - points at
  # an empty tab, because no analysis was ever recorded against that pull
  # request.
  assert_link "[the GitHub Security Tab](https://github.com/owner/repo/security/code-scanning?query=is%3Aopen+branch%3Amain)"
}

test_a_branch_name_is_url_encoded() {
  link_env
  export REF="refs/heads/feat/some+branch&more"

  # `+` decodes to a space and `&` starts the next query parameter, so a raw
  # branch name here would search for something else entirely.
  assert_link "[the GitHub Security Tab](https://github.com/owner/repo/security/code-scanning?query=is%3Aopen+branch%3Afeat%2Fsome%2Bbranch%26more)"
}

test_a_tag_ref_falls_back_to_every_open_alert() {
  link_env
  export REF="refs/tags/v1.2.3"

  # Neither filter applies to a tag. Listing every open alert still leads
  # somewhere; a `branch:v1.2.3` guess would resolve to nothing.
  assert_link "[the GitHub Security Tab](https://github.com/owner/repo/security/code-scanning?query=is%3Aopen)"
}

test_without_the_security_tab_the_link_points_at_the_run() {
  link_env
  export GITHUB_SECURITY_TAB="false"

  assert_link "[the GitHub Workflow Summary](https://github.com/owner/repo/actions/runs/123456)"
}

test_a_non_sarif_format_points_at_the_run() {
  link_env
  export FORMAT="json"

  # Only SARIF is uploaded to code scanning, so there is no alert to link to
  # whatever the caller asked for.
  assert_link "[the GitHub Workflow Summary](https://github.com/owner/repo/actions/runs/123456)"
}

run_tests
