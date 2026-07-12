# Federated local search

`icloud-cli search QUERY` scans opted-in provider archive documents and returns `icloud-cli.federated-search.v1`. Every hit keeps its provider id and provider-native record id, timestamp, sensitivity, redaction state, archive schema version, source fingerprint, and archive timestamp. Search does not create global people, place, trip, or account identities.

Results are bounded to 1,000 per page and ranked deterministically by timestamp descending, then provider id and record id. Repeat `--provider ID` to restrict providers; `--since`, `--until`, and the opaque returned cursor support time bounds and pagination. Deleted or tombstoned records are excluded.

High-sensitivity providers are excluded unless `--include-sensitive` is present. Body, content, and attachment fields are never indexed unless `--include-bodies` is also present, which requires `--confirm-sensitive`. High-sensitivity metadata-only snippets remain redacted even when the provider is included.

The implementation builds no secondary identity or search database: each query reads the current versioned provider archives. Therefore archive retention and tombstones apply immediately, reindexing means rerunning the query, and archive schema migration occurs through the shared archive reader. A provider joins only after its manifest declares `archive-metadata`; unsupported or missing archives are skipped without weakening another provider's result provenance.
