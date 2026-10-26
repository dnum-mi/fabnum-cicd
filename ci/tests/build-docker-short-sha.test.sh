#!/usr/bin/env bash
# build-docker.yml - TAG_SHORT_SHA
#
# Every push is tagged with the short commit SHA, which is what a caller that
# deploys by commit pulls. A caller whose branches are rebased or force-pushed
# can rebuild unchanged image content on an unrelated commit, which reuses the
# previous digest: the new SHA is then one more tag on a version that is still
# live, and since only a whole version can be deleted, never a single tag, those
# tags pile up for as long as the branch stays alive. TAG_SHORT_SHA is how a
# caller opts in to the tag, and it defaults off here: the safer behaviour is
# the default, and a caller that wants the per-commit tag asks for it.

# shellcheck source=ci/tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

WORKFLOW="$WORKFLOWS_DIR/build-docker.yml"

# The tag lines of the one step that computes them for whichever job pushes.
tag_lines() {
  yq '.jobs.infos.steps[] | select(.name == "Docker tags") | .with.tags' "$WORKFLOW"
}

test_the_input_is_a_boolean_that_defaults_off() {
  local type default
  type=$(yq '.on.workflow_call.inputs.TAG_SHORT_SHA.type' "$WORKFLOW")
  default=$(yq '.on.workflow_call.inputs.TAG_SHORT_SHA.default' "$WORKFLOW")

  if [ "$type" != "boolean" ]; then
    printf 'FAIL: TAG_SHORT_SHA is %s, expected a boolean\n' "$type" >&2
    exit 1
  fi
  # Defaulting on would tag every build with the SHA again for a caller that
  # never asked for it, and those tags pile up.
  if [ "$default" != "false" ]; then
    printf 'FAIL: TAG_SHORT_SHA defaults to %s; the safe default is false\n' "$default" >&2
    exit 1
  fi
}

test_the_short_sha_tag_is_enabled_by_the_input() {
  local lines
  lines=$(tag_lines | grep -F 'steps.infos.outputs.SHORT_SHA' || true)

  if [ "$(printf '%s\n' "$lines" | grep -c .)" -ne 1 ]; then
    printf 'FAIL: expected one short-SHA tag line, found:\n%s\n' "$lines" >&2
    exit 1
  fi
  # shellcheck disable=SC2016 # the Actions marker is meant to stay literal
  if [[ "$lines" != *'enable=${{ inputs.TAG_SHORT_SHA && '* ]]; then
    printf 'FAIL: the short-SHA tag is not enabled by TAG_SHORT_SHA:\n%s\n' "$lines" >&2
    exit 1
  fi
}

# Still no tag without a SHA to name, whatever the input says.
test_the_short_sha_tag_still_needs_a_sha() {
  local lines
  lines=$(tag_lines | grep -F 'steps.infos.outputs.SHORT_SHA' || true)

  # shellcheck disable=SC2016 # the Actions marker is meant to stay literal
  if [[ "$lines" != *"steps.infos.outputs.SHORT_SHA != ''"* ]]; then
    printf 'FAIL: the short-SHA tag no longer checks that a SHA exists:\n%s\n' "$lines" >&2
    exit 1
  fi
}

# Only the short SHA depends on it: the other tags are not the input's to turn off.
test_no_other_tag_depends_on_the_input() {
  local others
  others=$(tag_lines | grep -F 'TAG_SHORT_SHA' | grep -vF 'steps.infos.outputs.SHORT_SHA' || true)

  if [ -n "$others" ]; then
    printf 'FAIL: a tag other than the short SHA depends on TAG_SHORT_SHA:\n%s\n' "$others" >&2
    exit 1
  fi
}

run_tests
