#!/usr/bin/env bash
# The skills tell an agent how to call these workflows, so what they state has to
# be what the workflows declare.
#
# skills/fabnum-cicd-pipeline/references/workflows.md lists every reusable
# workflow with its required inputs, its secrets and the permissions a caller
# must grant. A table maintained by hand drifts the day a workflow gains an
# input, and an agent then writes a call that GitHub rejects at parse time. Each
# row is compared here with the `on.workflow_call` and the job permissions of the
# file it names, so the table cannot fall behind without a red build.

# shellcheck source=ci/tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SKILLS_DIR="$REPO_ROOT/skills"
CATALOG="$SKILLS_DIR/fabnum-cicd-pipeline/references/workflows.md"

reusable_workflows() {
  local f
  for f in "$WORKFLOWS_DIR"/*.yml; do
    if [ "$(yq '.on.workflow_call // "null"' "$f")" != "null" ]; then
      basename "$f" .yml
    fi
  done
}

# Column N of the catalog row for a workflow ($2 is the name, $3 the usage...).
catalog_cell() {
  grep -F "| \`$1\` |" "$CATALOG" | awk -F'|' -v col="$2" '{ print $col }'
}

# The backticked tokens of a cell, one per line, sorted. `{}` stands for "no
# permission" and is not a token.
cell_tokens() {
  grep -o '`[^`]*`' | tr -d '`' | grep -vx '{}' | sort
}

test_every_reusable_workflow_is_in_the_catalog() {
  local name missing=""
  for name in $(reusable_workflows); do
    if ! grep -qF "| \`$name\` |" "$CATALOG"; then
      missing="${missing}  ${name}"$'\n'
    fi
  done
  if [ -n "$missing" ]; then
    printf 'FAIL: reusable workflows missing from %s:\n%s' "$CATALOG" "$missing" >&2
    exit 1
  fi
}

test_the_catalog_lists_no_workflow_that_does_not_exist() {
  local name unknown=""
  for name in $(grep -o '^| `[a-z0-9-]*` |' "$CATALOG" | tr -d '|` '); do
    if [ ! -f "$WORKFLOWS_DIR/$name.yml" ]; then
      unknown="${unknown}  ${name}"$'\n'
    fi
  done
  if [ -n "$unknown" ]; then
    printf 'FAIL: the catalog lists workflows that do not exist:\n%s' "$unknown" >&2
    exit 1
  fi
}

test_required_inputs_match_the_workflows() {
  local name expected actual bad=""
  for name in $(reusable_workflows); do
    expected=$(yq '.on.workflow_call.inputs // {} | to_entries | .[] | select(.value.required == true) | .key' \
      "$WORKFLOWS_DIR/$name.yml" | sort)
    actual=$(catalog_cell "$name" 4 | cell_tokens)
    if [ "$expected" != "$actual" ]; then
      bad="${bad}  ${name}: workflow requires [$(echo "$expected" | tr '\n' ' ')] but the catalog says [$(echo "$actual" | tr '\n' ' ')]"$'\n'
    fi
  done
  if [ -n "$bad" ]; then
    printf 'FAIL: required inputs differ from the workflows:\n%s' "$bad" >&2
    exit 1
  fi
}

test_secrets_match_the_workflows() {
  local name expected actual bad=""
  for name in $(reusable_workflows); do
    expected=$(yq '.on.workflow_call.secrets // {} | keys | .[]' "$WORKFLOWS_DIR/$name.yml" | sort)
    actual=$(catalog_cell "$name" 5 | cell_tokens)
    if [ "$expected" != "$actual" ]; then
      bad="${bad}  ${name}: workflow declares [$(echo "$expected" | tr '\n' ' ')] but the catalog says [$(echo "$actual" | tr '\n' ' ')]"$'\n'
    fi
  done
  if [ -n "$bad" ]; then
    printf 'FAIL: secrets differ from the workflows:\n%s' "$bad" >&2
    exit 1
  fi
}

# GitHub validates the permissions of every job of a called workflow, so the
# caller must grant the highest level any job asks for, per scope.
test_permissions_match_the_union_of_the_jobs() {
  local name expected actual bad=""
  for name in $(reusable_workflows); do
    expected=$(yq -o=json -I=0 '[.jobs[].permissions // {} | to_entries[]]' "$WORKFLOWS_DIR/$name.yml" |
      jq -r 'group_by(.key)[] | .[0].key + ": " + (if any(.value == "write") then "write" else "read" end)' | sort)
    actual=$(catalog_cell "$name" 6 | cell_tokens)
    if [ "$expected" != "$actual" ]; then
      bad="${bad}  ${name}: jobs ask for [$(echo "$expected" | tr '\n' ';')] but the catalog says [$(echo "$actual" | tr '\n' ';')]"$'\n'
    fi
  done
  if [ -n "$bad" ]; then
    printf 'FAIL: permissions differ from the workflows:\n%s' "$bad" >&2
    exit 1
  fi
}

test_every_doc_link_of_the_catalog_resolves() {
  local link bad=""
  for link in $(grep -o '(\.\./\.\./\.\./docs/[^)]*)' "$CATALOG" | tr -d '()'); do
    if [ ! -f "$(dirname "$CATALOG")/$link" ]; then
      bad="${bad}  ${link}"$'\n'
    fi
  done
  if [ -n "$bad" ]; then
    printf 'FAIL: broken documentation links in the catalog:\n%s' "$bad" >&2
    exit 1
  fi
}

# The marketplace points at ./skills, and an agent finds a skill by its name.
test_each_skill_is_named_after_its_directory() {
  local file dir name bad=""
  for file in "$SKILLS_DIR"/*/SKILL.md; do
    dir=$(basename "$(dirname "$file")")
    name=$(sed -n 's/^name: *//p' "$file" | head -n1)
    if [ "$name" != "$dir" ]; then
      bad="${bad}  ${dir}: name is '${name}'"$'\n'
    fi
    if ! grep -q '^description: ' "$file"; then
      bad="${bad}  ${dir}: no description"$'\n'
    fi
  done
  if [ -n "$bad" ]; then
    printf 'FAIL: skills whose frontmatter does not match:\n%s' "$bad" >&2
    exit 1
  fi
}

# A skill must not send an agent to a workflow that was removed or renamed.
test_skills_only_call_workflows_that_exist() {
  local ref bad=""
  for ref in $(grep -rhoE 'fabnum-cicd/\.github/workflows/[a-z0-9-]+\.yml' "$SKILLS_DIR" | sort -u); do
    if [ ! -f "$WORKFLOWS_DIR/$(basename "$ref")" ]; then
      bad="${bad}  ${ref}"$'\n'
    fi
  done
  if [ -n "$bad" ]; then
    printf 'FAIL: skills call workflows that do not exist:\n%s' "$bad" >&2
    exit 1
  fi
}

run_tests
