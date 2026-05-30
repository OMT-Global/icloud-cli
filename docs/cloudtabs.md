# Cloud Tabs Investigation

Safari exposes two distinct tab surfaces that should stay separate in the CLI contract until the cross-device store is parsed from synthetic fixtures.

## Current Local Tabs

`icloud-cli safari tabs` reads local session property lists from the Safari directory:

- `CurrentSession.plist`
- `LastSession.plist`

These files represent local Safari session state for the current Mac. They are useful for the MVP because the format can be fixture-tested without requiring live browser data.

## Cross-Device iCloud Tabs

Safari's cross-device tab sync state is expected to live in `CloudTabs.db` in the Safari directory on current macOS. That store may contain tabs from other devices signed in to the same Apple account. Treat it as more sensitive than local session fixtures because it can reveal browsing activity from multiple devices.

The repo exposes a read-only probe:

```sh
icloud-cli safari cloud-tabs probe
icloud-cli safari cloud-tabs probe --format text
icloud-cli safari cloud-tabs probe --safari-dir Tests/Fixtures/Safari
```

The probe reports whether the store exists, whether the calling process can read it, and the file size. It does not query database rows or emit tab data.

The fixture-backed parser is exposed separately:

```sh
icloud-cli safari cloud-tabs list --confirm-sensitive
icloud-cli safari cloud-tabs list --confirm-sensitive --include-urls
icloud-cli safari cloud-tabs list --confirm-sensitive --include-urls --raw
icloud-cli safari cloud-tabs list --confirm-sensitive --device "Example iPhone"
```

Default list output is a per-device/tab metadata summary. URLs are omitted unless `--include-urls` is passed. With `--include-urls`, URLs are redacted to scheme plus host. Full URLs require both `--include-urls` and `--raw`.

## Permission And Failure Modes

Expected permission behavior:

- Missing store: the Mac may not have Safari iCloud tabs enabled, Safari may not have created the sync store yet, or the configured Safari directory may be wrong.
- Unreadable store: the terminal, OpenClaw worker, or calling process likely needs Full Disk Access.
- Readable store: `safari cloud-tabs list --confirm-sensitive` can query the local metadata adapter when the expected fixture-backed table shape is available. Schema drift should fail closed rather than guessing.

## Product Decision

Keep `icloud-cli safari tabs` local-session only by default. Cross-device tabs require the explicit `safari cloud-tabs list --confirm-sensitive` command and are excluded from the default `watch` command set. This prevents the MVP command from unexpectedly expanding from current-Mac state to multi-device browsing state.
