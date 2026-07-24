# Crawl budgets and partial results

Recursive local crawls must declare both a traversal budget and a wall-clock budget. The defaults are intentionally finite: interactive Drive and Finder-tag commands scan at most 5,000 files for at most 10 seconds, while default polling scans at most 2,000 files for at most 8 seconds per provider.

Affected commands accept `--scan-limit N` and `--timeout-ms N`. `--limit N` remains the number of matching results returned; it is not a traversal budget. Narrowing `--path` is usually safer than increasing either budget.

Drive list/status/errors/shared/recents and Finder tag item searches emit `icloud-cli.crawl.v1` reports containing:

- `state`: `complete`, `partial`, or `timeout`.
- `scannedCount`, `scanLimit`, and `wallClockLimitMilliseconds`.
- `resultCount` and an optional independent `resultLimit`.
- `totalAvailable` only when a complete crawl proves the total.
- `elapsedMilliseconds` and redacted `nextAction` guidance.
- `data`, containing the command's normal result payload.

`watch --once` applies one explicit budget to each selected provider. A partial or timed-out provider writes a redacted failure envelope and does not prevent later providers from refreshing. Previous successful cached data is retained when available; source paths and payload values are not copied into the failure text.

The privacy-preserving live audit passes explicit budgets to recursive commands and finishes with aggregate pass, empty, fail, and timeout counts. It never prints command payloads.
