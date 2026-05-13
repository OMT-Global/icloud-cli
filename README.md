# iCloud CLI

macOS command-line tools for reading iCloud-backed Apple state. The first supported command is Safari tab discovery:

```sh
icloud-cli safari tabs
icloud-cli safari tabs --format text
icloud-cli safari tabs --source current-session
icloud-cli safari cloud-tabs probe
```

The initial implementation reads local Safari session property lists from `~/Library/Safari`. That keeps the first slice simple and testable while we map the broader iCloud/Safari sync surface. Reading live browser state may require running the terminal with Full Disk Access on macOS.

If Safari session files are unreadable, the command exits with an error naming the file paths it tried. If the files are readable but empty, the error says no tabs were found instead of treating it as a permissions problem.

Use `icloud-cli safari cloud-tabs probe` to check whether Safari's cross-device tab store is present and readable before enabling any cloud-tab parsing. See [docs/cloudtabs.md](docs/cloudtabs.md) for the investigation notes, [docs/privacy.md](docs/privacy.md) for the privacy and permissions model, and [docs/openclaw-skill-contract.md](docs/openclaw-skill-contract.md) for the OpenClaw integration contract.

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

The gate checks CI policy drift, shell syntax, secret patterns, privacy fixtures, Swift tests, debug and release builds, and CLI help output.

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
