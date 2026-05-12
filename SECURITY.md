# Security Policy

`icloud-cli` reads privacy-sensitive Apple and browser state from the local Mac. Treat Safari tab URLs, iCloud state, logs, and fixture data as sensitive unless they are explicitly synthetic.

## Reporting

Report security issues privately to the OMT-Global maintainers instead of opening a public issue with sensitive details.

## Handling Sensitive Data

- Do not commit live Safari session files, iCloud databases, auth state, sessions, caches, or machine-local secrets.
- Use synthetic fixtures for tests.
- Keep raw browsing data local unless an operator explicitly exports it.
- Redact URLs and local paths in public reports unless they are synthetic examples.

See `docs/privacy.md` for command-level permission expectations and redaction defaults.
