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

# A chart at a given version, ready for one bump. The 4th argument sets the
# appVersion already in Chart.yaml - what 'auto' derives its level from.
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
appVersion: "${4:-1.0.0}"
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

# --- UPGRADE_TYPE=auto: the chart mirrors the app's bump level, derived from
# --- the appVersion delta; APP_VERSION being a prerelease selects the flow.

test_auto_maps_an_app_patch_to_a_chart_patch() {
  chart_at 1.2.3 auto rc 1.0.0
  export APP_VERSION="1.0.1"
  run_block "$UPDATE"
  assert_status 0
  assert_version 1.2.4
}

test_auto_maps_an_app_minor_to_a_chart_minor() {
  chart_at 1.2.3 auto rc 1.0.0
  export APP_VERSION="1.1.0"
  run_block "$UPDATE"
  assert_status 0
  assert_version 1.3.0
}

test_auto_maps_an_app_major_to_a_chart_major() {
  chart_at 1.2.3 auto rc 1.0.0
  export APP_VERSION="2.0.0"
  run_block "$UPDATE"
  assert_status 0
  assert_version 2.0.0
}

test_auto_enters_a_prerelease_cycle_at_the_app_level() {
  # App went 0.2.2 -> 0.3.0-rc (minor): the chart's cycle opens at minor too,
  # not at the blanket patch the plain 'prerelease' type uses.
  chart_at 0.2.8 auto rc 0.2.2
  export APP_VERSION="0.3.0-rc"
  run_block "$UPDATE"
  assert_status 0
  assert_version 0.3.0-rc
}

test_auto_iterates_a_running_cycle() {
  chart_at 0.3.0-rc auto rc 0.3.0-rc
  export APP_VERSION="0.3.0-rc.1"
  run_block "$UPDATE"
  assert_status 0
  assert_version 0.3.0-rc.1
}

test_auto_escalates_a_running_cycle_when_the_app_level_rises() {
  # The cycle started from fixes (chart 0.2.9-rc.2), then a feat raised the
  # app to 0.3.0-rc.1: the chart base escalates the same way release-please
  # escalated the app - bump the base, carry the prerelease part verbatim.
  chart_at 0.2.9-rc.2 auto rc 0.2.3-rc.1
  export APP_VERSION="0.3.0-rc.1"
  run_block "$UPDATE"
  assert_status 0
  assert_version 0.3.0-rc.2
}

test_auto_does_not_reescalate_an_already_escalated_cycle() {
  # The base already encodes the minor (patch == 0): later iterations only
  # advance the counter.
  chart_at 0.3.0-rc.2 auto rc 0.2.3-rc.1
  export APP_VERSION="0.3.0-rc.2"
  run_block "$UPDATE"
  assert_status 0
  assert_version 0.3.0-rc.3
}

test_auto_escalates_to_major_and_carries_the_counter() {
  chart_at 0.3.0-rc.2 auto rc 0.3.0-rc.1
  export APP_VERSION="1.0.0-rc.1"
  run_block "$UPDATE"
  assert_status 0
  assert_version 1.0.0-rc.2
}

test_auto_promotes_by_stripping_the_prerelease() {
  # On the release branch APP_VERSION is stable, and the level was baked into
  # the base during the cycle - promotion only drops the suffix.
  chart_at 0.3.0-rc.2 auto rc 0.3.0-rc.2
  export APP_VERSION="0.3.0"
  run_block "$UPDATE"
  assert_status 0
  assert_version 0.3.0
}

test_auto_rejects_a_non_semver_app_version() {
  # APP_VERSION was passed by the caller on this run - unlike the two
  # fallback cases below, failing here faults something the caller said.
  chart_at 1.2.3 auto rc 1.0.0
  export APP_VERSION="not-semver"
  run_block "$UPDATE"
  assert_status 1 "auto cannot derive a level from a non-semver APP_VERSION"
  assert_output_contains "not semver"
}

test_auto_without_app_version_falls_back_to_patch() {
  # 'auto' is the default, and a chart-only release is a legitimate use of
  # the default: warn and take the smallest bump rather than fail.
  chart_at 1.2.3 auto
  run_block "$UPDATE"
  assert_status 0 "a chart-only release under the default type must not fail"
  assert_version 1.2.4
  assert_output_contains "::warning::"
}

test_auto_falls_back_to_patch_on_a_non_semver_current_app_version() {
  # A pre-pipeline chart commonly holds 'latest': the first auto run cannot
  # derive a level, but it writes a real appVersion, so the next one can.
  chart_at 1.2.3 auto rc latest
  export APP_VERSION="1.1.0"
  run_block "$UPDATE"
  assert_status 0
  assert_version 1.2.4
  assert_output_contains "::warning::"
}

test_auto_keeps_the_prerelease_flow_when_the_level_is_unknown() {
  # The level falls back, the flow must not: a prerelease APP_VERSION must
  # never yield a stable chart version, whatever the chart held before.
  chart_at 1.2.3 auto rc latest
  export APP_VERSION="1.1.0-rc"
  run_block "$UPDATE"
  assert_status 0
  assert_version 1.2.4-rc
}

# --- 'Validate inputs' guards specific to the version contract.
VALIDATE=$(extract_run update-helm-chart.yml update "Validate inputs")

validate_env() {
  export HAS_PARTIAL_APP_AUTH="false"
  export RUN_MODE="local"
  export AUTOMERGE_METHOD="auto"
  export APP_VERSION="1.4.0"
  export UPGRADE_TYPE="patch"
  export PRERELEASE_IDENTIFIER="rc"
}

test_validate_accepts_every_upgrade_type() {
  local type
  for type in major minor patch prerelease auto; do
    validate_env
    export UPGRADE_TYPE="$type"
    run_block "$VALIDATE"
    assert_status 0 "UPGRADE_TYPE '$type' is a supported value"
  done
}

test_validate_rejects_an_unknown_upgrade_type() {
  validate_env
  export UPGRADE_TYPE="patsh"
  run_block "$VALIDATE"
  assert_status 1
  assert_output_contains "UPGRADE_TYPE must be"
}

test_validate_accepts_auto_without_app_version() {
  # 'auto' is the default and empty APP_VERSION is the documented chart-only
  # release: their combination must pass validation (the bump step warns and
  # falls back to patch - covered above).
  validate_env
  export UPGRADE_TYPE="auto"
  export APP_VERSION=""
  run_block "$VALIDATE"
  assert_status 0 "the default type with the documented empty APP_VERSION must validate"
}

run_tests
