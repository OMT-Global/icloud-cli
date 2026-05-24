#!/usr/bin/env bash
set -euo pipefail

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

bash scripts/ci/report-coverage-indicators.sh "$coverage_json" "$PWD/Sources/ICloudCLICore/"
