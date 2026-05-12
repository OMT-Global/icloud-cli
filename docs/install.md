# Install And Release Path

The first supported distribution path is a source checkout that produces a predictable local release artifact. This keeps the package path compatible with OMT bootstrap governance while avoiding signing, notarization, and tap maintenance before the CLI surface stabilizes.

## Decision

Use a source checkout plus `make release` for the first operator install path.

Deferred distribution paths:

- Homebrew tap.
- OpenClaw-specific tap.
- Signed and notarized binary artifact.

Signing and notarization can follow once the command surface and release cadence are stable.

## Build Artifact

```sh
make release
```

Expected outputs:

- `dist/icloud-cli`
- `dist/icloud-cli.sha256`

The release target runs `swift build -c release`, creates `dist/`, copies the release executable to a stable path, and writes a SHA-256 checksum.

## Install

From a trusted checkout:

```sh
make release
mkdir -p ~/.local/bin
cp dist/icloud-cli ~/.local/bin/icloud-cli
~/.local/bin/icloud-cli --version
```

Ensure `~/.local/bin` is on the operator PATH before configuring OpenClaw wrappers.

## Upgrade

```sh
git pull --ff-only
make release
cp dist/icloud-cli ~/.local/bin/icloud-cli
~/.local/bin/icloud-cli --version
```

If the checkout is managed by an agent, verify the branch and PR state before pulling or replacing a live binary.

## Bootstrap Compatibility

This repo keeps release automation in source-controlled project files and leaves GitHub policy under `project.bootstrap.yaml`. The current manifest has `release.enabled: false`, so this release target is a local operator artifact path, not a remote publishing workflow.
