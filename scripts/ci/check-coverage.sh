#!/usr/bin/env bash
set -euo pipefail

minimum_line_coverage="${COVERAGE_MIN_LINES:-68}"
module_cache="${CLANG_MODULE_CACHE_PATH:-$PWD/.build/module-cache}"
mkdir -p "$module_cache"
export CLANG_MODULE_CACHE_PATH="$module_cache"
export SWIFTPM_MODULECACHE_OVERRIDE="${SWIFTPM_MODULECACHE_OVERRIDE:-$module_cache}"

swift_args=()
if [[ -n "${SWIFT_FLAGS:-}" ]]; then
  # Intentional word splitting lets callers pass SwiftPM flags such as
  # SWIFT_FLAGS="--disable-sandbox --scratch-path /tmp/icloud-cli-build".
  read -r -a swift_args <<< "$SWIFT_FLAGS"
fi

if [[ "${#swift_args[@]}" -gt 0 ]]; then
  swift test "${swift_args[@]}" --enable-code-coverage
  coverage_json="$(swift test "${swift_args[@]}" --show-codecov-path)"
else
  swift test --enable-code-coverage
  coverage_json="$(swift test --show-codecov-path)"
fi

source_line_coverage="$(
  jq -r --arg prefix "$PWD/Sources/ICloudCLICore/" '
    [.data[0].files[]
      | select(.filename | startswith($prefix))
      | .summary.lines]
    | {count: (map(.count) | add), covered: (map(.covered) | add)}
    | (.covered * 100 / .count)
  ' "$coverage_json"
)"

printf 'Source line coverage: %.2f%% (minimum %.2f%%)\n' "$source_line_coverage" "$minimum_line_coverage"

awk -v actual="$source_line_coverage" -v minimum="$minimum_line_coverage" '
  BEGIN {
    if (actual + 0 < minimum + 0) {
      exit 1
    }
  }
'
