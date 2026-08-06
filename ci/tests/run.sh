#!/usr/bin/env bash
# Runs every suite in this directory. Requires bash >= 4 (mapfile, associative
# reads) and yq >= 4, both present on the GitHub-hosted runners.

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

failed=0
for suite in "$TESTS_DIR"/*.test.sh; do
  bash "$suite" || failed=1
done

echo
if [ "$failed" -ne 0 ]; then
  echo "FAILED"
  exit 1
fi

echo "All suites passed"
