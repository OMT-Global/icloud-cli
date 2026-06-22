#!/usr/bin/env bash
set -euo pipefail

fast_script="${1:-scripts/ci/run-fast-checks.sh}"
workflow="${2:-.github/workflows/pr-fast-ci.yml}"

failed=0

require_file() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "Required CI file is missing: $file" >&2
    failed=1
  fi
}

require_line() {
  local file="$1"
  local expected="$2"
  if ! grep -F -x "$expected" "$file" >/dev/null 2>&1; then
    echo "CI policy missing exact line in $file: $expected" >&2
    failed=1
  fi
}

require_contains() {
  local file="$1"
  local expected="$2"
  if ! grep -F "$expected" "$file" >/dev/null 2>&1; then
    echo "CI policy missing text in $file: $expected" >&2
    failed=1
  fi
}

require_file "$fast_script"
require_file "$workflow"

if [[ -f "$fast_script" ]]; then
  require_line "$fast_script" "bash scripts/ci/check-ci-policy.sh"
  require_line "$fast_script" "bash scripts/ci/check-shell-syntax.sh"
  require_line "$fast_script" "bash scripts/check-detect-secrets.sh --all-files"
  require_line "$fast_script" "bash scripts/check-privacy-fixtures.sh"
  require_line "$fast_script" "swift test"
  require_line "$fast_script" "bash scripts/ci/test-coverage-indicators.sh"
  require_line "$fast_script" "swift build"
  require_line "$fast_script" "swift build -c release"
  require_line "$fast_script" "swift run icloud-cli --help"
fi

if [[ -f "$workflow" ]]; then
  require_line "$workflow" "    types: [opened, synchronize, reopened, ready_for_review, edited]"
  require_line "$workflow" "      - macos-15"
  require_contains "$workflow" "bash scripts/ci/run-fast-checks.sh"
fi

exit "$failed"
