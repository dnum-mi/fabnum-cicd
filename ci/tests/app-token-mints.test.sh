#!/usr/bin/env bash
# Structural invariants for every actions/create-github-app-token step across
# the reusable workflows. These encode the security argument the App support
# rests on, so that adding a mint step cannot quietly weaken it.

# shellcheck source=ci/tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

WORKFLOWS=(build-docker.yml dispatch-helm-chart.yml release-app.yml release-helm.yml scan-trivy.yml update-helm-chart.yml)

# Emits one `<workflow>\t<job>\t<keys>\t<key=value pairs>` line per mint, with
# keys comma-separated and pairs semicolon-separated.
#
# The `with:` block is NOT passed through as a JSON string. It used to be, via
# `@json` plus a sed re-parse, and every quote arrived escaped as \" - so a
# `[[ "$with" == *'"owner"'* ]]` test could never match and the scope invariant
# below was vacuous: deleting `repositories:` from a mint still reported green.
# jq splits the fields here and @tsv emits them, so nothing depends on matching
# a quote through two layers of escaping.
each_mint() {
  local workflow
  for workflow in "${WORKFLOWS[@]}"; do
    yq -o=json -I=0 "
      .jobs | to_entries[] as \$job
      | \$job.value.steps[]
      | select(has(\"uses\"))
      | select(.uses | test(\"create-github-app-token\"))
      | {\"workflow\": \"$workflow\", \"job\": \$job.key, \"with\": (.with // {})}
    " "$WORKFLOWS_DIR/$workflow" |
      jq -r '[
        .workflow,
        .job,
        (.with | keys | join(",")),
        (.with | to_entries | map(.key + "=" + (.value | tostring)) | join(";"))
      ] | @tsv'
  done
}

# True when the mint's key list contains exactly this key.
mint_has_key() {
  local keys="$1" key="$2"
  [[ ",$keys," == *",$key,"* ]]
}

# Jobs that mint a token, as `<workflow>\t<job>`.
each_minting_job() {
  each_mint | cut -f1,2 | sort -u
}

test_at_least_one_mint_exists_in_every_workflow() {
  local workflow count
  for workflow in "${WORKFLOWS[@]}"; do
    count=$(each_mint | grep -c "^$workflow	")
    if [ "$count" -eq 0 ]; then
      printf 'FAIL: %s declares no App token mint; the auth modes are meant to be uniform\n' "$workflow" >&2
      exit 1
    fi
  done
}

test_every_mint_narrows_its_permissions() {
  local workflow job keys pairs
  while IFS=$'\t' read -r workflow job keys pairs; do
    # A token minted without permission-* inherits EVERY permission the App
    # installation holds, regardless of the job's own `permissions:` block.
    if [[ "$keys" != *'permission-'* ]]; then
      printf 'FAIL: %s job %q mints a token with no permission-* narrowing: %s\n' \
        "$workflow" "$job" "$keys" >&2
      exit 1
    fi
  done < <(each_mint)
}

test_owner_and_repositories_are_set_together() {
  local workflow job keys pairs has_owner has_repositories
  while IFS=$'\t' read -r workflow job keys pairs; do
    has_owner=false; has_repositories=false
    mint_has_key "$keys" owner && has_owner=true
    mint_has_key "$keys" repositories && has_repositories=true

    # `owner` without `repositories` widens the token to every repository in the
    # installation, at the installation's full permissions. Leaving both unset
    # resolves to the current repository, which is what same-repo mints want.
    if [ "$has_owner" != "$has_repositories" ]; then
      printf 'FAIL: %s job %q sets exactly one of owner/repositories: %s\n' \
        "$workflow" "$job" "$keys" >&2
      exit 1
    fi
  done < <(each_mint)
}

# The assertion above is only worth anything if it can fail. It could not before:
# the key match was tested against JSON-escaped text it never matched, so a mint
# with `owner` and no `repositories` passed. Prove the matcher works on both the
# widened shape and the two legitimate ones before trusting the real check.
test_the_scope_invariant_can_actually_fail() {
  if mint_has_key "client-id,private-key,permission-contents" owner; then
    printf 'FAIL: mint_has_key matched owner in a key list that lacks it\n' >&2
    exit 1
  fi

  if ! mint_has_key "client-id,owner,repositories,permission-actions" owner; then
    printf 'FAIL: mint_has_key failed to match owner in a key list that has it\n' >&2
    exit 1
  fi

  # The widened shape the real assertion exists to reject.
  local keys="client-id,private-key,owner,permission-actions"
  local has_owner=false has_repositories=false
  mint_has_key "$keys" owner && has_owner=true
  mint_has_key "$keys" repositories && has_repositories=true
  if [ "$has_owner" = "$has_repositories" ]; then
    printf 'FAIL: an owner-without-repositories mint would not be flagged\n' >&2
    exit 1
  fi
}

test_build_and_scan_tokens_are_read_only() {
  local workflow job keys pairs
  while IFS=$'\t' read -r workflow job keys pairs; do
    case "$workflow" in
      build-docker.yml|scan-trivy.yml) ;;
      *) continue ;;
    esac

    # build-docker mounts this token into the Docker build and scan-trivy only
    # needs it to download a database. Neither has any reason to write, and
    # build-docker's is readable by everything the Dockerfile executes.
    # Checked against the values, so a key merely containing "write" cannot
    # satisfy or trip it.
    if [[ ";$pairs;" == *'=write;'* || "$pairs" == *'=write' ]]; then
      printf 'FAIL: %s job %q mints a write-capable token: %s\n' \
        "$workflow" "$job" "$pairs" >&2
      exit 1
    fi
  done < <(each_mint)
}

test_every_minting_job_validates_its_credentials() {
  local workflow job steps
  while IFS=$'\t' read -r workflow job; do
    steps=$(yq ".jobs.\"$job\".steps[].name" "$WORKFLOWS_DIR/$workflow")

    # Exactly one of APP_CLIENT_ID/APP_PRIVATE_KEY silently falls through to
    # GH_PAT or GITHUB_TOKEN, which is never what the caller meant.
    if [[ "$steps" != *"Validate inputs"* && "$steps" != *"Validate credentials"* ]]; then
      printf 'FAIL: %s job %q mints a token but has no credential validation step\n' \
        "$workflow" "$job" >&2
      exit 1
    fi
  done < <(each_minting_job)
}

test_mints_are_pinned_to_a_commit_sha() {
  local uses
  while read -r uses; do
    if [[ ! "$uses" =~ @[0-9a-f]{40}$ ]]; then
      printf 'FAIL: unpinned action reference: %s\n' "$uses" >&2
      exit 1
    fi
  done < <(
    for workflow in "${WORKFLOWS[@]}"; do
      yq '.jobs[].steps[] | select(has("uses")) | select(.uses | test("create-github-app-token")) | .uses' \
        "$WORKFLOWS_DIR/$workflow"
    done
  )
}

run_tests
