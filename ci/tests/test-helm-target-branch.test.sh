#!/usr/bin/env bash
# test-helm.yml - 'Run chart-testing (install)'
#
# ct installs the charts that differ between HEAD and its target branch, so
# the target decides whether this gate tests anything at all. It named the
# pull request's own branch for as long as the workflow existed: every run
# diffed a branch against itself, installed nothing, and passed.

# shellcheck source=ci/tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

STEP='Run chart-testing (install)'
BLOCK=$(extract_run test-helm.yml test-charts "$STEP")

# Records every ct invocation, one argument per line, so a test can see where
# one argument ends and the next begins.
install_ct_stub() {
  cat >"$SANDBOX/bin/ct" <<'STUB'
#!/usr/bin/env bash
printf 'ct|%s\n' "$@" >>"$CALL_LOG"
exit 0
STUB
  chmod +x "$SANDBOX/bin/ct"
}

# Defined once, on the job, because the check for charts to install and the
# install itself have to diff against the same branch.
test_the_target_is_the_branch_the_pull_request_merges_into() {
  local expr
  expr=$(yq '.jobs."test-charts".env.TARGET_BRANCH' "$WORKFLOWS_DIR/test-helm.yml")
  if [[ "$expr" != *'github.base_ref'* ]] || [[ "$expr" == *'head_ref'* ]]; then
    printf 'FAIL: TARGET_BRANCH is %s; it must be the base branch, never the head\n' "$expr" >&2
    exit 1
  fi
}

test_no_step_names_a_target_of_its_own() {
  local overrides
  overrides=$(yq '.jobs."test-charts".steps[] | select(.env.TARGET_BRANCH != null) | .name' \
    "$WORKFLOWS_DIR/test-helm.yml")
  if [ -n "$overrides" ]; then
    printf 'FAIL: a step overrides the job-level TARGET_BRANCH: %s\n' "$overrides" >&2
    exit 1
  fi
}

test_the_target_reaches_ct_as_one_argument() {
  install_ct_stub
  export CT_CONF_PATH=".github/ct.yaml"
  # shellcheck disable=SC2016 # the substitution is meant to stay literal
  export TARGET_BRANCH='release/$(touch pwned) 1.x'

  run_block "$BLOCK"

  assert_status 0
  assert_called 'ct|--target-branch'
  # shellcheck disable=SC2016 # the substitution is meant to stay literal
  assert_called 'ct|release/$(touch pwned) 1.x'
  if [ -e pwned ] || [ -e "$SANDBOX/pwned" ]; then
    printf 'FAIL: the branch name was executed\n' >&2
    exit 1
  fi
}

run_tests
