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

# Catalog columns: $1 is the empty text before the first `|`, then name, usage...
COL_REQUIRED_INPUTS=4
COL_SECRETS=5
COL_PERMISSIONS=6

fail_if_any() {
  local title="$1" problems="$2"
  if [ -n "$problems" ]; then
    printf 'FAIL: %s\n%s' "$title" "$problems" >&2
    exit 1
  fi
}

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
  # shellcheck disable=SC2016 # the backticks are literal Markdown, not a command
  grep -o '`[^`]*`' | tr -d '`' | grep -vx '{}' | sort
}

test_every_reusable_workflow_is_in_the_catalog() {
  local name missing=""
  for name in $(reusable_workflows); do
    if ! grep -qF "| \`$name\` |" "$CATALOG"; then
      missing="${missing}  ${name}"$'\n'
    fi
  done
  fail_if_any "reusable workflows missing from the catalog:" "$missing"
}

test_the_catalog_lists_no_workflow_that_does_not_exist() {
  local name unknown=""
  # shellcheck disable=SC2016 # the backticks are literal Markdown, not a command
  while IFS= read -r name; do
    if [ ! -f "$WORKFLOWS_DIR/$name.yml" ]; then
      unknown="${unknown}  ${name}"$'\n'
    fi
  done < <(grep -o '^| `[a-z0-9-]*` |' "$CATALOG" | tr -d '|` ')
  fail_if_any "the catalog lists workflows that do not exist:" "$unknown"
}

# Compares one catalog column with what the workflows declare. `expected_of` is
# the name of a function that prints the expected tokens of a workflow file, one
# per line (the expected_* functions below).
check_column() {
  local column="$1" title="$2" expected_of="$3" name expected actual bad=""
  for name in $(reusable_workflows); do
    expected=$("$expected_of" "$WORKFLOWS_DIR/$name.yml" | sort)
    actual=$(catalog_cell "$name" "$column" | cell_tokens)
    if [ "$expected" != "$actual" ]; then
      bad="${bad}  ${name}: workflow has [$(echo "$expected" | tr '\n' ';')] but the catalog says [$(echo "$actual" | tr '\n' ';')]"$'\n'
    fi
  done
  fail_if_any "$title" "$bad"
}

expected_required_inputs() {
  yq '.on.workflow_call.inputs // {} | to_entries | .[] | select(.value.required == true) | .key' "$1"
}

expected_secrets() {
  yq '.on.workflow_call.secrets // {} | keys | .[]' "$1"
}

expected_required_secrets() {
  yq '.on.workflow_call.secrets // {} | to_entries | .[] | select(.value.required == true) | .key' "$1"
}

# The secrets a catalog cell marks "(required)", one per line, sorted.
catalog_required_secrets() {
  # shellcheck disable=SC2016 # the backticks are literal Markdown, not a command
  grep -o '`[^`]*` (required)' | sed 's/` (required)$//; s/^`//' | sort
}

# GitHub validates the permissions of every job of a called workflow, so the
# caller must grant the highest level any job asks for, per scope.
expected_permissions() {
  yq -o=json -I=0 '[.jobs[].permissions // {} | to_entries[]]' "$1" |
    jq -r 'group_by(.key)[] | .[0].key + ": " + (if any(.value == "write") then "write" else "read" end)'
}

test_required_inputs_match_the_workflows() {
  check_column "$COL_REQUIRED_INPUTS" "required inputs differ from the workflows:" expected_required_inputs
}

test_secrets_match_the_workflows() {
  check_column "$COL_SECRETS" "secrets differ from the workflows:" expected_secrets
}

test_required_secrets_are_marked_in_the_catalog() {
  local name expected actual bad=""
  for name in $(reusable_workflows); do
    expected=$(expected_required_secrets "$WORKFLOWS_DIR/$name.yml" | sort)
    actual=$(catalog_cell "$name" "$COL_SECRETS" | catalog_required_secrets)
    if [ "$expected" != "$actual" ]; then
      bad="${bad}  ${name}: workflow requires [$(echo "$expected" | tr '\n' ';')] but the catalog marks [$(echo "$actual" | tr '\n' ';')]"$'\n'
    fi
  done
  fail_if_any "required secrets differ from the workflows:" "$bad"
}

test_permissions_match_the_union_of_the_jobs() {
  check_column "$COL_PERMISSIONS" "permissions differ from the workflows:" expected_permissions
}

