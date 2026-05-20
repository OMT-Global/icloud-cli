#!/usr/bin/env bash
set -euo pipefail

module_cache="${CLANG_MODULE_CACHE_PATH:-$PWD/.build/module-cache}"
mkdir -p "$module_cache"
export CLANG_MODULE_CACHE_PATH="$module_cache"
export SWIFTPM_MODULECACHE_OVERRIDE="${SWIFTPM_MODULECACHE_OVERRIDE:-$module_cache}"

swift_args=()
if [[ -n "${SWIFT_FLAGS:-}" ]]; then
  read -r -a swift_args <<< "$SWIFT_FLAGS"
fi

run_swift_test() {
  if [[ "${#swift_args[@]}" -gt 0 ]]; then
    swift test "${swift_args[@]}"
  else
    swift test
  fi
}

mutation_file=""
backup_file=""

restore_mutation() {
  if [[ -n "$mutation_file" && -n "$backup_file" && -f "$backup_file" ]]; then
    cp "$backup_file" "$mutation_file"
  fi
  if [[ -n "$backup_file" && -f "$backup_file" ]]; then
    rm -f "$backup_file"
  fi
  mutation_file=""
  backup_file=""
}

trap restore_mutation EXIT

run_mutant() {
  local name="$1"
  local file="$2"
  local needle="$3"
  local replacement="$4"

  mutation_file="$file"
  backup_file="$(mktemp)"
  cp "$file" "$backup_file"

  NEEDLE="$needle" REPLACEMENT="$replacement" perl -0pi -e '
    BEGIN { $needle = $ENV{"NEEDLE"}; $replacement = $ENV{"REPLACEMENT"}; }
    $count = s/\Q$needle\E/$replacement/;
    END { exit($count == 1 ? 0 : 2); }
  ' "$file"

  if run_swift_test >/tmp/icloud-cli-mutant.log 2>&1; then
    echo "Mutation survived: $name" >&2
    cat /tmp/icloud-cli-mutant.log >&2
    exit 1
  fi

  echo "Mutation killed: $name"
  restore_mutation
}

run_mutant \
  "drop-http-url-support" \
  "Sources/ICloudCLICore/SafariTabs.swift" \
  'return ["http", "https"].contains(scheme)' \
  'return ["https"].contains(scheme)'

run_mutant \
  "drop-tab-title-text-rendering" \
  "Sources/ICloudCLICore/CommandRunner.swift" \
  'if let title = tab.title {' \
  'if false, let title = tab.title {'

run_mutant \
  "wrong-missing-cloud-tabs-failure-mode" \
  "Sources/ICloudCLICore/CloudTabs.swift" \
  'return "cloud-tabs-store-missing"' \
  'return "cloud-tabs-store-unreadable"'

run_mutant \
  "disable-help-shortcut" \
  "Sources/ICloudCLICore/CommandLine.swift" \
  'if tokens.isEmpty || tokens.contains("--help") || tokens.contains("-h") {' \
  'if tokens.isEmpty {'
