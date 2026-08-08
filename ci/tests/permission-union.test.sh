#!/usr/bin/env bash
# Reusable workflows must not force their callers to over-grant permissions.
#
# GitHub validates the permissions requested by EVERY job of a called workflow
# at parse time, regardless of each job's `if:`. A caller therefore has to grant
# the union of all of them, and a job that never runs still costs the caller its
# scopes. actionlint does not check this, and the failure is silent: the call
# simply works, with more privilege than it needs.
#
# The invariant below catches the avoidable shape - a scope that some jobs want,
# others do not, and no always-running job needs. Whoever calls such a workflow
# hands over that scope even when nothing will ever use it.
#
# "Always-running" here means a job whose `if:` does not depend on `inputs.`:
# only those are switchable by the caller. A job gated on event data or on a
# `needs.*.result` is not a caller decision, so its scopes are unavoidable.

# shellcheck source=ci/tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Scopes deliberately left forced, with the reason. Anything not listed here
# must not appear - a new entry is a design decision, not a formality.
# Format: <workflow>:<scope> => reason
declare -A ACCEPTED_EXCESS=(
  ["scan-gitleaks.yml:pull-requests"]="scan-notif posts the leak summary on the pull request; a caller that passes no PR_NUMBER still grants it. Splitting the notifier out would separate a scan from the report it exists to produce."
  ["scan-trivy.yml:packages"]="images-scan pulls the image to scan; a config-only caller still grants it. Read-only, and the two scans share the SARIF upload plumbing."
  ["scan-trivy.yml:contents"]="both scans read the checked-out tree; only a caller that selects neither scan - a no-op call - grants this unused."
  ["scan-trivy.yml:security-events"]="both scans upload SARIF; only a caller that selects neither scan - a no-op call - grants this unused."
)

rank_of() {
  case "$1" in
    none) echo 0 ;;
    read) echo 1 ;;
    write) echo 2 ;;
    *) echo 0 ;;
  esac
}

