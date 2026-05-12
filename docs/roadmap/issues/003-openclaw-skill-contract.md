## Problem / intent

OpenClaw should be able to run this CLI from the MacBook node and ingest Safari tab inventory without exposing more browsing data than the operator intends.

## Acceptance criteria

- Define the OpenClaw skill command contract for Safari tab reads.
- Document expected JSON schema and error shape.
- Add an example skill wrapper or command snippet that invokes `icloud-cli safari tabs`.
- Add guidance for local-only retention, redaction, and export boundaries.

## Validation commands

```sh
bash scripts/ci/run-fast-checks.sh
swift run icloud-cli safari tabs --help
```

## Notes

- Keep raw browsing data local unless the operator explicitly exports it.
- The OpenClaw node integration should treat permissions failures as actionable status, not generic command failure.