# expected_permissions reads job-level maps only. A workflow-level `permissions:`
# or a shorthand such as `read-all` would be missed silently, so they are refused
# here instead - the permission-union suite documents the same per-job rule.
test_permissions_are_declared_per_job_as_maps() {
  local file bad=""
  for file in "$WORKFLOWS_DIR"/*.yml; do
    if [ "$(yq '.on.workflow_call // "null"' "$file")" = "null" ]; then
      continue
    fi
    if [ "$(yq 'has("permissions")' "$file")" = "true" ]; then
      bad="${bad}  $(basename "$file"): permissions declared at the workflow level"$'\n'
    fi
    if [ "$(yq '[.jobs[] | select(has("permissions")) | .permissions | select(tag != "!!map")] | length' "$file")" != "0" ]; then
      bad="${bad}  $(basename "$file"): a job declares permissions that are not a map"$'\n'
    fi
  done
  fail_if_any "the catalog cannot read these permissions:" "$bad"
}

test_every_doc_link_of_the_catalog_resolves() {
  local link bad=""
  for link in $(grep -o '(\.\./\.\./\.\./docs/[^)]*)' "$CATALOG" | tr -d '()'); do
    if [ ! -f "$(dirname "$CATALOG")/$link" ]; then
      bad="${bad}  ${link}"$'\n'
    fi
  done
  fail_if_any "broken documentation links in the catalog:" "$bad"
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
  fail_if_any "skills whose frontmatter does not match:" "$bad"
}

# A skill must not send an agent to a workflow that was removed or renamed.
test_skills_only_call_workflows_that_exist() {
  local ref bad=""
  while IFS= read -r ref; do
    if [ ! -f "$WORKFLOWS_DIR/$(basename "$ref")" ]; then
      bad="${bad}  ${ref}"$'\n'
    fi
  done < <(grep -rhoE 'fabnum-cicd/\.github/workflows/[a-z0-9-]+\.yml' "$SKILLS_DIR" | sort -u)
  fail_if_any "skills call workflows that do not exist:" "$bad"
}

# The skills point an agent at the documentation with paths relative to their own
# file, which resolve once the plugin is installed (its root is this repository).
# A placeholder such as NN-<nom>.md is not a path.
test_relative_paths_in_the_skills_resolve() {
  local file dir path bad=""
  for file in "$SKILLS_DIR"/*/SKILL.md; do
    dir=$(dirname "$file")
    while IFS= read -r path; do
      case "$path" in *'<'*) continue ;; esac
      if [ ! -e "$dir/$path" ]; then
        bad="${bad}  $(basename "$dir"): $path"$'\n'
      fi
    done < <(grep -oE '\.\./[A-Za-z0-9_./<>-]*[A-Za-z0-9>/]' "$file" | sort -u)
  done
  fail_if_any "skills point at paths that do not exist:" "$bad"
}

# OpenCode installs skills from a URL by reading this index, and fetches only the
# files it lists: a file added to a skill but not listed is silently missing for
# those users.
test_the_url_index_lists_every_file_of_every_skill() {
  local expected actual
  expected=$(cd "$SKILLS_DIR" && find . -mindepth 2 -type f | sed 's|^\./||' | LC_ALL=C sort)
  actual=$(jq -r '.skills[] | .name as $n | .files[] | "\($n)/\(.)"' "$SKILLS_DIR/index.json" | LC_ALL=C sort)
  if [ "$expected" != "$actual" ]; then
    printf 'FAIL: skills/index.json does not list the files of the skills\n--- on disk ---\n%s\n--- in the index ---\n%s\n' \
      "$expected" "$actual" >&2
    exit 1
  fi
}

# The OpenCode plugin registers the skills with a path relative to its own file:
# moving either one would leave OpenCode without skills and without an error.
test_the_opencode_plugin_points_at_the_skills() {
  local main plugin_dir bad=""
  main=$(jq -r '.main' "$REPO_ROOT/package.json")
  if [ ! -f "$REPO_ROOT/$main" ]; then
    bad="  package.json main '$main' does not exist"$'\n'
  else
    plugin_dir=$(dirname "$REPO_ROOT/$main")
    if ! grep -qF '"../../skills"' "$REPO_ROOT/$main"; then
      bad="${bad}  $main no longer resolves the skills with \"../../skills\""$'\n'
    elif [ ! -f "$plugin_dir/../../skills/index.json" ]; then
      bad="${bad}  \"../../skills\" from $main is not the skills directory"$'\n'
    fi
  fi
  fail_if_any "the OpenCode plugin does not reach the skills:" "$bad"
}

run_tests
