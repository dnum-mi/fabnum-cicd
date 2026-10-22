#!/usr/bin/env bash
# build-docker.yml - 'merge' job: the Buildx setup
#
# `imagetools` needs the buildx plugin but never a builder, so the setup action
# is skipped where the plugin is already there and kept where it is not.

# shellcheck source=ci/tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

BLOCK=$(extract_run build-docker.yml merge "Check for Docker Buildx")

output_value() {
  grep '^present=' "$GITHUB_OUTPUT" | tail -1 | cut -d= -f2
}

test_reports_the_plugin_when_it_is_installed() {
  run_block "$BLOCK"

  assert_status 0
  [ "$(output_value)" = "true" ] || { echo "FAIL: expected present=true" >&2; exit 1; }
}

test_reports_a_missing_plugin_without_failing_the_job() {
  export STUB_DOCKER_NO_BUILDX=1

  run_block "$BLOCK"

  # The check only decides whether to install: it must not fail the job itself.
  assert_status 0
  [ "$(output_value)" = "false" ] || { echo "FAIL: expected present=false" >&2; exit 1; }
}

test_setup_runs_only_when_the_plugin_is_missing() {
  local condition
  condition=$(yq '.jobs.merge.steps[] | select(.name == "Set up Docker Buildx") | .if' \
    "$WORKFLOWS_DIR/build-docker.yml")

  [[ "$condition" == *"steps.buildx.outputs.present != 'true'"* ]] || {
    echo "FAIL: the Buildx setup is not conditioned on the plugin check: $condition" >&2
    exit 1
  }
}

run_tests
