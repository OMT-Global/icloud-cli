# Safe SQLite snapshots

Apple applications often keep committed SQLite state across a database file and its write-ahead log. Querying the live path directly can produce inconsistent reads, wait indefinitely on a busy store, or interact with an Apple-owned database in ways the CLI does not intend.

`SQLiteSnapshotQueryEngine` creates a mode-`0700` temporary directory and asks SQLite to create a consistent private snapshot with `VACUUM INTO`. SQLite coordinates the main database and WAL under one read view, so a live writer cannot leave a mixed-generation main/WAL copy. The resulting snapshot is mode-`0600` and queried with `-readonly`, `PRAGMA query_only=ON`, a bounded busy timeout, and a bounded process timeout. Production callers use `SQLiteSnapshotQueryEngine.production`, which enforces minimums of 500ms busy timeout and 5s process timeout. The snapshot, query output, and error output are deleted before the call returns or throws. Snapshot contents are never logged.

Errors retain the original store path and distinguish missing stores, permission denial, unsupported schemas, locked or busy stores, and timeouts. `VACUUM INTO` reads the Apple-owned source without checkpointing, mutating, or creating source-side files.

## Migration status

Messages conversations/recent messages and Safari history use the snapshot engine first because they read high-sensitivity, frequently changing databases. The remaining SQLite-backed providers still use the older read-only query path and should migrate incrementally with their provider-specific work:

- Notes and Reminders
- Calendar, Contacts, Mail, and Maps
- Photos sharing and Find My metadata
- Books, Voice Memos, Home, Health, Freeform, Music, Stocks, Weather, and News
- Safari Cloud Tabs, profiles, and extensions where their selected store is SQLite

Provider migrations should retain existing confirmation and redaction gates and add WAL-backed fixtures before switching paths.
