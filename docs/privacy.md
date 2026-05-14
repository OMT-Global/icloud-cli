# Privacy And Permissions Model

`icloud-cli` reads Apple state from the local Mac. The default posture is local-only, read-only, and explicit: commands should report what they read, avoid hidden export paths, and redact data when output is meant for logs, issues, or OpenClaw telemetry.

## Sensitive Data Classes

The CLI may read or derive:

- Safari tab URLs and titles.
- Safari bookmark URLs/titles, Reading List URLs/titles, and frequently visited URLs/titles.
- Safari session file paths and read errors.
- Future Safari iCloud tab metadata from local sync stores such as `CloudTabs.db`.
- Future Apple account, iCloud settings, or device-sync metadata.
- Local macOS permission state, including Full Disk Access or Automation failures.

Treat all live tab URLs, browsing titles, account identifiers, local paths, and sync database contents as sensitive. Test fixtures must use synthetic examples only.

## Output And Redaction Defaults

Interactive command output may show the requested data because the operator asked for it directly. Anything intended for logs, issue reports, OpenClaw status, or automation summaries should use these defaults:

- Redact tab URLs to scheme plus host unless full export is explicitly requested.
- Redact tab titles by default in status/error summaries.
- Replace home-directory paths with `~/...`.
- Preserve enough error shape to identify the failing source class, for example readable empty session files versus unreadable session files.
- Never include live Safari plist contents, iCloud databases, auth state, caches, or session files in reports.

OpenClaw integrations should default to local retention. Exporting raw browsing data must be an explicit operator choice, not a side effect of polling.

## Command Permissions

| Command | Reads | macOS permission expectation |
| --- | --- | --- |
| `icloud-cli safari tabs` | `~/Library/Safari/CurrentSession.plist` and `~/Library/Safari/LastSession.plist` | Terminal or calling process may need Full Disk Access to read Safari session files. |
| `icloud-cli safari bookmarks` | `~/Library/Safari/Bookmarks.plist` bookmark entries | Terminal or calling process may need Full Disk Access to read Safari metadata files. |
| `icloud-cli safari reading-list` | `~/Library/Safari/Bookmarks.plist` Reading List entries | Terminal or calling process may need Full Disk Access to read Safari metadata files. |
| `icloud-cli safari frequently-visited` | `~/Library/Safari/TopSites.plist` or compatible frequently visited site cache | Terminal or calling process may need Full Disk Access to read Safari metadata files. |
| Future `icloud-cli safari tabs --include-cloud` | Safari iCloud sync storage, likely under `~/Library/Safari` | Full Disk Access is expected; schema and safety constraints must be documented before implementation. |
| Future iCloud settings commands | Local Apple account or system settings state | Document per-command read surfaces before implementation; do not require Automation unless a command actually controls an app. |

Automation permission is not required for the current Safari tab reader because it reads local files. Any future command that controls Safari, System Settings, or another app must document the Automation prompt and failure mode before merge.

## Fixtures And Tests

Fixtures must be synthetic. The fast gate runs `scripts/check-privacy-fixtures.sh`, which rejects fixture content containing local home paths, known live Safari database names, file URLs, or non-example web URLs. Use `example.com`, `example.org`, or `example.net` for tab fixtures.

The fast gate order is:

```sh
bash scripts/check-detect-secrets.sh --all-files
bash scripts/check-privacy-fixtures.sh
swift test
swift build
```

This keeps static privacy checks and Swift tests ahead of the standalone build.
