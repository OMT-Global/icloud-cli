# Resumable provider archives

`icloud-cli archive sync PROVIDER --input BATCH.json` persists a bounded, incremental metadata archive under `~/.icloud-cli/archives` by default. `icloud-cli archive status PROVIDER` returns freshness and health metadata without returning archived records.

## Contracts

Archive sync input uses `icloud-cli.archive-sync.v1`. Each batch declares a stable provider id, a provider-owned schema version, a source fingerprint, an optional resume cursor, nested metadata records, explicit deleted ids, and an optional structured failure. Payload fields are JSON values, not JSON serialized into strings.

Stored documents use `icloud-cli.archive.v1`. The shared envelope owns cursor, fingerprint, attempt/success timestamps, freshness, counts, failure state, tombstones, and retention. Providers continue to own their `providerSchemaVersion` and field meanings. The reader migrates the legacy synthetic `icloud-cli.archive.v0` envelope and writes the migrated v1 document atomically.

Only providers declaring the `archive-metadata` capability may sync. The initial allowlist is account, backup, devices, Drive, Focus, Handoff, Shortcuts, and storage metadata. High-sensitivity providers and body/media fields fail closed until a later provider issue explicitly opts them in.

## Sync behavior

- Upserts are keyed by provider record id and are idempotent when source timestamp and fields are unchanged.
- `deletedIds` create tombstones rather than silently dropping records.
- A cursor and source fingerprint advance only after a complete batch.
- Partial source failures and scan/time budgets preserve the last successful cursor while recording redacted failure code and guidance.
- `--scan-limit` and `--timeout-ms` bound each sync attempt.
- Status reports last attempt, last success, freshness, active/tombstone/total counts, cursor, fingerprint, and structured failure.

## Storage, retention, and backup

The archive directory is mode `0700`; documents are mode `0600` and replaced atomically. The CLI requests the macOS backup-exclusion resource flag on the directory, but backup tools and filesystems may not honor it, so operators should explicitly exclude this path. Operators who need disaster recovery should back it up only into an encrypted, access-controlled destination and restore the whole provider document rather than editing cursors manually.

Tombstones are retained for 30 days by default, and each provider archive is capped at 100,000 records. Retention runs after each sync. Archive code does not log record fields, identifiers, source paths, or failure payloads; errors expose stable codes and operator guidance only.
