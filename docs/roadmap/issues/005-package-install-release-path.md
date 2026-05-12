## Problem / intent

Operators and OpenClaw nodes need a reproducible way to install `icloud-cli` without building from source manually on every machine.

## Acceptance criteria

- Decide the first distribution path: Homebrew tap, OpenClaw tap, signed binary artifact, or source checkout.
- Add a release build command that produces a predictable binary artifact.
- Document install and upgrade steps.
- Keep release automation compatible with the OMT bootstrap governance model.

## Validation commands

```sh
bash scripts/ci/run-fast-checks.sh
make build
```

## Notes

- Signing/notarization can be a follow-up if the first distribution path does not require it.
