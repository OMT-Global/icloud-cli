# iCloud CLI

macOS command-line tools for reading local iCloud-backed Apple state. The current command surface focuses on read-only local inventory:

```sh
icloud-cli safari tabs
icloud-cli safari tabs --format text
icloud-cli safari tabs --source current-session
icloud-cli safari cloud-tabs probe
icloud-cli safari cloud-tabs list --confirm-sensitive
icloud-cli safari bookmarks
icloud-cli safari reading-list
icloud-cli safari frequently-visited --limit 10
icloud-cli drive list --depth 2
icloud-cli drive status
icloud-cli drive containers --sort-by size
icloud-cli account status
icloud-cli snapshot
icloud-cli permissions doctor
icloud-cli shortcuts list --name Daily
```

The implementation reads local Safari session and metadata property lists from `~/Library/Safari`, iCloud Drive metadata from `~/Library/Mobile Documents`, Shortcuts metadata from `~/Library/Shortcuts`, and best-effort local Apple cache stores for account, backup, family, Calendar, Mail, Find My, Photos sharing, Health aggregates, Home, Books, Music, Weather, Stocks, Freeform, Voice Memos, Finder tags, Notes, and Reminders. Commands stay local and read-only while we map the broader iCloud/Safari sync surface. Reading live browser state or private Apple caches may require running the terminal with Full Disk Access on macOS.

If Safari session files are unreadable, the command exits with an error naming the file paths it tried. If the files are readable but empty, the error says no tabs were found instead of treating it as a permissions problem.

Use `icloud-cli safari cloud-tabs probe` to check whether Safari's cross-device tab store is present and readable before using `icloud-cli safari cloud-tabs list --confirm-sensitive`. Use `icloud-cli permissions doctor` when a command reports missing or unreadable local stores; it probes source paths without reading payload content and gives the Full Disk Access hint per command. See [docs/cloudtabs.md](docs/cloudtabs.md) for the investigation notes, [docs/privacy.md](docs/privacy.md) for the privacy and permissions model, and [docs/openclaw-skill-contract.md](docs/openclaw-skill-contract.md) for the OpenClaw integration contract.

## Build

```sh
make build
make test
make release
```

The first distribution path is a source checkout that builds a local release binary. `make release` writes `dist/icloud-cli` and `dist/icloud-cli.sha256`; copy or symlink that binary into the operator's PATH. See [docs/install.md](docs/install.md) for install and upgrade steps.

## CI

Run the same local gate that backs PR `CI Gate` before opening a PR:

```sh
bash scripts/ci/run-fast-checks.sh
```

The gate checks CI policy drift, shell syntax, secret patterns, privacy fixtures, Swift tests, source coverage with CRAP-style low-coverage indicators, debug and release builds, and CLI help output.

## Roadmap

The roadmap lives in GitHub issues. The first milestone focuses on:

- stable `icloud-cli safari tabs` JSON output
- reliable discovery of local Safari session files
- investigation of `CloudTabs.db` for cross-device iCloud Safari tabs
- OpenClaw skill integration so a MacBook node can report tab inventory safely

## Bootstrap

This repo uses `project.bootstrap.yaml` as the governance control plane.

```sh
node ~/src/omt-global/bootstrap/dist/cli.js plan --manifest ./project.bootstrap.yaml --target .
node ~/src/omt-global/bootstrap/dist/cli.js apply repo --manifest ./project.bootstrap.yaml --target .
```

Do not run `bootstrap apply home` for this repo; it intentionally sets `agents.manageCodexHome: false`.

Use `scripts/audit-github-settings.sh` and the checklist in [docs/bootstrap/governance-audit.md](docs/bootstrap/governance-audit.md) after bootstrap changes or org plan changes.
