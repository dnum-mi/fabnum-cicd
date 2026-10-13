#!/usr/bin/env bash
# Every workflow that runs a script must name the shell it wrote that script in.
#
# GitHub reads the shell off the runner when a step does not name one: bash on
# Linux and macOS, PowerShell on Windows. Every `run:` block in this repository
# is bash — `[ -n "$X" ]`, arrays, `+=`, `>> "$GITHUB_OUTPUT"` — so a caller
# that points RUNS_ON at a Windows runner gets a parse error where a run should
# be, not a different-but-working shell.
#
# That is not hypothetical. test-go.yml takes a RUNNERS matrix precisely so a
# suite can be tried on a second operating system; the first caller to name
# windows-latest had its step handed to pwsh, which stopped at the first
# `if [ -n "$TEST_PRECOMMAND" ]` with "Missing '(' after 'if'". The job failed
# in 37 seconds having tested nothing, and nothing in the workflow said why.
#
# 31 of these workflows take a RUNS_ON input, so this was one caller's choice
# away in almost all of them; test-go.yml was simply the first anyone pointed
# somewhere else.
#
# `bash` is the portable value rather than a Linux one: GitHub resolves it to
# Git Bash on Windows and to /usr/bin/bash elsewhere. It is not offered as an
# input for the same reason it is not a preference — the scripts *are* bash, so
# the other values are not alternatives, they are failures, and they fail on
# exactly the runner nobody tests on.
#
# Declared once per file rather than per step: a step added later would
# otherwise reintroduce this silently, which is how it would come back.

set -uo pipefail
# shellcheck source=ci/tests/lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

test_every_workflow_that_runs_a_script_declares_bash() {
  local file name steps shell missing=""
  for file in "$WORKFLOWS_DIR"/*.yml; do
    name=$(basename "$file")
    # Steps only ever live under jobs.<id>.steps, so this counts run: blocks
    # without matching the `defaults.run` key that is the fix itself.
    steps=$(yq '[.jobs[] | .steps[]? | select(has("run"))] | length' "$file")
    if [ "$steps" -eq 0 ]; then
      continue
    fi
    shell=$(yq '.defaults.run.shell // ""' "$file")
    if [ "$shell" != "bash" ]; then
      missing="${missing}  ${name} (${steps} run steps, defaults.run.shell=${shell:-unset})"$'\n'
    fi
  done
  if [ -n "$missing" ]; then
    printf 'FAIL: these workflows run a script without naming the shell:\n%s' "$missing" >&2
    exit 1
  fi
}

run_tests
