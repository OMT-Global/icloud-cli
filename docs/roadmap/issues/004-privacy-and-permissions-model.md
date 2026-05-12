## Problem / intent

This app touches privacy-sensitive Apple account and browser state. Before adding more iCloud settings surfaces, the repo needs a clear permissions and data-handling model.

## Acceptance criteria

- Document privacy-sensitive data classes the CLI may read.
- Define redaction defaults for logs, errors, issue reports, and OpenClaw integration output.
- Document Full Disk Access and Automation permission requirements by command.
- Add tests or static checks that prevent accidental fixture/history leakage where practical.

## Validation commands

```sh
bash scripts/ci/run-fast-checks.sh
```

## Notes

- Do not store auth state, sessions, caches, or machine-local secrets in the repo.
- Treat browsing history and tab URLs as sensitive by default.
