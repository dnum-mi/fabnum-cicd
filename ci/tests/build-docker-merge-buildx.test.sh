#!/usr/bin/env bash
# build-docker.yml - 'Check for buildx'
#
# The merge job only runs `imagetools`, which needs the buildx plugin and no
# builder, so the builder is not set up wherever the plugin is already there:
# that is about 8 of the job's 20 seconds. A RUNS_ON runner without the plugin
# is the case this must not break - setup-buildx-action is what downloads it
# there, so the step has to stay reachable.

# shellcheck source=ci/tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

BLOCK=$(extract_run build-docker.yml merge 'Check for buildx')

# The shared docker stub answers every command it does not know with success,
# which is a runner that has the plugin. This is a runner that does not.
without_the_plugin() {
  cat >"$SANDBOX/bin/docker" <<'STUB'
#!/usr/bin/env bash
printf 'docker|%s\n' "$*" >>"$CALL_LOG"
printf "docker: 'buildx' is not a docker command.\n" >&2
exit 1
STUB
  chmod +x "$SANDBOX/bin/docker"
}

test_a_runner_with_the_plugin_skips_the_builder_setup() {
  run_block "$BLOCK"

  assert_status 0
  assert_file_contains "$GITHUB_OUTPUT" "present=true"
  assert_called "docker|buildx version"
}

test_a_runner_without_the_plugin_still_gets_it_installed() {
  without_the_plugin

  run_block "$BLOCK"

  # The probe failing is the answer, not an error: the step must not fail the
  # job, and must leave the output unset so the setup step runs.
  assert_status 0
  if grep -q "present=true" "$GITHUB_OUTPUT"; then
    printf 'FAIL: reported the plugin present when docker has no buildx\n' >&2
    exit 1
  fi
}

# The condition is what turns the probe into a saving. Without it the setup
# runs everywhere again and nothing else would notice.
test_the_builder_setup_runs_only_when_the_plugin_is_missing() {
  local condition
  condition=$(yq '.jobs.merge.steps[] | select(.name == "Set up Docker Buildx") | .["if"]' \
    "$WORKFLOWS_DIR/build-docker.yml")

  # shellcheck disable=SC2016 # the Actions marker is meant to stay literal
  if [ "$condition" != '${{ steps.buildx.outputs.present != '"'true'"' }}' ]; then
    printf 'FAIL: the builder setup is not conditional on the probe: %q\n' "$condition" >&2
    exit 1
  fi
}

run_tests
