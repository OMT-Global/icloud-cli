# Issue work result

## Selected issue

- Closes #27

## Summary

Added `icloud-cli shortcuts list` for read-only local Shortcuts metadata inventory. Each entry includes `name`, `actionCount`, `createdAt`, `modifiedAt`, and `acceptsInput`. The command supports `--name PATTERN`, `--format json|text`, and `--shortcuts-dir PATH` for fixtures or alternate libraries.

The implementation does not execute shortcuts and does not request Automation permission.

## Validation

Run before PR:

```sh
bash scripts/ci/run-fast-checks.sh
swift test
swift build
bash scripts/check-privacy-fixtures.sh
.build/debug/icloud-cli shortcuts list --shortcuts-dir Tests/Fixtures/Shortcuts --format json
.build/debug/icloud-cli shortcuts list --shortcuts-dir Tests/Fixtures/Shortcuts --name Daily --format text
```
