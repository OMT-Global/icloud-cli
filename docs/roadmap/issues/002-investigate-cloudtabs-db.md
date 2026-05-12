## Problem / intent

Local session files are useful for the active Mac, but Safari iCloud tabs may also live in `~/Library/Safari/CloudTabs.db` or adjacent sync artifacts. We need to map that storage before promising cross-device tab visibility.

## Acceptance criteria

- Document which Safari/iCloud files contain local tabs vs cross-device iCloud tabs on current macOS.
- Add a read-only probe command or internal fixture parser for `CloudTabs.db` if it is stable enough.
- Identify required macOS permissions and failure modes.
- Decide whether cross-device tabs belong under `icloud-cli safari tabs` by default or a separate option such as `--include-cloud`.

## Validation commands

```sh
bash scripts/ci/run-fast-checks.sh
```

## Notes

- Do not commit live `CloudTabs.db` data.
- Prefer fixture databases with synthetic URLs/titles.
