# Issue work result

## Selected issues

- Closes #20
- Closes #36

## Summary

Added Safari bookmarks, reading list, and frequently visited site inventory commands backed by synthetic plist fixtures. Safari history (#25) remains out of scope because it needs a stronger explicit opt-in/redaction design before implementation.

## Files changed

- `Sources/ICloudCLICore/CommandLine.swift`
- `Sources/ICloudCLICore/CommandRunner.swift`
- `Sources/ICloudCLICore/SafariBookmarks.swift`
- `Sources/ICloudCLICore/SafariFrequentlyVisited.swift`
- `Tests/ICloudCLICoreTests/CLIParserTests.swift`
- `Tests/ICloudCLICoreTests/SafariBookmarksReaderTests.swift`
- `Tests/Fixtures/Safari/Bookmarks.plist`
- `Tests/Fixtures/Safari/TopSites.plist`
- `README.md`
- `docs/privacy.md`
- `docs/issue-work-plan.md`
- `scripts/check-privacy-fixtures.sh`

## Validation

Passed locally on macOS/Hermes:

```sh
bash scripts/ci/run-fast-checks.sh
swift test
swift build
bash scripts/check-privacy-fixtures.sh
.build/debug/icloud-cli safari bookmarks --safari-dir Tests/Fixtures/Safari --format json
.build/debug/icloud-cli safari reading-list --safari-dir Tests/Fixtures/Safari --format text
.build/debug/icloud-cli safari frequently-visited --safari-dir Tests/Fixtures/Safari --limit 2 --format text
```

## PR suggestion

Title: `feat: add Safari bookmarks and frequently visited commands`

Body:

```md
## Summary
- add `icloud-cli safari bookmarks`
- add `icloud-cli safari reading-list`
- add `icloud-cli safari frequently-visited`
- document the selected issue group and privacy posture

Closes #20
Closes #36

## Validation
- `bash scripts/ci/run-fast-checks.sh`
- `swift test`
- `swift build`
- `bash scripts/check-privacy-fixtures.sh`
- CLI smoke checks against synthetic Safari fixtures
```
