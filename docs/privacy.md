# Privacy And Permissions Model

`icloud-cli` reads Apple state from the local Mac. The default posture is local-only, read-only, and explicit: commands should report what they read, avoid hidden export paths, and redact data when output is meant for logs, issues, or OpenClaw telemetry.

## Sensitive Data Classes

The CLI may read or derive:

- Safari tab URLs and titles.
- Safari bookmark URLs/titles, Reading List URLs/titles, and frequently visited URLs/titles.
- Safari history URLs/titles and visit timestamps.
- Notes titles, folder names, dates, and optional body content.
- Reminder titles, due dates, priorities, and optional notes.
- Contacts names, emails, phones, organizations, and optional notes.
- Messages conversation metadata and optional recent message bodies.
- Photos/screenshots, Maps, and News metadata.
- Account, backup, Family Sharing, Calendar, Mail, Find My, Health aggregate, Home, Books, Music, Weather, Stocks, Freeform, Voice Memos, Finder tag, shared Photos, and Safari profile/extension metadata.
- Safari session file paths and read errors.
- Safari iCloud tab metadata from local sync stores such as `CloudTabs.db`.
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
| `icloud-cli photos screenshots` | Screenshot file metadata under `~/Pictures/Screenshots` by default | Normal user file access. The command does not read pixel data or thumbnails. Logs should redact home-directory paths. |
| `icloud-cli photos list` | Local Photos library file metadata under `~/Pictures/Photos Library.photoslibrary` by default | Full Disk Access may be needed. The command emits file metadata only and does not export pixels, thumbnails, or EXIF location data. |
| `icloud-cli notes list` | Local Notes SQLite metadata from `~/Library/Group Containers/group.com.apple.notes/NoteStore.sqlite` by default | Full Disk Access may be needed. Body content is omitted unless `--include-body` is passed. Logs should redact titles and always omit bodies. |
| `icloud-cli reminders list` / `reminders lists` | EventKit reminder and list metadata by default | Reminders authorization is required. `reminders authorization` checks state without prompting. The explicit `--degraded-private-store` fallback reads a version-checked private store and may require Full Disk Access. Reminder titles and notes are sensitive; logs should summarize list counts. |
| `icloud-cli safari history` | `~/Library/Safari/History.db` | Full Disk Access is expected. Requires `--confirm-sensitive`; `--redact-urls` is recommended for automated export. This command is not part of default watch polling. |
| `icloud-cli messages conversations` / `messages recent` | `~/Library/Messages/chat.db` | Full Disk Access is expected. Recent message reads require `--confirm-sensitive`; bodies require `--include-body`. Message commands are not part of default watch polling. |
| `icloud-cli contacts list` | Local AddressBook SQLite metadata under `~/Library/Application Support/AddressBook` by default | Contacts permission or Full Disk Access may be needed. Notes are omitted unless `--include-notes` is passed. |
| `icloud-cli maps favorites` / `maps recents` | Local Maps cache under `~/Library/Containers/com.apple.Maps` by default | Location data is sensitive. Home/work categories are high-sensitivity and logs must omit coordinates. |
| `icloud-cli news history` / `news topics` | Local News cache under `~/Library/Containers/com.apple.news` by default | Reading history is interest-graph data. Logs should summarize source/topic counts rather than URLs. |
| `icloud-cli watch` / `cache read` / `cache status` | Local cache files under `~/.icloud-cli/cache` by default | Cache files inherit the sensitivity of each command. The cache directory is created with mode `0700`; Safari history, Messages, and Contacts are excluded from the default command set. |
| Future iCloud settings commands | Local Apple account or system settings state | Document per-command read surfaces before implementation; do not require Automation unless a command actually controls an app. |

Automation permission is not required for the current Safari tab reader because it reads local files. Any future command that controls Safari, System Settings, or another app must document the Automation prompt and failure mode before merge.

Reminders commands are read-only. EventKit is the primary source for `list` and `lists`; private smart views and the explicit degraded fallback can break when Apple changes its schema and therefore fail closed on unsupported shapes. Any future mutation must live under a separate `actions reminders` namespace and follow [ADR 001](adr/001-eventkit-reminders-action-boundary.md).

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

`icloud-cli drive status`, `drive errors`, `drive shared`, and `drive recents` reuse the same local iCloud Drive filesystem read surface. They summarize sync state, recent modification dates, and best-effort shared item metadata without opening file contents or making network requests.


## Shortcuts inventory

`icloud-cli shortcuts list` reads local Shortcuts metadata only. It does not execute shortcuts, request Automation permission, or read action payload contents beyond counting action entries in the shortcut plist. Shortcut names are operator-sensitive metadata; logs and status summaries should avoid dumping full JSON unless explicitly requested.


