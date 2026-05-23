#!/usr/bin/env bash
set -euo pipefail

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

fixture="$tmpdir/coverage.json"
source_prefix="$tmpdir/Sources/ICloudCLICore/"
mkdir -p "$source_prefix"

cat >"$fixture" <<JSON
{
  "data": [
    {
      "files": [
        {
          "filename": "${source_prefix}Healthy.swift",
          "summary": {
            "lines": { "count": 100, "covered": 95 }
          },
          "functions": [
            {
              "name": "healthy()",
              "summary": {
                "lines": { "count": 24, "covered": 24 }
              }
            }
          ]
        },
        {
          "filename": "${source_prefix}Risky.swift",
          "summary": {
            "lines": { "count": 40, "covered": 10 }
          },
          "functions": [
            {
              "name": "riskyBranch()",
              "summary": {
                "lines": { "count": 20, "covered": 5 }
              }
            },
            {
              "name": "untouchedBranch()",
              "summary": {
                "lines": { "count": 12, "covered": 0 }
              }
            }
          ]
        }
      ]
    }
  ]
}
JSON

output="$(
  COVERAGE_MIN_LINES=70 CRAP_INDICATOR_LIMIT=4 \
    bash scripts/ci/report-coverage-indicators.sh "$fixture" "$source_prefix"
)"

grep -F "Source line coverage: 75.00% (minimum 70.00%)" <<<"$output" >/dev/null
grep -F "CRAP indicators" <<<"$output" >/dev/null
grep -F "Risky.swift: 25.00% line coverage (10/40)" <<<"$output" >/dev/null
grep -F "Risky.swift::untouchedBranch(): 0.00% function line coverage (0/12)" <<<"$output" >/dev/null

if COVERAGE_MIN_LINES=80 bash scripts/ci/report-coverage-indicators.sh "$fixture" "$source_prefix" >/tmp/icloud-cli-coverage-threshold.log 2>&1; then
  echo "Expected coverage threshold failure" >&2
  cat /tmp/icloud-cli-coverage-threshold.log >&2
  exit 1
fi

echo "Coverage indicator tests passed"
