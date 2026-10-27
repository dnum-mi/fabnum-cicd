#!/usr/bin/env bash
# lint-commits.yml - the commitlint config it generates
#
# The config is written into the caller's checked-out repository, so how Node
# loads it depends on the caller's package.json. A repository declaring
# "type": "module" loads a `commitlint.config.js` as an ES module, where the
# CommonJS `module.exports` the workflow writes fails with "module is not
# defined in ES module scope" - and takes every pull request's commit lint down
# with it. A `.cjs` file is CommonJS whatever the package says, and an explicit
# --config keeps commitlint's own lookup (which prefers a checked-in `.js`)
# from picking some other file over the one carrying the workflow's inputs.

# shellcheck source=ci/tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Runs the generation step inside a workspace whose package.json is $1, and
# leaves the workspace path in WORKSPACE.
generate_config_in_workspace() {
  local package_json="$1" block

  WORKSPACE="$SANDBOX/workspace"
  mkdir -p "$WORKSPACE"
  printf '%s\n' "$package_json" >"$WORKSPACE/package.json"

  block=$(extract_run lint-commits.yml lint-commits "Create commitlint config")
  run_block "cd \"$WORKSPACE\" && $block"
  assert_status 0 "generating the config"
}

# What commitlint would read out of the file the step wrote, loaded the way Node
# loads it for this workspace: a `.js` follows the package.json's "type", a
# `.cjs` is always CommonJS.
load_generated_config() {
  local file
  file=$(find "$WORKSPACE" -maxdepth 1 -name 'commitlint.config.*' -exec basename {} \; | head -1)
  (cd "$WORKSPACE" && node --input-type=module -e "
    const loaded = await import('./$file');
    console.log(JSON.stringify(loaded.default));
  ")
}

# The two loading tests below are sanity checks: recent Node releases tolerate
# CommonJS syntax in a `.js` of a module package, where the Node 22 of the
# hosted runners does not (and bun does not either). What pins the regression on
# every runtime is the file name and the explicit --config further down.
test_the_config_loads_in_a_module_package() {
  export COMMITLINT_ALLOWED_TYPES="feat,fix" COMMITLINT_REQUIRE_SCOPE=false COMMITLINT_MAX_SUBJECT_LENGTH=72
  generate_config_in_workspace '{"name":"caller","type":"module"}'

  local loaded
  if ! loaded=$(load_generated_config 2>&1); then
    printf 'FAIL: the generated config does not load in a "type": "module" package:\n%s\n' "$loaded" >&2
    exit 1
  fi
}

test_the_config_loads_in_a_typeless_package() {
  export COMMITLINT_ALLOWED_TYPES="feat,fix" COMMITLINT_REQUIRE_SCOPE=false COMMITLINT_MAX_SUBJECT_LENGTH=72
  generate_config_in_workspace '{"name":"caller"}'

  local loaded
  if ! loaded=$(load_generated_config 2>&1); then
    printf 'FAIL: the generated config does not load in a typeless package:\n%s\n' "$loaded" >&2
    exit 1
  fi
}

test_the_inputs_reach_the_rules() {
  export COMMITLINT_ALLOWED_TYPES="feat, fix ,docs" COMMITLINT_REQUIRE_SCOPE=true COMMITLINT_MAX_SUBJECT_LENGTH=72
  generate_config_in_workspace '{"name":"caller","type":"module"}'

  local rules
  rules=$(load_generated_config | yq -p=json -o=json -I=0 '.rules')

  if [ "$rules" != '{"type-enum":[2,"always",["feat","fix","docs"]],"scope-empty":[2,"never"],"header-max-length":[2,"always",72]}' ]; then
    printf 'FAIL: the inputs did not become the rules:\n%s\n' "$rules" >&2
    exit 1
  fi
}

test_the_generated_file_is_not_a_dot_js() {
  export COMMITLINT_ALLOWED_TYPES="feat" COMMITLINT_REQUIRE_SCOPE=false COMMITLINT_MAX_SUBJECT_LENGTH=100
  generate_config_in_workspace '{"name":"caller","type":"module"}'

  # A .js would be parsed per the caller's package.json, which is the bug; and
  # would overwrite a checked-in commitlint.config.js of theirs besides.
  if [ -e "$WORKSPACE/commitlint.config.js" ]; then
    printf 'FAIL: the step wrote commitlint.config.js into the caller workspace\n' >&2
    exit 1
  fi
  if [ ! -e "$WORKSPACE/commitlint.config.cjs" ]; then
    printf 'FAIL: the step did not write commitlint.config.cjs\n' >&2
    exit 1
  fi
}

# The lint step with git and bunx replaced: git hands it one commit, and bunx
# records the arguments commitlint would have been given.
run_lint_step() {
  local config_file="$1" block

  cat >"$SANDBOX/bin/git" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *"--pretty=format:%H"*) echo "0123456789abcdef0123456789abcdef01234567" ;;
  *"--format=%s"*) echo "fix(ci): something" ;;
esac
EOF
  cat >"$SANDBOX/bin/bunx" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
echo "bunx $*" >>"$CALL_LOG"
EOF
  chmod +x "$SANDBOX/bin/git" "$SANDBOX/bin/bunx"

  export PATH="$SANDBOX/bin:$PATH"
  export GITHUB_STEP_SUMMARY="$SANDBOX/summary.md"
  export CONFIG_FILE="$config_file" COMMIT_RANGE="a..b" ALLOWED_TYPES="feat,fix" FAIL_ON_ERROR=true

  block=$(extract_run lint-commits.yml lint-commits "Lint commits")
  run_block "$block"
  assert_status 0 "the lint step"
}

test_the_generated_config_is_passed_explicitly() {
  run_lint_step ""

  assert_called "bunx commitlint --config commitlint.config.cjs"
}

test_a_caller_config_file_wins() {
  : >"$SANDBOX/custom.config.js"
  run_lint_step "$SANDBOX/custom.config.js"

  assert_called "bunx commitlint --config $SANDBOX/custom.config.js"
  assert_not_called "commitlint.config.cjs"
}

run_tests
