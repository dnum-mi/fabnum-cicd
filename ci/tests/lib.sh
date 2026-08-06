#!/usr/bin/env bash
# Test harness for the shell logic embedded in the reusable workflows.
#
# The blocks are executed straight out of the YAML rather than copied here, so a
# test can never drift from the workflow it covers. Reusable workflows check out
# the *caller's* repository, so this logic cannot live in a script file - running
# it from the YAML is the only way to test the real thing.

set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
WORKFLOWS_DIR="$REPO_ROOT/.github/workflows"

TESTS_RUN=0
TESTS_FAILED=0

# Prints the `run:` script of a step, identified by workflow file, job id and
# step name. Fails loudly when the step disappears or is renamed - a silently
# empty block would make every assertion below pass for the wrong reason.
extract_run() {
  local workflow="$1" job="$2" step="$3" block

  block=$(yq "
    .jobs.\"$job\".steps[]
    | select(.name == \"$step\")
    | .run
  " "$WORKFLOWS_DIR/$workflow")

  if [ -z "$block" ] || [ "$block" = "null" ]; then
    printf 'extract_run: no run block for step %q in job %q of %s\n' \
      "$step" "$job" "$workflow" >&2
    exit 1
  fi

  # A block interpolating ${{ }} cannot be executed as plain shell, and is the
  # pattern this repository avoids anyway (values are passed through `env:`).
  # shellcheck disable=SC2016 # the Actions marker is meant to stay literal
  if [[ "$block" == *'${{'* ]]; then
    # shellcheck disable=SC2016
    printf 'extract_run: step %q in %s interpolates ${{ }} into the shell; pass the value through `env:` instead\n' \
      "$step" "$workflow" >&2
    exit 1
  fi

  printf '%s\n' "$block"
}

# Fresh sandbox per test: stub executables on PATH, an empty call log, and a
# GITHUB_OUTPUT the steps can write to.
sandbox_setup() {
  SANDBOX=$(mktemp -d)
  export SANDBOX
  export CALL_LOG="$SANDBOX/calls.log"
  export GITHUB_OUTPUT="$SANDBOX/github_output"
  : >"$CALL_LOG"
  : >"$GITHUB_OUTPUT"

  mkdir -p "$SANDBOX/bin"
  install_gh_stub
  install_git_stub
  export PATH="$SANDBOX/bin:$PATH"
}

# Records every git invocation. `config --get` answers from STUB_GIT_CONFIG_<key>
# so a step can read back what it set, and `diff --no-index` reports files as
# differing unless STUB_GIT_FILES_MATCH is set.
install_git_stub() {
  cat >"$SANDBOX/bin/git" <<'STUB'
#!/usr/bin/env bash
args="$*"
printf 'git|%s\n' "$args" >>"$CALL_LOG"

if [ -n "${STUB_GIT_FAIL_ON:-}" ] && [[ "$args" == *"$STUB_GIT_FAIL_ON"* ]]; then
  printf '%s\n' "${STUB_GIT_FAIL_MESSAGE:-stub git: forced failure}" >&2
  exit 1
fi

case "$args" in
  "config --local --get "*)
    # Nothing pre-existing unless the test says otherwise.
    [ -n "${STUB_GIT_EXISTING_HEADER:-}" ] && printf '%s\n' "$STUB_GIT_EXISTING_HEADER"
    [ -n "${STUB_GIT_EXISTING_HEADER:-}" ] || exit 1
    ;;
  "diff --no-index --quiet"*)
    [ "${STUB_GIT_FILES_MATCH:-false}" = "true" ] || exit 1
    ;;
esac
exit 0
STUB
  chmod +x "$SANDBOX/bin/git"
}

# Records every invocation as `gh|<token>|<args>` so a test can assert both what
# was run and which credential ran it.
#
# Read commands evaluate their real `--jq` filter against a fixture with `jq`,
# so the filters in the workflows are themselves under test rather than being
# stubbed past. `gh` uses gojq, which agrees with jq on the expressions here.
install_gh_stub() {
  cat >"$SANDBOX/bin/gh" <<'STUB'
#!/usr/bin/env bash
args="$*"
printf 'gh|%s|%s\n' "${GH_TOKEN:-}" "$args" >>"$CALL_LOG"

if [ -n "${STUB_GH_FAIL_ON:-}" ] && [[ "$args" == *"$STUB_GH_FAIL_ON"* ]]; then
  printf '%s\n' "${STUB_GH_FAIL_MESSAGE:-stub gh: forced failure}" >&2
  exit 1
fi

# The value of the --jq flag, whatever position it appears in.
jq_filter=""
while [ "$#" -gt 0 ]; do
  if [ "$1" = "--jq" ]; then
    jq_filter="${2:-}"
    break
  fi
  shift
done

# gh prints nothing for a null result, where jq would print "null".
apply_filter() {
  if [ -z "$jq_filter" ]; then
    cat
    return
  fi
  jq -r "$jq_filter" | grep -v '^null$' || true
}

case "$args" in
  "pr list"*)
    printf '%s' "${STUB_GH_PR_LIST_JSON:-[]}" | apply_filter
    ;;
  "api repos/"*)
    printf '%s' "${STUB_GH_REPO_JSON:-{\"allow_auto_merge\":true\}}" | apply_filter
    ;;
  "pr merge"*|"workflow "*)
    ;;
  *)
    printf 'stub gh: unhandled invocation: %s\n' "$args" >&2
    exit 127
    ;;
