# Issue work result

## Selected issues

- Closes #19
- Closes #32

## Summary

Added read-only iCloud Drive metadata inventory commands:

- `icloud-cli drive list` lists files under the local iCloud Drive root with relative path, name, size, modified timestamp, iCloud status, and app container.
- `icloud-cli drive containers` lists top-level iCloud app containers with display name, size, and latest modified timestamp.

The implementation uses synthetic filesystem fixtures and does not read file contents.

## Validation

Run before PR:

```sh
bash scripts/ci/run-fast-checks.sh
swift test
swift build
bash scripts/check-privacy-fixtures.sh
.build/debug/icloud-cli drive list --icloud-root Tests/Fixtures/MobileDocuments --format json
.build/debug/icloud-cli drive containers --icloud-root Tests/Fixtures/MobileDocuments --sort-by size --format text
```
