# Safe SQLite snapshots

Apple applications often keep committed SQLite state across a database file and its write-ahead log. Querying the live path directly can produce inconsistent reads, wait indefinitely on a busy store, or interact with an Apple-owned database in ways the CLI does not intend.

`SQLiteSnapshotQueryEngine` creates a mode-`0700` temporary directory, copies the database and any present `-wal` and `-shm` companions as mode-`0600` files, and queries only that private copy. The `sqlite3` process runs with `-readonly`, `PRAGMA query_only=ON`, a one-second busy timeout, and a ten-second process timeout. The snapshot, query output, and error output are deleted before the call returns or throws. Copied contents are never logged.

Errors retain the original store path and distinguish missing stores, permission denial, unsupported schemas, locked or busy stores, and timeouts. The implementation does not checkpoint, lock, vacuum, or write to the Apple-owned source.

## Migration status

Messages conversations/recent messages and Safari history use the snapshot engine first because they read high-sensitivity, frequently changing databases. The remaining SQLite-backed providers still use the older read-only query path and should migrate incrementally with their provider-specific work:

- Notes and Reminders
- Calendar, Contacts, Mail, and Maps
- Photos sharing and Find My metadata
- Books, Voice Memos, Home, Health, Freeform, Music, Stocks, Weather, and News
- Safari Cloud Tabs, profiles, and extensions where their selected store is SQLite

Provider migrations should retain existing confirmation and redaction gates and add WAL-backed fixtures before switching paths.
