#!/usr/bin/env bash
# build-docker.yml - OCI labels and manifest list annotations
#
# source / revision / version are what lets a consumer of the image - a
# registry UI, a scanner, a cluster-side inventory - tie a running tag back to
# the repository and commit it came from. The labels sit in each platform
# image's config, the annotations on the manifest list; a client reading only
# one of the two must still find all three keys.

# shellcheck source=ci/tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

BLOCK=$(extract_run build-docker.yml merge "Create manifest list and push")

LABELS_INPUT=$(yq '
  .jobs.build.steps[]
  | select(.name == "Build docker image")
  | .with.labels
' "$WORKFLOWS_DIR/build-docker.yml")

merge_env() {
  export NORMALIZED_IMAGE="ghcr.io/my-org/my-image"
  export OCI_LABELS="true"
  export OCI_SOURCE="https://github.com/my-org/my-repo"
  export OCI_REVISION="0123456789abcdef0123456789abcdef01234567"
  export OCI_VERSION="1.2.3"
  export DOCKER_METADATA_OUTPUT_JSON='{"tags":["ghcr.io/my-org/my-image:1.2.3"]}'
  mkdir -p "$SANDBOX/digests"
  touch "$SANDBOX/digests/aaaa"
  cd "$SANDBOX/digests" || exit 1
}

test_manifest_list_carries_the_three_annotations() {
  merge_env

  run_block "$BLOCK"

  assert_status 0
  assert_called "--annotation index:org.opencontainers.image.source=https://github.com/my-org/my-repo"
  assert_called "--annotation index:org.opencontainers.image.revision=0123456789abcdef0123456789abcdef01234567"
  assert_called "--annotation index:org.opencontainers.image.version=1.2.3"
  assert_called "-t ghcr.io/my-org/my-image:1.2.3 ghcr.io/my-org/my-image@sha256:aaaa"
}

test_no_annotation_when_disabled() {
  merge_env
  export OCI_LABELS="false"

  run_block "$BLOCK"

  assert_status 0
  assert_not_called "--annotation"
  # Disabling the metadata must not cost the push itself.
  assert_called "buildx imagetools create -t ghcr.io/my-org/my-image:1.2.3"
}

test_build_step_sets_the_three_labels() {
  for key in source revision version; do
    if [[ "$LABELS_INPUT" != *"org.opencontainers.image.$key="* ]]; then
      printf 'FAIL: build step labels miss org.opencontainers.image.%s\n%s\n' "$key" "$LABELS_INPUT" >&2
      exit 1
    fi
  done
}

test_caller_labels_come_last_so_they_can_override() {
  # On a duplicate key the last --label wins: LABELS must follow the defaults.
  local last
  last=$(printf '%s\n' "$LABELS_INPUT" | grep -v '^\s*$' | tail -1)
  if [[ "$last" != *'inputs.LABELS'* ]]; then
    printf 'FAIL: inputs.LABELS is not the last labels entry (got %q)\n' "$last" >&2
    exit 1
  fi
}

run_tests
