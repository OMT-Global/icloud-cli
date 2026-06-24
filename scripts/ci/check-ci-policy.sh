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

job_block() {
  local file="$1"
  local job="$2"
  awk -v job="  ${job}:" '
    $0 == job { in_job = 1; print; next }
    in_job && $0 ~ /^  [A-Za-z0-9_-]+:/ { exit }
    in_job { print }
  ' "$file"
}

require_job_line() {
  local file="$1"
  local job="$2"
  local expected="$3"
  if ! job_block "$file" "$job" | grep -F -x "$expected" >/dev/null 2>&1; then
    echo "CI policy missing exact line in $workflow job $job: $expected" >&2
    failed=1
  fi
}

reject_job_contains() {
  local file="$1"
  local job="$2"
  local rejected="$3"
  if job_block "$file" "$job" | grep -F "$rejected" >/dev/null 2>&1; then
    echo "CI policy rejected text in $workflow job $job: $rejected" >&2
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
  require_job_line "$workflow" "pr-ci-gate" "    name: PR Checks"
  require_job_line "$workflow" "pr-ci-gate" "    if: github.event_name == 'pull_request'"
  require_job_line "$workflow" "pr-ci-gate" "      - macos-15"
  reject_job_contains "$workflow" "pr-ci-gate" "self-hosted"
  require_job_line "$workflow" "ci-gate" "    name: CI Gate"
  require_job_line "$workflow" "ci-gate" "    if: always()"
  require_contains "$workflow" "bash scripts/ci/run-fast-checks.sh"
fi

exit "$failed"
