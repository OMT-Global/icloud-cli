# ADR 001: Provider, helper, and daemon execution model

Status: proposed; requires human architecture, security, and product approval

## Context

The project is a local, read-only, on-demand CLI. Its providers now span public Apple frameworks, ordinary files and preferences, and version-sensitive private stores. A stable signed release improves TCC continuity, but it does not by itself justify a persistent process or collecting every permission in a background service.

## Options

| Model | Lifecycle and resources | IPC and local authentication | TCC identity and blast radius | Failure and recovery | Archive ownership | Signing and notarization |
| --- | --- | --- | --- | --- | --- | --- |
| One on-demand CLI | Exists only per invocation; no idle cost | None for direct use; stdin/stdout and filesystem contracts for wrappers | One stable signed identity may receive multiple permissions; operator grants only providers used | Process exit isolates failures; rerun a bounded command | CLI-owned private local archives | One universal signed/notarized product and stable install path |
| launchd local daemon | Persistent or socket-activated; ongoing memory and lifecycle work | Requires authenticated Unix socket, peer validation, protocol versioning, rate limits, and recovery tooling | One always-running identity concentrates permission and increases exposure | Provider crashes can affect control plane; launchd restart and database recovery required | Daemon becomes synchronization and migration owner | Separate stable service identity, launchd plist, install/uninstall, notarization, upgrades |
| Signed per-domain helpers | Spawned or service-managed per domain | Requires narrow versioned IPC and caller authentication for each helper | Best permission isolation, but more prompts and identities for operators to understand | Strong domain isolation; more binaries and upgrade failure modes | Must choose one archive writer and coordinate migrations | Every helper needs stable identifiers, signing, notarization, installation, and continuity validation |
| Delegate external provider CLIs | External lifecycle and cadence | JSON subprocess contract, version/capability negotiation, bounded timeouts, and path trust | Permissions belong to the external tool, reducing this binary's grants but expanding supply-chain trust | Failures isolated by process; operator must repair external install/version | External tool owns source archive unless an explicit import adapter preserves evidence | External publisher owns identity; this project verifies versions and provenance |

## Proposed decision

Keep the signed on-demand CLI as the required product and archive owner. Daemon mode remains a non-goal. Scheduled refresh uses launchd or another local orchestrator to invoke bounded CLI commands; it does not introduce a resident `icloud-cli` service.

Per-domain helpers are not implemented. A future provider may propose one only when measured TCC blast-radius reduction outweighs additional identities, IPC, packaging, and recovery costs. Such an issue must define one archive writer, authenticated local IPC, stable identifiers, install/uninstall behavior, and permission-continuity evidence.

External provider CLIs may be optional, versioned integrations when they offer a supported capability this project should not reproduce. They never silently replace an internal provider, and imported records retain external provenance. No external delegation is required for the current provider set.

The default remains local-only and read-only. Any send, react, mutate, control, or other action process requires a separate issue, namespace, authorization design, audit contract, and permission boundary.

## Current provider classification

This table classifies the implemented read path, not the Apple application's underlying storage. `sourceKind` and provider ids come from `icloud-cli.providers.v1`; explicit public-framework exceptions reflect the EventKit and PhotoKit provider PRs.

| Classification | Providers | Notes |
| --- | --- | --- |
| Public Apple framework | `photos`, `reminders` | PhotoKit and EventKit are primary; explicit degraded fallbacks remain separately labeled. |
| Filesystem/plist | `account`, `backup`, `devices`, `drive`, `family`, `focus`, `handoff`, `shortcuts`, `storage`, `tags`, `wallet` | Read ordinary metadata files, preference plists, or bounded directory state. |
| Private-store fallback | `books`, `calendar`, `contacts`, `findmy`, `freeform`, `health`, `home`, `mail`, `maps`, `messages`, `music`, `news`, `notes`, `safari`, `stocks`, `voice-memos`, `weather` | Version/schema checked and read-only; mixed Safari surfaces are classified by their most sensitive fallback. |
| Delegated integration | None | Optional future adapters require version and provenance contracts. |
| Unsupported | None in the manifest | Missing or incompatible stores fail closed at runtime rather than becoming an untracked provider. |

When a provider migrates to a public framework or delegation adapter, its manifest capability and this classification must change in the same PR. A generated classification field should be considered in the next provider-manifest schema revision so docs cannot drift from runtime discovery.

## Consequences

- Operators install and grant permissions to one stable product, but can minimize blast radius by using only needed providers.
- No background listener, socket authentication surface, privileged helper, or new persistent lifecycle is added.
- Archive migrations and retention stay in one codebase.
- A hung provider is bounded by command budgets and exits with its process.
- Helper or daemon proposals remain possible, but must prove their narrower boundary and operational cost rather than arriving as incidental implementation details.

## Approval gate

This ADR becomes accepted only after non-author product, architecture, and security approval. Until then, existing behavior and the daemon non-goal remain authoritative.
