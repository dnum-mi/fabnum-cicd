#!/usr/bin/env bash
# The steps that run a command the caller supplied: PRE_COMMAND, BUILD_COMMAND,
# PUBLISH_COMMAND, INSTALL_COMMAND, LINT_COMMAND, TYPE_CHECK_COMMAND and
# TEST_COMMAND.
#
# These are shell by contract, so they have to be executed - but through `eval`
# from `env:` rather than as `run: ${{ inputs.X }}`, which pastes the caller's
# text into the script before the shell sees it. What the steps must keep doing
# is the part a refactor of that kind could quietly lose: run the command as
# written, and fail when it fails. A TEST_COMMAND that stopped propagating its
# status would turn every red test suite green.
#
# The table is the inventory. A new step of this shape that is not listed here
# is not covered, which is why the first test fails when one appears.

set -uo pipefail
# shellcheck source=ci/tests/lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

# workflow|job|step|input
STEPS=(
  "lint-python.yml|lint|Install dependencies|INSTALL_COMMAND"
  "lint-python.yml|lint|Lint|LINT_COMMAND"
  "lint-python.yml|lint|Type check|TYPE_CHECK_COMMAND"
  "release-npm.yml|publish|Run pre-command|PRE_COMMAND"
  "release-npm.yml|publish|Build package|BUILD_COMMAND"
  "release-npm.yml|publish|Publish package (custom command)|PUBLISH_COMMAND"
  "test-python.yml|test|Install dependencies|INSTALL_COMMAND"
  "test-python.yml|test|Test|TEST_COMMAND"
)

run_step() {
  local workflow="$1" job="$2" step="$3" input="$4" command="$5"
  export "$input=$command"
  run_block "$(extract_run "$workflow" "$job" "$step")"
}

# Every step in the workflows whose script is `eval "$..._COMMAND"` must be in
# the table above, or its behaviour is pinned by nothing.
test_every_command_step_is_covered() {
  local file found missing=""
  for file in "$WORKFLOWS_DIR"/*.yml; do
    # shellcheck disable=SC2016 # `$j` and `\$` are yq syntax, not shell
    while IFS= read -r found; do
      [ -n "$found" ] || continue
      if ! printf '%s\n' "${STEPS[@]}" | grep -qxF "$(basename "$file")|$found"; then
        missing="${missing}  $(basename "$file")|$found"$'\n'
      fi
    # The script may be written `run: eval "$X"` or as a `run: |` block, which
    # ends in a newline; both are the same step.
    done < <(yq -r '.jobs | to_entries[] | .key as $j | .value.steps[]?
      | ((.run // "") | sub("\n+$"; "")) as $script
      | select($script | test("^eval \"\\$[A-Z_]+_COMMAND\"$"))
      | $j + "|" + .name + "|" + ($script | sub("eval \"\\$"; "") | sub("\""; ""))' "$file")
  done
  if [ -n "$missing" ]; then
    printf 'FAIL: command steps missing from STEPS:\n%s' "$missing" >&2
    exit 1
  fi
}

# The tests below hand each step its variable themselves, so they cannot see a
# step whose `env:` forgot to pass the input in: `eval ""` exits 0, and a red
# suite or a publish that never ran would read as green.
test_every_step_passes_its_own_input_in() {
  local entry workflow job step input mapped
  for entry in "${STEPS[@]}"; do
    IFS='|' read -r workflow job step input <<<"$entry"
    mapped=$(yq -r ".jobs.\"$job\".steps[] | select(.name == \"$step\") | .env.\"$input\"" "$WORKFLOWS_DIR/$workflow")
    # shellcheck disable=SC2016 # the Actions marker is meant to stay literal
    if [ "$mapped" != "\${{ inputs.$input }}" ]; then
      printf 'FAIL: %s: step "%s" sets %s to %q, expected ${{ inputs.%s }}\n' \
        "$workflow" "$step" "$input" "$mapped" "$input" >&2
      exit 1
    fi
  done
}

test_the_command_runs_as_written() {
  local entry workflow job step input
  for entry in "${STEPS[@]}"; do
    IFS='|' read -r workflow job step input <<<"$entry"
    # shellcheck disable=SC2016 # evaluated by the step under test, not here
    run_step "$workflow" "$job" "$step" "$input" 'echo "ran-$((40 + 2))"'
    assert_status 0 "$workflow: $step"
    assert_output_contains "ran-42"
  done
}

test_a_failing_command_fails_the_step() {
  local entry workflow job step input
  for entry in "${STEPS[@]}"; do
    IFS='|' read -r workflow job step input <<<"$entry"
    run_step "$workflow" "$job" "$step" "$input" 'exit 7'
    assert_status 7 "$workflow: $step"
  done
}

# `set -e` has to stay in force inside the evaluated text: a failure in the
# middle of a multi-line command must not be masked by a later line succeeding.
test_a_failure_before_the_last_line_is_not_masked() {
  local entry workflow job step input
  for entry in "${STEPS[@]}"; do
    IFS='|' read -r workflow job step input <<<"$entry"
    run_step "$workflow" "$job" "$step" "$input" $'false\necho reached-the-end'
    assert_status 1 "$workflow: $step"
    assert_output_lacks "reached-the-end"
  done
}

# The command is data until the shell evaluates it: a value that closes a quote
# or chains a command is run as the caller wrote it, and nothing around it.
test_the_command_text_arrives_intact() {
  local entry workflow job step input
  for entry in "${STEPS[@]}"; do
    IFS='|' read -r workflow job step input <<<"$entry"
    run_step "$workflow" "$job" "$step" "$input" "printf '%s|' \"a b\" 'c\$d' ; echo end"
    assert_status 0 "$workflow: $step"
    # shellcheck disable=SC2016 # the literal `$` is the point
    assert_output_contains 'a b|c$d|end'
  done
}

run_tests
