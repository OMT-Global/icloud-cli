# iCloud CLI Vision

Version: 0.2

iCloud CLI is a macOS command-line toolkit for reading local iCloud-backed Apple state. It is local, read-only, and operator-facing: it should help a user understand Safari, iCloud Drive, Shortcuts, account status, and nearby Apple metadata without turning private device data into a cloud service.

The product started with Safari tabs and CloudTabs investigation, but the useful shape is broader: safe local inventory commands, privacy-aware permission diagnostics, and redacted snapshots that other local automation such as OpenClaw can consume.

## Who It Serves

- A privacy-conscious Mac operator who wants scriptable visibility into local Apple ecosystem state.
- Agents that need stable JSON contracts, fixture-backed parsers, and explicit privacy rules before using personal-device data.
- Local automation systems that need aggregate or redacted state without receiving raw browsing, account, or file payloads by default.

## Current Product Boundary

- Supported sources: local Safari session/bookmark/profile/frequently-visited data, CloudTabs probes and confirmed sensitive listing, iCloud Drive metadata, Shortcuts metadata, account and system status caches, Wallet/Handoff fixtures, and broad local inventory snapshots.
- Permission model: commands name unreadable paths and `permissions doctor` probes source availability without reading payload content.
- Distribution path: versioned universal macOS DMGs signed with a stable identifier, notarized, stapled, and published with checksums.
- Integration path: OpenClaw skill contract and redacted command output suitable for local node reporting.
- Execution model: a signed on-demand CLI owns local archives; schedulers may invoke bounded commands, but a resident daemon is not required.

## Product Principles

- Local-only and read-only unless a future issue explicitly changes that boundary.
- Sensitive output requires explicit confirmation or redaction; broad snapshots should prefer counts, statuses, and paths over raw content.
- Permission errors should be actionable and path-specific, not vague.
- Tests and privacy fixtures are part of the product contract for every parser.
- CLI ergonomics matter: stable JSON, useful text output, clear help, deterministic release artifacts, and no unnecessary dependencies.

## Near-Term Direction

- Strengthen redacted aggregate inventory commands that summarize Apple state safely.
- Keep CloudTabs work narrow: probe first, require confirmation for sensitive listing, and document local database constraints.
- Expand permissions diagnostics for the stores that commonly require Full Disk Access.
- Preserve release packaging, coverage indicators, privacy checks, and governance audits as fast local gates.

## Non-Goals

- Do not become a sync service, daemon, or remote data collector.
- Do not add per-domain helpers or external delegation without a provider-specific issue proving the permission boundary, IPC, archive ownership, and recovery model.
- Do not upload, persist, or share private Apple account data.
- Do not add broad Apple cache readers without explicit privacy docs, fixtures, and command contracts.
- Do not make OpenClaw or agent integrations depend on raw browsing or account payloads.
