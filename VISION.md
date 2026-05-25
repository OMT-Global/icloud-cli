# iCloud CLI Vision

Version: 0.1

iCloud CLI is a local-first Swift command-line tool for inspecting selected iCloud-adjacent state, starting with Safari tab inventory and expanding only where privacy and reliability can stay clear.

The product should help the operator understand personal Apple ecosystem state without sending private data elsewhere.

## Who It Serves

- A privacy-conscious operator who wants local inspection tools.
- Agents that need explicit command contracts and fixture-backed tests.
- Future users who want small, auditable iCloud utilities instead of a broad opaque app.

## Product Principles

- Local-only by default.
- Redact sensitive output unless the command explicitly promises otherwise.
- Tests should be written before new behavior.
- SwiftPM CLI ergonomics matter: help, errors, and release artifacts are product surfaces.
- Governance and roadmap should stay issue-backed.

## Near-Term Direction

- Strengthen aggregate, redacted inventory commands.
- Keep Safari tabs and CloudTabs probing narrow and well-tested.
- Preserve release packaging with checksums.
- Maintain governance audits without extra runtime dependencies.

## Non-Goals

- Do not become a cloud sync service.
- Do not collect or transmit private account data.
- Do not add broad iCloud surfaces without clear local data contracts and privacy docs.
