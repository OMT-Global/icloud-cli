## Problem / intent

The first operator-facing slice is `icloud-cli safari tabs`: read Safari tab state on the local MacBook node and emit a stable payload that OpenClaw can ingest.

The initial bootstrap commit adds a parser for local Safari session property lists and fixture-backed tests. This issue tracks hardening that MVP against real Safari data shape variations before we treat it as ready for OpenClaw automation.

## Acceptance criteria

- `icloud-cli safari tabs` emits stable JSON with URL, title, source, window index, and tab index.
- `--format text`, `--source current-session`, `--source last-session`, and `--safari-dir` keep working.
- Tests cover representative Safari `CurrentSession.plist` / `LastSession.plist` variants without reading the live user profile.
- Error output clearly distinguishes missing Full Disk Access / unreadable files from empty tab state.
- README documents the minimum macOS permissions and example commands.

## Validation commands

```sh
bash scripts/ci/run-fast-checks.sh
swift run icloud-cli safari tabs --safari-dir Tests/Fixtures/Safari --format json
swift run icloud-cli safari tabs --safari-dir Tests/Fixtures/Safari --format text
```

## Notes

- Keep tests first: extend fixture coverage before changing parser behavior.
- Avoid committing live browser history or machine-local Safari files.
