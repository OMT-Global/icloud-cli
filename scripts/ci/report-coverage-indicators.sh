#!/usr/bin/env bash
set -euo pipefail

coverage_json="${1:?usage: report-coverage-indicators.sh COVERAGE_JSON [SOURCE_PREFIX]}"
source_prefix="${2:-$PWD/Sources/ICloudCLICore/}"
minimum_line_coverage="${COVERAGE_MIN_LINES:-68}"
crap_indicator_limit="${CRAP_INDICATOR_LIMIT:-5}"
crap_max_coverage="${CRAP_MAX_COVERAGE:-80}"
crap_min_file_lines="${CRAP_MIN_FILE_LINES:-10}"
crap_min_function_lines="${CRAP_MIN_FUNCTION_LINES:-8}"

source_line_coverage="$(
  jq -r --arg prefix "$source_prefix" '
    [.data[0].files[]
      | select(.filename | startswith($prefix))
      | .summary.lines]
    | {count: (map(.count // 0) | add // 0), covered: (map(.covered // 0) | add // 0)}
    | if .count == 0 then 0 else (.covered * 100 / .count) end
  ' "$coverage_json"
)"

printf 'Source line coverage: %.2f%% (minimum %.2f%%)\n' "$source_line_coverage" "$minimum_line_coverage"

printf 'CRAP indicators (coverage-driven; llvm-cov JSON does not include cyclomatic complexity):\n'
crap_indicators="$(
  jq -r \
    --arg prefix "$source_prefix" \
    --argjson limit "$crap_indicator_limit" \
    --argjson max_coverage "$crap_max_coverage" \
    --argjson min_file_lines "$crap_min_file_lines" \
    --argjson min_function_lines "$crap_min_function_lines" '
    def pct($covered; $count):
      if ($count | tonumber) == 0 then 0 else (($covered | tonumber) * 100 / ($count | tonumber)) end;
    def line_summary:
      .summary.lines as $lines
      | {
          count: ($lines.count // 0),
          covered: ($lines.covered // 0),
          pct: pct(($lines.covered // 0); ($lines.count // 0))
        };

    (
      [.data[0].files[]
        | select(.filename | startswith($prefix))
        | line_summary as $lines
        | select($lines.count >= $min_file_lines and $lines.pct < $max_coverage)
        | {
            kind: "file",
            name: (.filename | ltrimstr($prefix)),
            pct: $lines.pct,
            covered: $lines.covered,
            count: $lines.count
          }]
      +
      [.data[0].files[]
        | select(.filename | startswith($prefix))
        | .filename as $filename
        | (.functions // [])[]
        | line_summary as $lines
        | select($lines.count >= $min_function_lines and $lines.pct < $max_coverage)
        | {
            kind: "function",
            name: (($filename | ltrimstr($prefix)) + "::" + (.name // "<anonymous>")),
            pct: $lines.pct,
            covered: $lines.covered,
            count: $lines.count
          }]
    )
    | sort_by(.pct, (.count * -1), .name)
    | .[:$limit]
    | .[]
    | [.kind, .name, .pct, .covered, .count]
    | @tsv
  ' "$coverage_json" \
    | awk -F '\t' '
      $1 == "file" {
        printf "- %s: %.2f%% line coverage (%s/%s)\n", $2, $3, $4, $5
      }
      $1 == "function" {
        printf "- %s: %.2f%% function line coverage (%s/%s)\n", $2, $3, $4, $5
      }
    '
)"

if [[ -z "$crap_indicators" ]]; then
  echo "- none below ${crap_max_coverage}% coverage with current size thresholds"
else
  echo "$crap_indicators"
fi

awk -v actual="$source_line_coverage" -v minimum="$minimum_line_coverage" '
  BEGIN {
    if (actual + 0 < minimum + 0) {
      exit 1
    }
  }
'
