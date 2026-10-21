#!/usr/bin/env bash
# The command line scan-zizmor.yml builds from its inputs.
#
# Two of the inputs are safety switches rather than preferences, so a step that
# silently stopped honouring them would still run green:
#
#   - ONLINE_AUDITS=false has to keep the job token away from zizmor. Given a
#     token, zizmor runs the audits that call the GitHub API; the flag alone
#     would not stop a token already in the environment from being used.
#   - FAIL_ON_FINDINGS=false has to reach zizmor as `--no-exit-codes`, because
#     the exit status *is* the verdict - the step has no other way to fail.
#
# The stub stands in for the binary: what is under test is the arguments the
# workflow assembles, not zizmor's audits.

set -uo pipefail
# shellcheck source=ci/tests/lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

WORKFLOW="scan-zizmor.yml"

# Logs its arguments - joined, then one per line - and whether GH_TOKEN reached
# it, then exits with STUB_ZIZMOR_STATUS: the code the real one derives from its
# worst finding.
install_zizmor_stub() {
  cat >"$SANDBOX/bin/zizmor" <<'STUB'
#!/usr/bin/env bash
printf 'zizmor|%s\n' "$*" >>"$CALL_LOG"
for arg in "$@"; do printf 'arg|%s\n' "$arg" >>"$CALL_LOG"; done
printf 'token|%s\n' "${GH_TOKEN-unset}" >>"$CALL_LOG"
exit "${STUB_ZIZMOR_STATUS:-0}"
STUB
  chmod +x "$SANDBOX/bin/zizmor"
}

# The workflow's own defaults, so a test only names what it changes.
default_inputs() {
  export CONFIG_FILE="" SCAN_PATH="." PERSONA="regular" MIN_SEVERITY="" \
    MIN_CONFIDENCE="" ONLINE_AUDITS="true" FAIL_ON_FINDINGS="true" \
    JOB_TOKEN="job-token-value"
}

run_zizmor() { run_block "$(extract_run "$WORKFLOW" zizmor 'Run zizmor')"; }

test_defaults_audit_the_repository_as_annotations() {
  install_zizmor_stub
  default_inputs
  run_zizmor
  assert_status 0
  assert_called "zizmor|--format=github --persona regular ."
  assert_not_called "--config"
  assert_not_called "--min-severity"
  assert_not_called "--min-confidence"
}

test_optional_inputs_are_forwarded_when_set() {
  install_zizmor_stub
  default_inputs
  export CONFIG_FILE=".github/custom-zizmor.yml" PERSONA="pedantic" \
    MIN_SEVERITY="medium" MIN_CONFIDENCE="high" SCAN_PATH=".github/workflows"
  run_zizmor
  assert_status 0
  assert_called "--config .github/custom-zizmor.yml"
  assert_called "--persona pedantic"
  assert_called "--min-severity medium"
  assert_called "--min-confidence high"
  assert_called ".github/workflows"
}

test_online_audits_get_the_job_token_and_no_flag() {
  install_zizmor_stub
  default_inputs
  run_zizmor
  assert_status 0
  assert_called "token|job-token-value"
  assert_not_called "--no-online-audits"
}

# The token is in the step's environment either way - it is the workflow that
# has to keep it from zizmor, not the caller's good intentions.
test_turning_online_audits_off_withholds_the_token() {
  install_zizmor_stub
  default_inputs
  export ONLINE_AUDITS="false"
  run_zizmor
  assert_status 0
  assert_called "--no-online-audits"
  assert_called "token|unset"
  assert_not_called "job-token-value"
}

test_findings_fail_the_step_by_default() {
  install_zizmor_stub
  default_inputs
  export STUB_ZIZMOR_STATUS=13
  run_zizmor
  assert_status 13
  assert_not_called "--no-exit-codes"
}

test_findings_can_be_reported_without_failing() {
  install_zizmor_stub
  default_inputs
  export FAIL_ON_FINDINGS="false"
  run_zizmor
  assert_status 0
  assert_called "--no-exit-codes"
}

# A path with a space is one path. Splitting it would audit two directories
# that do not exist and report a clean run over neither.
test_scan_path_stays_a_single_argument() {
  install_zizmor_stub
  default_inputs
  export SCAN_PATH="my workflows"
  run_zizmor
  assert_status 0
  assert_called "arg|my workflows"
  # --format=github, --persona, regular and the path: four, not five.
  assert_call_count "arg|" 4
}

run_tests
