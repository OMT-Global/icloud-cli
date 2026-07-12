# Messages archive and search

The Messages provider uses an internal, read-only adapter rather than delegating to `imsgcrawl` or `imsg`. This keeps the versioned output, snapshot, archive, retention, and privacy contracts in one executable while leaving send, react, and other actions outside the crawler boundary. It never loads private frameworks, injects a library, disables SIP, or modifies Apple's database.

`messages archive --confirm-sensitive` copies `chat.db` and any present WAL/SHM companions into private temporary storage through the shared SQLite snapshot engine. It reads a bounded batch in ascending message-date order, persists stable message and conversation identifiers, advances a cursor only after a successful archive sync, and stores a source size/modification fingerprint. Repeated batches deduplicate by message id and fields. A complete bounded identifier scan creates tombstones for disappeared messages; when the source exceeds the explicit limit, deletion inference is skipped rather than risking false tombstones. Group chats retain their chat identifier.

Bodies are omitted by default. `--include-body` is accepted only with `--body-retention-days 1...365`; searching bodies also requires `--confirm-sensitive`. Metadata search returns `icloud-cli.messages-search.v1` rows and never exposes bodies unless both flags are present. The shared archive remains local, private, bounded, and excluded from backup on a best-effort basis.

The Apple Messages schema is private and varies by macOS release. The adapter supports the current public fixture shape and the established `message`, `chat`, `chat_message_join`, and `handle` tables, failing closed when neither shape is present. Attachments and attributed-body blobs are unsupported and never archived.
