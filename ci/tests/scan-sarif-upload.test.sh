#!/usr/bin/env bash
# scan-*.yml - the SARIF upload steps
#
# upload-sarif waits for GitHub to finish processing the file by default, about
# 5 of the step's 8 seconds and minutes when processing is slow. Every upload
# here is continue-on-error and the job is gated by the scanner's own exit code,
# so nothing reads what the wait would have reported. A new scan workflow, or an
# upload step added to one, would bring the wait back without anything failing.

# shellcheck source=ci/tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# scan-scorecard.yml keeps the wait on purpose: it runs on pushes to the default
# branch and weekly, so no pull request waits on it, and its "Link the results"
# step tells the reader the results are available once the upload succeeded -
# which only holds if success means processed.
KEEPS_THE_WAIT="scan-scorecard.yml"

# One line per upload-sarif step across the scan workflows:
# "<file> <wait-for-processing value>", `null` when the input is not set.
upload_steps() {
  local file
  for file in "$WORKFLOWS_DIR"/scan-*.yml; do
    [ "$(basename "$file")" = "$KEEPS_THE_WAIT" ] && continue
    yq -r '.jobs[].steps[]
      | select((.uses // "") | test("^github/codeql-action/upload-sarif@"))
      | .with["wait-for-processing"]' "$file" |
      sed "s|^|$(basename "$file") |"
  done
}

test_no_upload_waits_for_processing() {
  local steps
  steps=$(upload_steps)

  if [ -z "$steps" ]; then
    printf 'FAIL: found no upload-sarif step in the scan workflows; the check below would pass for nothing\n' >&2
    exit 1
  fi

  if grep -v ' false$' <<<"$steps" >/dev/null; then
    printf 'FAIL: an upload-sarif step does not set wait-for-processing: false\n%s\n' \
      "$(grep -v ' false$' <<<"$steps")" >&2
    exit 1
  fi
}

# The workflows that upload today, so removing one of the steps - and with it
# the coverage above - is a decision rather than an accident.
test_the_known_uploads_are_all_covered() {
  local steps file
  steps=$(upload_steps)

  for file in scan-trivy.yml scan-gitleaks.yml; do
    if ! grep -q "^$file " <<<"$steps"; then
      printf 'FAIL: %s no longer has an upload-sarif step\n' "$file" >&2
      exit 1
    fi
  done
}

run_tests
