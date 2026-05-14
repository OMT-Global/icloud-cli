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
| `icloud-cli shortcuts list` | `~/Library/Shortcuts/*.shortcut` metadata including shortcut names, action counts, dates, and input capability | Terminal or calling process may need access to the Shortcuts library. The command is read-only and never executes shortcuts. |
| `icloud-cli storage status` | Locally cached iCloud quota metadata, currently `~/Library/Preferences/MobileMeAccounts.plist` when available | Normal user file access. The command is read-only and makes no live network requests. Account email is direct operator output only; logs should redact to `user@…`. |
| `icloud-cli focus status` | Local Focus / Do Not Disturb preference plists under `~/Library/DoNotDisturb` | Normal user file access. The command is read-only and does not modify Focus state. |
| `icloud-cli devices list` | Locally cached iCloud registered-device metadata, currently `~/Library/Preferences/MobileMeAccounts.plist` when available | Normal user file access. Device names may be personally identifying; logs should report only count/model summary. |
| `icloud-cli wallet passes` | Local Wallet pass bundles under `~/Library/Passes`, reading pass manifests only | Normal user file access or Full Disk Access depending on macOS privacy posture. The command is read-only, emits no barcode or payment credential payloads, and logs should omit serial numbers. |
| `icloud-cli handoff list` | Local Handoff cache files under `~/Library/Application Support/com.apple.handoff` | Normal user file access. The command is read-only and does not use Bluetooth, network, or Continuity APIs. Titles and URLs are sensitive and should be redacted in logs. |
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


## iCloud Drive inventory

`icloud-cli drive list` and `icloud-cli drive containers` read filesystem metadata under `~/Library/Mobile Documents` only. They do not read file contents. JSON output includes real paths by design for direct operator use; logs and status summaries should redact the home directory. Evicted `.icloud` stubs are reported as metadata with `sizeBytes: null`.


## Shortcuts inventory

`icloud-cli shortcuts list` reads local Shortcuts metadata only. It does not execute shortcuts, request Automation permission, or read action payload contents beyond counting action entries in the shortcut plist. Shortcut names are operator-sensitive metadata; logs and status summaries should avoid dumping full JSON unless explicitly requested.


## Local iCloud status surfaces

`icloud-cli storage status`, `icloud-cli focus status`, and `icloud-cli devices list` read cached local metadata only. They do not contact iCloud, mutate system settings, or require Automation permission. Storage and devices currently use the local MobileMe/iCloud account preferences cache when present; Focus reads the local Do Not Disturb preference directory. Direct command output may include the real account email and device names because the operator requested them. OpenClaw logs and PR summaries should redact account emails and avoid listing device names unless explicitly requested.


## Wallet and Handoff inventory

`icloud-cli wallet passes` reads local pass manifests from `~/Library/Passes` and emits only pass metadata: type, description, organization, relevant/expiration dates, and serial number. It intentionally does not emit barcode payloads, NFC/payment material, images, signatures, or full ZIP contents. Serial numbers are identifiers and should be hidden from OpenClaw status summaries unless the operator explicitly requests raw command output.

`icloud-cli handoff list` reads cached local Handoff activity metadata from `~/Library/Application Support/com.apple.handoff`. The cache schema is treated as best-effort and may vary by macOS release, so the reader accepts JSON/plist fixtures and common key aliases rather than promising a private Apple schema. Activity titles and URLs are sensitive cross-device context; logs should summarize by app/device/count only.