## Local iCloud status surfaces

`icloud-cli storage status`, `icloud-cli focus status`, and `icloud-cli devices list` read cached local metadata only. They do not contact iCloud, mutate system settings, or require Automation permission. Storage and devices currently use the local MobileMe/iCloud account preferences cache when present; Focus reads the local Do Not Disturb preference directory. Direct command output may include the real account email and device names because the operator requested them. OpenClaw logs and PR summaries should redact account emails and avoid listing device names unless explicitly requested.


## Wallet and Handoff inventory

`icloud-cli wallet passes` reads local pass manifests from `~/Library/Passes` and emits only pass metadata: type, description, organization, relevant/expiration dates, and serial number. It intentionally does not emit barcode payloads, NFC/payment material, images, signatures, or full ZIP contents. Serial numbers are identifiers and should be hidden from OpenClaw status summaries unless the operator explicitly requests raw command output.

`icloud-cli handoff list` reads cached local Handoff activity metadata from `~/Library/Application Support/com.apple.handoff`. The cache schema is treated as best-effort and may vary by macOS release, so the reader accepts JSON/plist fixtures and common key aliases rather than promising a private Apple schema. Activity titles and URLs are sensitive cross-device context; logs should summarize by app/device/count only.


## High-sensitivity local inventories

The Photos, Notes, Reminders, Safari history, Messages, Contacts, Maps, and News commands are read-only local inventory surfaces. Synthetic tests use controlled fixture stores; real Apple private schemas can vary by macOS release, so schema adapters should stay conservative and fail closed when tables are unavailable.

`icloud-cli watch` defaults to lower-risk polling commands only: `safari-tabs`, `drive-list`, `photos-screenshots`, and `storage-status`. Operators may add commands explicitly, but high-sensitivity commands such as Safari history, Messages, and Contacts are intentionally excluded from the default cache refresh set.


## Broad Local Metadata Commands

The second inventory wave adds local-only command trees for `account status`, `backup status`, `family status`, `calendar`, `findmy`, `mail`, `books`, `voice-memos`, `home`, `health summary`, `photos shared-albums`, `photos shared-library`, `safari cloud-tabs list`, `safari profiles list`, `safari extensions list`, `tags`, `weather`, `stocks`, `music`, `freeform`, `notes accounts/folders/tags/shared`, and `reminders flagged/today/scheduled/assigned`.

These commands use preference/plist readers for account, backup, Family Sharing, permissions, and snapshot status, plus best-effort SQLite metadata readers for Apple private cache stores when a stable local table shape is known or supplied by fixtures. All adapters are read-only and local-only. They do not refresh iCloud, contact Apple services, control apps, trigger HomeKit accessories, execute shortcuts, read audio/photo/book/media payloads, or emit auth tokens. Private Apple schemas can vary across macOS releases, so commands fail closed when expected local tables are absent.

Messages and Safari history queries first copy the database and present WAL/SHM companions into a private temporary directory, query that copy in read-only/query-only mode with bounded busy and process timeouts, and delete it deterministically. See [sqlite-snapshots.md](sqlite-snapshots.md) for the migration and cleanup contract.

Recursive Drive and Finder-tag crawls use explicit scan and wall-clock budgets and return structured partial/timeout metadata rather than hanging. Polling records only redacted failure codes and guidance when a crawl cannot finish. See [crawl-budgets.md](crawl-budgets.md) for the output contract.

High-sensitivity gates:

- `icloud-cli safari cloud-tabs list`, `icloud-cli mail recent`, and `icloud-cli health summary` require `--confirm-sensitive`.
- `findmy` and `weather` omit coordinates unless `--include-coordinates` is passed.
- `calendar events` omits attendees and notes unless `--include-attendees` or `--include-notes` is passed.
- `books list` omits highlight counts unless `--include-highlights` is passed and never emits quoted annotation text.
- `reminders` smart lists omit notes unless `--include-notes` is passed.
- `safari cloud-tabs list` defaults to device/tab summaries; `--include-urls` emits scheme and host only, while `--raw` is required with `--include-urls` for full URLs.

`icloud-cli snapshot` composes lower-risk command summaries into one redacted operator payload for terminal use and OpenClaw polling. The default snapshot excludes Safari history, Messages, Contacts, Mail recent headers, Find My people, Health, raw CloudTabs URLs, Notes bodies, and location coordinates.

`icloud-cli permissions doctor` probes source path existence/readability only. It does not decode plist/SQLite payloads and does not require `--confirm-sensitive`; sensitive commands are reported as `needs-confirm-sensitive` so automation can distinguish permission issues from explicit operator gates.
