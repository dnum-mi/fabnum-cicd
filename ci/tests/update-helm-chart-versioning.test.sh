#!/usr/bin/env bash
# update-helm-chart.yml - version bump semantics.
#
# The full lifecycle a chart goes through under the two-branch flow: entering a
# prerelease cycle, iterating it, switching identifiers, promoting to a final
# version, and the plain bumps. Each case runs the workflow's real `run:` block
# against a real Chart.yaml.

# shellcheck source=ci/tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

UPDATE=$(extract_run update-helm-chart.yml update "update chart version")

# A chart at a given version, ready for one bump.
chart_at() {
  export CHART_DIR="charts"
  export CHART_NAME="my-app"
  export APP_VERSION=""
  export UPGRADE_TYPE="${2:-patch}"
  export PRERELEASE_IDENTIFIER="${3:-rc}"
  export HELM_DOCS_VERSION="v1.14.2"

  mkdir -p "$SANDBOX/$CHART_DIR/$CHART_NAME"
  cat >"$SANDBOX/$CHART_DIR/$CHART_NAME/Chart.yaml" <<YAML
apiVersion: v2
name: my-app
type: application
version: $1
appVersion: "1.0.0"
YAML

  cd "$SANDBOX" || exit 1
}

assert_version() {
  local actual
  actual=$(yq '.version' "$SANDBOX/charts/my-app/Chart.yaml")
  if [ "$actual" != "$1" ]; then
    printf 'FAIL: expected chart version %q, got %q\n---- output ----\n%s\n----------------\n' \
      "$1" "$actual" "$RUN_OUTPUT" >&2
    exit 1
  fi
}

test_patch_bumps_the_patch_number() {
  chart_at 1.2.3 patch
  run_block "$UPDATE"
  assert_status 0
  assert_version 1.2.4
}

test_minor_bumps_and_resets_patch() {
  chart_at 1.2.3 minor
  run_block "$UPDATE"
  assert_status 0
  assert_version 1.3.0
}

test_major_bumps_and_resets_the_rest() {
  chart_at 1.2.3 major
  run_block "$UPDATE"
  assert_status 0
  assert_version 2.0.0
}

test_prerelease_from_a_release_prepares_the_next_patch() {
  chart_at 0.2.0 prerelease
  run_block "$UPDATE"
  assert_status 0
  assert_version 0.2.1-rc
}

test_prerelease_numbers_a_bare_identifier() {
  chart_at 1.0.0-rc prerelease
  run_block "$UPDATE"
  assert_status 0
  assert_version 1.0.0-rc.1
}

test_prerelease_increments_a_numbered_identifier() {
  chart_at 1.0.0-rc.1 prerelease
  run_block "$UPDATE"
  assert_status 0
  assert_version 1.0.0-rc.2
}

test_prerelease_switches_identifier_without_a_number() {
  chart_at 1.0.0-alpha.2 prerelease beta
  run_block "$UPDATE"
  assert_status 0
  assert_version 1.0.0-beta
}

test_any_release_bump_promotes_a_prerelease_as_is() {
  # 1.0.0-rc.2 already names its release version; the bump only drops the
  # prerelease part, whatever UPGRADE_TYPE asked for.
  local type
  for type in patch minor major; do
    chart_at 1.0.0-rc.2 "$type"
    run_block "$UPDATE"
    assert_status 0 "promoting with UPGRADE_TYPE=$type"
    assert_version 1.0.0
  done
}

test_prerelease_reads_back_any_identifier_it_can_write() {
  # The validation accepts '^[A-Za-z0-9-]+$', so the parse on the NEXT run must
  # too. A narrower parse regex stamped '1.0.0-rc2' on the first run and then
  # failed 'Unexpected prerelease format' on every run after it.
  chart_at 1.0.0-rc2 prerelease rc2
  run_block "$UPDATE"
  assert_status 0 "an identifier the validation accepted must parse back"
  assert_version 1.0.0-rc2.1
}

run_tests
