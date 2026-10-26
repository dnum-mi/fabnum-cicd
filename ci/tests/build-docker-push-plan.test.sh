#!/usr/bin/env bash
# build-docker.yml - 'Plan the push'
#
# A merge job exists to put one tag on the images two runners built apart. A
# build that is a single job has nothing to merge, and pushes its own tags
# instead. Which of the two a run takes decides whether it spends a runner, an
# artifact round trip and a second registry login, and whether the digest it
# reports is the one it pushed - so the split has to be exact in both
# directions: no merge where there is nothing to merge, and none missing where
# two jobs would each leave an untagged image behind.

# shellcheck source=ci/tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

BLOCK=$(extract_run build-docker.yml infos 'Plan the push')

plan() {
  export PUSH="$1" BUILD_AMD64="$2" BUILD_ARM64="$3" USE_QEMU="$4"
  run_block "$BLOCK"
  assert_status 0
}

assert_plan() {
  assert_file_contains "$GITHUB_OUTPUT" "DIRECT_PUSH=$1"
  assert_file_contains "$GITHUB_OUTPUT" "NEEDS_MERGE=$2"
}

test_a_build_that_does_not_push_needs_neither() {
  plan false true true false

  assert_plan false false
}

test_a_lone_amd64_build_pushes_its_own_tags() {
  plan true true false false

  assert_plan true false
}

test_a_lone_arm64_build_pushes_its_own_tags() {
  plan true false true false

  assert_plan true false
}

test_both_architectures_on_native_runners_are_merged() {
  plan true true true false

  assert_plan false true
}

# One job builds both platforms and pushes the list itself, so a merge would
# only copy it under the same tags.
test_both_architectures_through_qemu_are_one_job() {
  plan true true true true

  assert_plan true false
}

test_a_lone_architecture_through_qemu_is_one_job() {
  plan true false true true

  assert_plan true false
}

run_tests
