# OpenClaw Safari Tabs Skill Contract

OpenClaw should invoke `icloud-cli` as a local MacBook node tool. The skill contract is intentionally read-only and local-retention first: raw browsing data stays on the Mac unless an operator explicitly exports it.

## Command

```sh
icloud-cli safari tabs --format json
```

Recommended wrapper behavior:

```sh
#!/usr/bin/env bash
set -euo pipefail

icloud-cli safari tabs --format json
```

Use `--safari-dir PATH` only for synthetic fixtures, tests, or a deliberate operator override. Use `icloud-cli safari cloud-tabs probe --format json` as a readiness check before any future cloud-tab opt-in is offered.

## JSON Schema

Successful `safari tabs --format json` output is an array of tab objects:

```json
[
  {
    "source": "current-session",
    "tabIndex": 0,
    "title": "Example",
    "url": "https://example.com/current",
    "windowIndex": 0
  }
]
```

Field contract:

| Field | Type | Notes |
| --- | --- | --- |
| `url` | string | Full URL requested by the operator. Treat as sensitive. |
| `title` | string or null | Browser title. Treat as sensitive and redact from status logs by default. |
| `windowIndex` | integer or null | Zero-based window index when the source preserves it. |
| `tabIndex` | integer or null | Zero-based tab index when the source preserves it. |
| `source` | string | `current-session` or `last-session` for the current command. |

The cloud-tab probe emits one object with booleans for `exists` and `readable`, a nullable `sizeBytes`, source-class lists, a `recommendedDefault`, a `permissionExpectation`, and a nullable `failureMode`.

## Error Shape

The CLI exits non-zero and writes a single human-readable error line to stderr. OpenClaw should classify these strings into actionable local status:

| Error text contains | OpenClaw status |
| --- | --- |
| `No readable Safari session files found` | Permission or path problem; ask operator to grant Full Disk Access or check `--safari-dir`. |
| `Readable Safari session files did not contain tabs` | Safari data was readable but empty; not an infrastructure failure. |
| `unreadable Safari session files` | Mixed empty/unreadable state; report both readable-empty and permission follow-up. |
| `Unsupported output format` | Skill wrapper bug; repair command arguments. |

Do not upload stderr with unredacted local paths to remote logs. Replace the home directory with `~/...` in OpenClaw status summaries.

## Retention And Export Boundaries

- Default retention is local-only on the MacBook node.
- OpenClaw status logs should redact titles and reduce URLs to scheme plus host unless the operator requests full export.
- Raw JSON output may be passed to a local OpenClaw planner on the same Mac.
- Remote export requires an explicit operator action and should name the destination.
- Cloud-tab data must stay disabled by default until a fixture-backed parser and opt-in flag exist.
