#!/usr/bin/env bash
# build-docker.yml - 'Create manifest list and push'
#
# Annotations are attached to the manifest list once, at 'imagetools create'
# time in the merge job, rather than per architecture at build time - see
# build-docker.yml for why. Their values come off the same metadata-action run
# as the image labels, in the 'infos' job, so both carry one
# org.opencontainers.image.created. This covers the arg-building: each line of
# DOCKER_ANNOTATIONS becomes its own '--annotation' flag, and an empty value
# contributes no flags at all rather than a stray '--annotation ""'.

# shellcheck source=ci/tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

WORKFLOW="$WORKFLOWS_DIR/build-docker.yml"
META_STEP="Docker meta (labels and annotations)"

BLOCK=$(extract_run build-docker.yml merge "Create manifest list and push")

manifest_env() {
  export NORMALIZED_IMAGE="ghcr.io/acme/app"
  export DOCKER_METADATA_OUTPUT_JSON='{"tags":["ghcr.io/acme/app:1.2.3"]}'
}

# One digest file per architecture, named the way the 'Export digest' step
# writes them (the sha256 hex, no 'sha256:' prefix) - the block turns each
# into a '<image>@sha256:<digest>' reference. Mirrors working-directory:
# by cd-ing the test itself into the fixture digests dir.
write_digest_files() {
  mkdir -p "$SANDBOX/digests"
  cd "$SANDBOX/digests" || exit 1
  touch "$@"
}

# The format string is the caller's so a failure can print a value with %q,
# where the exact bytes are the point.
# shellcheck disable=SC2059
fail() {
  printf "FAIL: $1\n" "${@:2}" >&2
  exit 1
}

test_passes_each_annotation_line_as_its_own_flag() {
  manifest_env
  export DOCKER_ANNOTATIONS=$'index:org.opencontainers.image.revision=abc123\nindex:org.opencontainers.image.version=1.2.3'
  write_digest_files "deadbeef"

  run_block "$BLOCK"

  assert_status 0
  assert_called 'docker|buildx imagetools create -t ghcr.io/acme/app:1.2.3 --annotation index:org.opencontainers.image.revision=abc123 --annotation index:org.opencontainers.image.version=1.2.3 ghcr.io/acme/app@sha256:deadbeef'
}

test_omits_annotation_flags_when_none_are_set() {
  manifest_env
  export DOCKER_ANNOTATIONS=""
  write_digest_files "deadbeef"

  run_block "$BLOCK"

  assert_status 0
  assert_not_called "--annotation"
  # Nothing to annotate must not cost the push itself - an empty source has to
  # leave the loop's exit status alone under the runner's `bash -e`.
  assert_called 'docker|buildx imagetools create -t ghcr.io/acme/app:1.2.3 ghcr.io/acme/app@sha256:deadbeef'
}

# Labels and annotations are the same values, so they have to be one
# metadata-action run: a second one takes its own clock reading for
# org.opencontainers.image.created, and the index ends up disagreeing with the
# images underneath it about when they were built.
test_labels_and_annotations_come_from_one_metadata_run() {
  local producers levels
  producers=$(yq '[.jobs.*.steps[] | select(.with.annotations) | .name] | join(", ")' "$WORKFLOW")
  [ "$producers" = "$META_STEP" ] \
    || fail 'the annotations must come from the one run that also produces the labels (producers: %s)' "$producers"

  [ "$(yq ".jobs.infos.steps[] | select(.name == \"$META_STEP\") | .with | has(\"labels\")" "$WORKFLOW")" = "true" ] \
    || fail 'that run no longer produces the labels, so the two sets are back on separate clocks'

  # imagetools create rejects manifest-level annotations, so the level the run
  # emits is load-bearing, not cosmetic.
  levels=$(yq ".jobs.infos.steps[] | select(.name == \"$META_STEP\") | .env.DOCKER_METADATA_ANNOTATIONS_LEVELS" "$WORKFLOW")
  [ "$levels" = "index" ] \
    || fail 'annotations must be emitted at index level for imagetools create (got %q)' "$levels"
}

run_tests
