#!/usr/bin/env bash
# test-helm.yml - 'Find the charts to install'
#
# Creating the kind cluster is most of the job, and a run that changes no chart
# gives `ct install` nothing to install. The cluster is therefore created only
# when ct would install something. The failure to guard against is the quiet
# one: a configuration with `charts:` or `all: true` makes `ct install` process
# charts that did not change, `ct list-changed` does not say so, and skipping
# on its word would pass a run that tested nothing.

# shellcheck source=ci/tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

STEP='Find the charts to install'
BLOCK=$(extract_run test-helm.yml test-charts "$STEP")

# Stands in for ct the way ct 3.15.0 behaves: `list-changed` writes the charts
# that changed to stdout, and `--print-config` writes the effective
# configuration to stderr. The configuration block is ct's own output with the
# lines this step reads, and the ones it must not mistake for them, left to vary.
install_ct_stub() {
  cat >"$SANDBOX/bin/ct" <<'STUB'
#!/usr/bin/env bash
printf 'ct|%s\n' "$*" >>"$CALL_LOG"

if [ -n "${STUB_CT_FAIL:-}" ]; then
  printf '%s\n' "$STUB_CT_FAIL" >&2
  exit 1
fi

if [[ "$*" == *"--print-config"* ]]; then
  cat >&2 <<CONFIG
Using config file: ci/ct.yaml
------------------------------------------------------------------------------------------------------------------------
 Configuration
------------------------------------------------------------------------------------------------------------------------
Remote: origin
TargetBranch: main
Since: HEAD
BuildID:
LintConf:
ChartYamlSchema:
ValidateMaintainers: false
ValidateChartSchema: false
ValidateYaml: false
SkipHelmDependencies: false
AdditionalCommands: []
CheckVersionIncrement: false
ProcessAllCharts: ${STUB_CT_PROCESS_ALL:-false}
Charts: ${STUB_CT_CHARTS:-[]}
ChartRepos: ${STUB_CT_REPOS:-[]}
ChartDirs: [charts]
ExcludedCharts: ${STUB_CT_EXCLUDED:-[]}
HelmExtraArgs:
Debug: false
CONFIG
fi

[ -n "${STUB_CT_CHANGED:-}" ] && printf '%s\n' "$STUB_CT_CHANGED"
exit 0
STUB
  chmod +x "$SANDBOX/bin/ct"
}

gate_env() {
  install_ct_stub
  export CT_CONF_PATH="ci/ct.yaml"
  export TARGET_BRANCH="main"
}

expect_install() {
  assert_status 0
  assert_file_contains "$GITHUB_OUTPUT" "install=$1"
  if [ "$1" = "true" ] && grep -q "install=false" "$GITHUB_OUTPUT"; then
    printf 'FAIL: reported both outcomes\n' >&2
    exit 1
  fi
}

test_a_run_that_changes_no_chart_installs_nothing() {
  gate_env

  run_block "$BLOCK"

  expect_install false
  assert_output_contains "No chart changed against main"
  assert_output_contains "no kind cluster is created"
}

test_a_changed_chart_is_installed() {
  gate_env
  export STUB_CT_CHANGED="charts/a"

  run_block "$BLOCK"

  expect_install true
  assert_output_contains "charts/a"
}

# `list-changed` reports only what changed, so with `all: true` it says nothing
# for a run that `ct install` would still spend on every chart.
test_a_configuration_that_processes_every_chart_installs_them() {
  gate_env
  export STUB_CT_PROCESS_ALL="true"

  run_block "$BLOCK"

  expect_install true
}

test_a_configuration_that_names_charts_installs_them() {
  gate_env
  export STUB_CT_CHARTS="[charts/a charts/b]"

  run_block "$BLOCK"

  expect_install true
}

# The configuration lists several other charts-shaped fields, and a non-empty
# one is not a reason to start a cluster.
test_other_chart_lists_in_the_configuration_do_not_count() {
  gate_env
  export STUB_CT_EXCLUDED="[cnpg-cluster vso-utils]"
  export STUB_CT_REPOS="[bitnami=https://charts.bitnami.com/bitnami]"

  run_block "$BLOCK"

  expect_install false
}

# A ct that cannot tell what changed (an unknown target branch, a bad
# configuration) must fail the job as `ct install` would, not be read as
# "nothing to install".
test_a_failing_ct_fails_the_step_and_shows_why() {
  gate_env
  export STUB_CT_FAIL="Error: unknown revision or path not in the working tree: main"

  run_block "$BLOCK"

  assert_status 1
  assert_output_contains "unknown revision"
  if grep -q "install=" "$GITHUB_OUTPUT"; then
    printf 'FAIL: decided without an answer from ct\n%s\n' "$(cat "$GITHUB_OUTPUT")" >&2
    exit 1
  fi
}

# The install step diffs against the same branch with the same configuration;
# anything else and the two could disagree about what changed.
test_ct_is_asked_what_the_install_will_be_asked() {
  gate_env

  run_block "$BLOCK"

  assert_called "ct|list-changed --config ci/ct.yaml --target-branch main --print-config"
}

test_the_cluster_and_the_install_wait_for_the_answer() {
  local step condition
  for step in 'Create kind cluster' 'Run chart-testing (install)'; do
    condition=$(yq ".jobs.\"test-charts\".steps[] | select(.name == \"$step\") | .[\"if\"]" \
      "$WORKFLOWS_DIR/test-helm.yml")
    # shellcheck disable=SC2016 # the Actions marker is meant to stay literal
    if [ "$condition" != '${{ steps.charts.outputs.install == '"'true'"' }}' ]; then
      printf 'FAIL: %s is not conditional on the answer: %q\n' "$step" "$condition" >&2
      exit 1
    fi
  done
}

test_the_question_comes_before_the_cluster() {
  local names name position gate=-1 kind=-1 install=-1
  mapfile -t names < <(yq '.jobs."test-charts".steps[].name' "$WORKFLOWS_DIR/test-helm.yml")
  position=0
  for name in "${names[@]}"; do
    [ "$name" = "$STEP" ] && gate=$position
    [ "$name" = "Create kind cluster" ] && kind=$position
    [ "$name" = "Run chart-testing (install)" ] && install=$position
    position=$((position + 1))
  done

  if [ "$gate" -lt 0 ] || [ "$gate" -ge "$kind" ] || [ "$kind" -ge "$install" ]; then
    printf 'FAIL: expected the question, then the cluster, then the install; got steps %s, %s, %s\n' \
      "$gate" "$kind" "$install" >&2
    exit 1
  fi
}

# Defined on the job so the question and the install cannot read different ones.
test_the_configuration_path_is_defined_once() {
  local job step_overrides
  job=$(yq '.jobs."test-charts".env.CT_CONF_PATH' "$WORKFLOWS_DIR/test-helm.yml")
  # shellcheck disable=SC2016 # the Actions marker is meant to stay literal
  if [ "$job" != '${{ inputs.CT_CONF_PATH }}' ]; then
    printf 'FAIL: the job does not define CT_CONF_PATH from the input: %q\n' "$job" >&2
    exit 1
  fi

  step_overrides=$(yq '.jobs."test-charts".steps[] | select(.env.CT_CONF_PATH != null) | .name' \
    "$WORKFLOWS_DIR/test-helm.yml")
  if [ -n "$step_overrides" ]; then
    printf 'FAIL: a step defines its own CT_CONF_PATH: %s\n' "$step_overrides" >&2
    exit 1
  fi
}

run_tests
