#!/usr/bin/env bash
# clean-images.yml - 'Delete ${{ inputs.IMAGE }} image'

# shellcheck source=ci/tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# shellcheck disable=SC2016 # the Actions marker is meant to stay literal
BLOCK=$(extract_run clean-images.yml cleanup-image 'Delete ${{ inputs.IMAGE }} image')

image_env() {
  export GH_TOKEN="github-token"
  export OWNER="owner"
  export PROTECTED_TAGS="latest,main,develop"
  export IMAGE="ghcr.io/owner/my-app/server:pr-83"
  export STUB_GH_PACKAGE_VERSIONS_JSON='[
    {"id": 4, "name": "sha256:ddd", "metadata": {"container": {"tags": ["pr-83", "9e681f1", "feat/some-branch"]}}}
  ]'
}

test_deletes_a_version_carrying_only_ephemeral_tags() {
  image_env

  run_block "$BLOCK"

  assert_status 0
  assert_called "versions/4"
  assert_output_contains "Image deletion completed"
}

test_refuses_a_version_that_also_carries_a_release_tag() {
  image_env
  # Same digest reached by a pull request tag and a release tag. Deleting by
  # the pull request tag would take the release down with it, since a version
  # carries every tag ever pushed to that digest.
  export STUB_GH_PACKAGE_VERSIONS_JSON='[
    {"id": 4, "name": "sha256:ddd", "metadata": {"container": {"tags": ["pr-83", "0.2.0"]}}}
  ]'

  run_block "$BLOCK"

  assert_status 0 "refusing is a normal outcome, not a job failure"
  assert_output_contains "Refusing to delete"
  assert_output_contains "0.2.0"
  assert_not_called "api --method DELETE"
}

test_refuses_a_version_that_also_carries_a_prerelease_tag() {
  image_env
  export STUB_GH_PACKAGE_VERSIONS_JSON='[
    {"id": 4, "name": "sha256:ddd", "metadata": {"container": {"tags": ["pr-83", "0.2.0-rc.4"]}}}
  ]'

  run_block "$BLOCK"

  assert_status 0
  assert_output_contains "Refusing to delete"
  assert_not_called "api --method DELETE"
}

test_refuses_a_version_that_also_carries_a_protected_moving_tag() {
  image_env
  export STUB_GH_PACKAGE_VERSIONS_JSON='[
    {"id": 4, "name": "sha256:ddd", "metadata": {"container": {"tags": ["pr-83", "latest"]}}}
  ]'

  run_block "$BLOCK"

  assert_status 0
  assert_output_contains "Refusing to delete"
  assert_not_called "api --method DELETE"
}

test_honours_a_custom_protected_tag_list() {
  image_env
  export PROTECTED_TAGS="stable"
  export STUB_GH_PACKAGE_VERSIONS_JSON='[
    {"id": 4, "name": "sha256:ddd", "metadata": {"container": {"tags": ["pr-83", "stable"]}}}
  ]'

  run_block "$BLOCK"

  assert_status 0
  assert_output_contains "Refusing to delete"
  assert_not_called "api --method DELETE"
}

test_a_branch_name_tag_does_not_protect_a_version() {
  image_env
  # 'feat/some-branch' is as spent as the pull request tag once the branch is
  # gone; only version-like and explicitly protected tags hold a version.
  run_block "$BLOCK"

  assert_status 0
  assert_called "versions/4"
}

test_reports_a_missing_tag_without_failing() {
  image_env
  export STUB_GH_PACKAGE_VERSIONS_JSON='[]'

  run_block "$BLOCK"

  assert_status 0 "an already-deleted image is a normal outcome"
  assert_output_contains "not found"
  assert_not_called "api --method DELETE"
}

test_deletes_platform_children_before_their_parent() {
  image_env
  export STUB_GH_PACKAGE_VERSIONS_JSON='[
    {"id": 4, "name": "sha256:ddd", "metadata": {"container": {"tags": ["pr-83"]}}},
    {"id": 6, "name": "sha256:fff", "metadata": {"container": {"tags": []}}}
  ]'
  export STUB_DOCKER_MANIFEST_JSON='{"manifests": [{"digest": "sha256:fff"}]}'

  run_block "$BLOCK"

  assert_status 0
  # The children are untagged, so once the manifest list referencing them is
  # gone nothing can find them again - they must go first.
  assert_called "versions/6"
  assert_called_before "versions/6" "versions/4"
}

test_fails_when_image_carries_no_tag() {
  image_env
  # CLEAN_ORPHANED callers pass the package name alone, so an untagged IMAGE
  # reaching this job is a miswired call. Without the guard the expansion
  # leaves the tag equal to the name, nothing matches, and the job reports
  # "not found" and exits 0 - a green run that deleted nothing.
  export IMAGE="ghcr.io/owner/my-app/server"

  run_block "$BLOCK"

  assert_status 1 "a silent no-op would be indistinguishable from a real cleanup"
  assert_output_contains "must include a tag"
  assert_not_called "api --method DELETE"
}

run_tests
