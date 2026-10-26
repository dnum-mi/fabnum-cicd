#!/usr/bin/env bash
# lint-helm.yml and update-helm-chart.yml - 'Check for Go'
#
# helm-docs is compiled with `go install`. The Go a hosted runner already ships
# does that as well as the `stable` that setup-go fetches, and fetching it is 7
# to 10 seconds. Go 1.21 and later download whatever toolchain a module asks
# for, so any of them is enough; anything older, or no Go at all as on a
# RUNS_ON runner, must still get `stable` installed.

# shellcheck source=ci/tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# <workflow> <job> pairs: the same two steps live in both.
WORKFLOWS=("lint-helm.yml lint-docs" "update-helm-chart.yml update")

# A runner whose `go` reports STUB_GO_VERSION from `go env GOVERSION`, or has no
# go at all when it is unset.
go_env() {
  if [ -z "${STUB_GO_VERSION:-}" ]; then
    cat >"$SANDBOX/bin/go" <<'STUB'
#!/usr/bin/env bash
printf 'go: command not found\n' >&2
exit 127
STUB
  else
    cat >"$SANDBOX/bin/go" <<'STUB'
#!/usr/bin/env bash
printf 'go|%s\n' "$*" >>"$CALL_LOG"
[ "$*" = "env GOVERSION" ] && printf '%s\n' "$STUB_GO_VERSION"
exit 0
STUB
  fi
  chmod +x "$SANDBOX/bin/go"
}

# Runs the step of every workflow and calls $1 after each, with the output file
# emptied between them.
for_each_workflow() {
  local callback="$1" entry workflow job block
  for entry in "${WORKFLOWS[@]}"; do
    read -r workflow job <<<"$entry"
    block=$(extract_run "$workflow" "$job" 'Check for Go')
    : >"$GITHUB_OUTPUT"
    run_block "$block"
    "$callback" "$workflow"
  done
}

expect_present() {
  assert_status 0 "$1: the probe must never fail the job"
  assert_file_contains "$GITHUB_OUTPUT" "present=true"
}

expect_absent() {
  assert_status 0 "$1: the probe must never fail the job"
  if grep -q "present=true" "$GITHUB_OUTPUT"; then
    printf 'FAIL: %s reported Go present for %q\n' "$1" "${STUB_GO_VERSION:-<no go>}" >&2
    exit 1
  fi
}

test_the_go_a_hosted_runner_ships_is_used() {
  export STUB_GO_VERSION="go1.24.13"
  go_env
  for_each_workflow expect_present
}

test_the_newest_go_is_used_too() {
  export STUB_GO_VERSION="go1.26.9"
  go_env
  for_each_workflow expect_present
}

# 1.21 is the first release that fetches the toolchain a module asks for.
test_go_1_21_is_the_oldest_that_counts() {
  export STUB_GO_VERSION="go1.21.0"
  go_env
  for_each_workflow expect_present
}

test_a_release_candidate_counts_like_its_release() {
  export STUB_GO_VERSION="go1.27rc1"
  go_env
  for_each_workflow expect_present
}

test_a_go_without_toolchain_switching_gets_stable_installed() {
  export STUB_GO_VERSION="go1.20.14"
  go_env
  for_each_workflow expect_absent
}

test_a_runner_without_go_gets_stable_installed() {
  unset STUB_GO_VERSION
  go_env
  for_each_workflow expect_absent
}

# A development build, or anything the pattern does not recognise, is not a
# reason to skip the install.
test_an_unrecognised_version_gets_stable_installed() {
  export STUB_GO_VERSION="devel go1.27-abcdef0 Tue Jan 1 00:00:00 2030 +0000"
  go_env
  for_each_workflow expect_absent
}

# The condition is what turns the probe into a saving, and what keeps the
# fallback for a runner that needs it.
test_setup_go_runs_only_when_the_probe_found_none() {
  local entry workflow job condition names name position probe setup
  for entry in "${WORKFLOWS[@]}"; do
    read -r workflow job <<<"$entry"

    condition=$(yq ".jobs.\"$job\".steps[] | select(.name == \"Set up Go\") | .[\"if\"]" \
      "$WORKFLOWS_DIR/$workflow")
    # shellcheck disable=SC2016 # the Actions marker is meant to stay literal
    if [ "$condition" != '${{ steps.go.outputs.present != '"'true'"' }}' ]; then
      printf 'FAIL: %s: Set up Go is not conditional on the probe: %q\n' "$workflow" "$condition" >&2
      exit 1
    fi

    # The probe has to come first, or the condition reads an output not yet set.
    mapfile -t names < <(yq ".jobs.\"$job\".steps[].name" "$WORKFLOWS_DIR/$workflow")
    probe=-1 setup=-1 position=0
    for name in "${names[@]}"; do
      [ "$name" = "Check for Go" ] && probe=$position
      [ "$name" = "Set up Go" ] && setup=$position
      position=$((position + 1))
    done
    if [ "$probe" -lt 0 ] || [ "$setup" -lt 0 ] || [ "$probe" -ge "$setup" ]; then
      printf 'FAIL: %s: Check for Go (step %s) does not come before Set up Go (step %s)\n' \
        "$workflow" "$probe" "$setup" >&2
      exit 1
    fi
  done
}

run_tests