# Reusable workflows only - a workflow nobody can call has no caller to burden.
reusable_workflows() {
  local f
  for f in "$WORKFLOWS_DIR"/*.yml; do
    if [ "$(yq '.on.workflow_call // "null"' "$f")" != "null" ]; then
      basename "$f"
    fi
  done
}

# `<job id>\t<caller-switchable>\t<scope>=<level>,...` per job.
job_permissions() {
  local workflow="$1"
  yq -o=json -I=0 '
    .jobs | to_entries[]
    | {"job": .key, "if": (.value.if // ""), "perms": (.value.permissions // {})}
  ' "$WORKFLOWS_DIR/$workflow" |
    jq -r '[
      .job,
      (if (.["if"] | test("inputs\\.")) then "switchable" else "always" end),
      (.perms | to_entries | map(.key + "=" + (.value | tostring)) | join(","))
    ] | @tsv'
}

# A scope is forced excess when some job requests it, some job does not, and no
# always-running job requests it: the caller grants it for a job it may never
# enable. When *every* job requests it the only way to avoid it is to enable no
# job at all, which is a call that does nothing - not a configuration worth
# designing for.
forced_excess_scopes() {
  local workflow="$1" job kind pairs scope level
  local -A wanted_by_any=() wanted_by_all=() wanted_by_always=()
  local job_count=0

  while IFS=$'\t' read -r job kind pairs; do
    job_count=$((job_count + 1))
    local -A this_job=()
    if [ -n "$pairs" ]; then
      local pair
      for pair in ${pairs//,/ }; do
        scope="${pair%%=*}"; level="${pair##*=}"
        [ "$(rank_of "$level")" -eq 0 ] && continue
        this_job["$scope"]=1
        wanted_by_any["$scope"]=1
        [ "$kind" = "always" ] && wanted_by_always["$scope"]=1
      done
    fi
    for scope in "${!wanted_by_any[@]}"; do
      if [ -n "${this_job[$scope]:-}" ]; then
        wanted_by_all["$scope"]=$(( ${wanted_by_all[$scope]:-0} + 1 ))
      fi
    done
  done < <(job_permissions "$workflow")

  for scope in "${!wanted_by_any[@]}"; do
    [ -n "${wanted_by_always[$scope]:-}" ] && continue
    [ "${wanted_by_all[$scope]:-0}" -eq "$job_count" ] && continue
    echo "$scope"
  done
}

test_no_workflow_forces_an_unusable_scope_on_its_callers() {
  local workflow scope key found=0
  while read -r workflow; do
    while read -r scope; do
      [ -z "$scope" ] && continue
      key="$workflow:$scope"
      if [ -z "${ACCEPTED_EXCESS[$key]:-}" ]; then
        printf 'FAIL: %s forces callers to grant %q for a job they may never enable.\n' \
          "$workflow" "$scope" >&2
        printf '      Split that job into its own reusable workflow, or record the\n' >&2
        printf '      trade-off in ACCEPTED_EXCESS with the reason it stays.\n' >&2
        found=1
      fi
    done < <(forced_excess_scopes "$workflow")
  done < <(reusable_workflows)
  [ "$found" -eq 0 ] || exit 1
}

# An entry that no longer describes the workflows is worse than no entry: it
# reads as a reviewed decision while covering nothing.
test_every_accepted_exception_still_applies() {
  local key workflow scope still
  for key in "${!ACCEPTED_EXCESS[@]}"; do
    workflow="${key%%:*}"; scope="${key##*:}"
    if [ ! -f "$WORKFLOWS_DIR/$workflow" ]; then
      printf 'FAIL: ACCEPTED_EXCESS names %s, which does not exist\n' "$workflow" >&2
      exit 1
    fi
    still=$(forced_excess_scopes "$workflow" | grep -Fx "$scope" || true)
    if [ -z "$still" ]; then
      printf 'FAIL: ACCEPTED_EXCESS still excuses %s in %s, but it is no longer forced - drop the entry\n' \
        "$scope" "$workflow" >&2
      exit 1
    fi
  done
}

# The sharpest form of the same problem: a job declaring `permissions: {}` -
# it needs nothing at all - beside a job declaring write scopes, so callers
# grant writes to run a job that wants none.
test_a_permissionless_job_never_shares_a_workflow_with_a_scoped_one() {
  local workflow job kind pairs
  while read -r workflow; do
    local empty_jobs=() scoped_jobs=()
    while IFS=$'\t' read -r job kind pairs; do
      # Only `permissions: {}` counts. A job with no `permissions:` key at all
      # inherits the caller's grant and makes no claim about what it needs.
      if [ "$(yq ".jobs.\"$job\" | has(\"permissions\")" "$WORKFLOWS_DIR/$workflow")" != "true" ]; then
        continue
      fi
      if [ -z "$pairs" ]; then
        [ "$kind" = "switchable" ] && empty_jobs+=("$job")
      else
        scoped_jobs+=("$job")
      fi
    done < <(job_permissions "$workflow")

    if [ "${#empty_jobs[@]}" -gt 0 ] && [ "${#scoped_jobs[@]}" -gt 0 ]; then
      # shellcheck disable=SC2016 # `permissions: {}` is quoted YAML, not an expansion
      printf 'FAIL: %s job(s) %s declare `permissions: {}` but callers must still grant %s for %s\n' \
        "$workflow" "${empty_jobs[*]}" "$(job_permissions "$workflow" | cut -f3 | tr '\n' ' ')" "${scoped_jobs[*]}" >&2
      exit 1
    fi
  done < <(reusable_workflows)
}

# The three assertions above are only worth something if they can fail. Build
# the offending shape as a fixture and confirm it is caught.
test_the_invariant_catches_the_shape_it_was_written_for() {
  local fixture_dir fixture
  fixture_dir=$(mktemp -d)
  fixture="$fixture_dir/regression.yml"
  cat >"$fixture" <<'YAML'
on:
  workflow_call:
    inputs:
      RUN_MODE:
        type: string
        required: true
jobs:
  caller:
    runs-on: ubuntu-24.04
    permissions: {}
    if: ${{ inputs.RUN_MODE == 'caller' }}
    steps:
    - run: 'true'
  called:
    runs-on: ubuntu-24.04
    permissions:
      contents: write
    if: ${{ inputs.RUN_MODE == 'called' }}
    steps:
    - run: 'true'
YAML

  local saved="$WORKFLOWS_DIR"
  WORKFLOWS_DIR="$fixture_dir"
  local excess
  excess=$(forced_excess_scopes regression.yml)
  WORKFLOWS_DIR="$saved"
  rm -rf "$fixture_dir"

  if [ "$excess" != "contents" ]; then
    printf 'FAIL: the pre-split update-helm-chart shape was not flagged (got %q)\n' "$excess" >&2
    exit 1
  fi
}

run_tests
