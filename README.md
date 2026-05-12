# iCloud CLI

macOS command-line tools for reading iCloud-backed Apple state. The first supported command is Safari tab discovery:

```sh
icloud-cli safari tabs
icloud-cli safari tabs --format text
icloud-cli safari tabs --source current-session
```

The initial implementation reads local Safari session property lists from `~/Library/Safari`. That keeps the first slice simple and testable while we map the broader iCloud/Safari sync surface. Reading live browser state may require running the terminal with Full Disk Access on macOS.

If Safari session files are unreadable, the command exits with an error naming the file paths it tried. If the files are readable but empty, the error says no tabs were found instead of treating it as a permissions problem.

## Build

```sh
make build
make test
```

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
