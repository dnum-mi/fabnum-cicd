#!/usr/bin/env bash
# Runs every suite in this directory, side by side. Requires bash >= 4 (mapfile,
# associative reads) and yq >= 4, both present on the GitHub-hosted runners.
#
# The suites share nothing - each builds its own sandbox under mktemp - so they
# run TEST_JOBS at a time (default: one per CPU). A suite's output is held until
# it ends and printed in suite order, so a failure is never interleaved with its
# neighbours' lines.

set -uo pipefail

TESTS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

if ! command -v yq >/dev/null 2>&1; then
  echo "yq is required to run these tests (https://github.com/mikefarah/yq)" >&2
  exit 1
fi

if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
  echo "bash >= 4 is required (found $BASH_VERSION); on macOS run these with a Homebrew bash" >&2
  exit 1
fi

JOBS="${TEST_JOBS:-$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)}"
RESULTS=$(mktemp -d)
trap 'rm -rf "$RESULTS"' EXIT
export RESULTS

run_suite() {
  local name
  name=$(basename "$1")
  bash "$1" >"$RESULTS/$name.out" 2>&1
  echo $? >"$RESULTS/$name.status"
}
export -f run_suite

# Largest first: a suite's size tracks its run time well enough, and the longest
# one starting last would leave every other worker idle behind it.
# shellcheck disable=SC2012,SC2016 # suite names are plain, ls -S is the portable size sort, and $0 is for the child shell to expand
ls -S "$TESTS_DIR"/*.test.sh | tr '\n' '\0' | xargs -0 -n1 -P "$JOBS" bash -c 'run_suite "$0"'

failed=0
for suite in "$TESTS_DIR"/*.test.sh; do
  name=$(basename "$suite")
  cat "$RESULTS/$name.out"
  # A suite that never reported, its worker having been killed, counts as failed.
  if [ "$(cat "$RESULTS/$name.status" 2>/dev/null)" != 0 ]; then
    failed=1
  fi
done

echo
if [ "$failed" -ne 0 ]; then
  echo "FAILED"
  exit 1
fi

echo "All suites passed"