esac
exit 0
STUB
  chmod +x "$SANDBOX/bin/gh"
}

sandbox_teardown() {
  [ -n "${SANDBOX:-}" ] && rm -rf "$SANDBOX"
}

# Runs an extracted block. Environment comes from the caller's exports, matching
# how Actions passes a step's `env:` block.
run_block() {
  RUN_OUTPUT=$(bash -c "$1" 2>&1)
  RUN_STATUS=$?
  export RUN_OUTPUT RUN_STATUS
}

assert_status() {
  local expected="$1" label="${2:-exit status}"
  if [ "$RUN_STATUS" -ne "$expected" ]; then
    printf 'FAIL: %s: expected %d, got %d\n---- output ----\n%s\n----------------\n' \
      "$label" "$expected" "$RUN_STATUS" "$RUN_OUTPUT" >&2
    exit 1
  fi
}

assert_output_contains() {
  if [[ "$RUN_OUTPUT" != *"$1"* ]]; then
    printf 'FAIL: expected output to contain %q\n---- output ----\n%s\n----------------\n' \
      "$1" "$RUN_OUTPUT" >&2
    exit 1
  fi
}

assert_output_lacks() {
  if [[ "$RUN_OUTPUT" == *"$1"* ]]; then
    printf 'FAIL: expected output NOT to contain %q\n---- output ----\n%s\n----------------\n' \
      "$1" "$RUN_OUTPUT" >&2
    exit 1
  fi
}

assert_called() {
  if ! grep -qF -- "$1" "$CALL_LOG"; then
    printf 'FAIL: expected a call matching %q\n---- calls ----\n%s\n---------------\n' \
      "$1" "$(cat "$CALL_LOG")" >&2
    exit 1
  fi
}

assert_not_called() {
  if grep -qF -- "$1" "$CALL_LOG"; then
    printf 'FAIL: expected no call matching %q\n---- calls ----\n%s\n---------------\n' \
      "$1" "$(cat "$CALL_LOG")" >&2
    exit 1
  fi
}

assert_call_count() {
  local pattern="$1" expected="$2" actual
  actual=$(grep -cF -- "$pattern" "$CALL_LOG")
  if [ "$actual" -ne "$expected" ]; then
    printf 'FAIL: expected %d calls matching %q, got %d\n---- calls ----\n%s\n---------------\n' \
      "$expected" "$pattern" "$actual" "$(cat "$CALL_LOG")" >&2
    exit 1
  fi
}

assert_file_contains() {
  if ! grep -qF -- "$2" "$1"; then
    printf 'FAIL: expected %s to contain %q\n---- contents ----\n%s\n------------------\n' \
      "$1" "$2" "$(cat "$1")" >&2
    exit 1
  fi
}

# Discovers `test_*` functions and runs each in its own subshell, so an aborted
# assertion or a leaked export cannot affect the next test.
run_tests() {
  local suite fn log
  suite=$(basename "$0")
  printf '\n%s\n' "$suite"

  for fn in $(declare -F | awk '{ print $3 }' | grep '^test_' | sort); do
    TESTS_RUN=$((TESTS_RUN + 1))
    log=$(mktemp)

    if ( sandbox_setup; trap sandbox_teardown EXIT; "$fn" ) >"$log" 2>&1; then
      printf '  ok   %s\n' "${fn#test_}"
    else
      TESTS_FAILED=$((TESTS_FAILED + 1))
      printf '  FAIL %s\n' "${fn#test_}"
      sed 's/^/       /' "$log"
    fi

    rm -f "$log"
  done

  if [ "$TESTS_FAILED" -gt 0 ]; then
    printf '\n%d of %d failed\n' "$TESTS_FAILED" "$TESTS_RUN"
    exit 1
  fi

  printf '  %d passed\n' "$TESTS_RUN"
}
