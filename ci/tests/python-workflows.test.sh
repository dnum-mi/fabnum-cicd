#!/usr/bin/env bash
# test-python.yml - 'Validate inputs': IMPORT_NAME is spliced into a `python -c`,
# so anything but a dotted module name is refused rather than escaped.
# release-pypi.yml - 'Name the artifact': one workflow run can publish several
# packages, and artifact names must be unique within a run.

# shellcheck source=ci/tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

VALIDATE=$(extract_run test-python.yml test "Validate inputs")
ARTIFACT=$(extract_run release-pypi.yml build "Name the artifact")

test_accepts_a_module_name() {
  export IMPORT_NAME="my_package"

  run_block "$VALIDATE"

  assert_status 0
}

test_accepts_a_dotted_module_name() {
  export IMPORT_NAME="my_package.sub_module"

  run_block "$VALIDATE"

  assert_status 0
}

test_accepts_an_empty_name() {
  export IMPORT_NAME=""

  run_block "$VALIDATE"

  assert_status 0
}

test_rejects_a_command_separator() {
  export IMPORT_NAME="os; __import__('os').system('id')"

  run_block "$VALIDATE"

  assert_status 1
  assert_output_contains "IMPORT_NAME"
}

test_rejects_a_trailing_newline() {
  export IMPORT_NAME=$'my_package\nimport os'

  run_block "$VALIDATE"

  assert_status 1
}

test_rejects_a_leading_digit() {
  export IMPORT_NAME="1package"

  run_block "$VALIDATE"

  assert_status 1
}

test_artifact_name_is_derived_from_the_working_directory() {
  export WORKING_DIRECTORY="clients/python/my-sdk"

  run_block "$ARTIFACT"

  assert_status 0
  assert_file_contains "$GITHUB_OUTPUT" "name=python-dist-clients-python-my-sdk"
}

test_artifact_names_differ_between_packages() {
  export WORKING_DIRECTORY="sdk/worker"
  run_block "$ARTIFACT"
  local first
  first=$(cat "$GITHUB_OUTPUT")

  : >"$GITHUB_OUTPUT"
  export WORKING_DIRECTORY="sdk/client"
  run_block "$ARTIFACT"

  [ "$first" != "$(cat "$GITHUB_OUTPUT")" ] || {
    echo "both packages got the same artifact name: $first" >&2
    return 1
  }
}

run_tests
