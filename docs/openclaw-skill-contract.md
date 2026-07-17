# OpenClaw provider control-plane contract

`icloud-cli` is a local, read-only Mac node tool. OpenClaw integrations discover the available Apple-data providers from a versioned external manifest, then invoke bounded actions. The contract does not grant remote access, create a daemon, or retain payload data outside the operator's Mac.

## Discovery

```sh
icloud-cli providers external-manifest --format json
```

The command returns `icloud-cli.openclaw.external.v1`. Its `providerManifest` is the exact [`icloud-cli.providers.v1`](provider-manifest.md) registry emitted by `icloud-cli providers list`; integration code must use that embedded registry rather than maintaining another command list. The `actions` array defines the default command, availability, local-only boundary, confirmation rule, redaction mode, timeout, retention, and structured wrapper-error shape for every action class.

The registry and external manifest are static metadata. They contain no account identifiers, user paths, authorization results, payload records, or permission-probe output.

## Action wrappers

Wrappers must use argument arrays, not a shell string assembled from model output. They must run only on the same Mac where the operator has installed `icloud-cli`, enforce the manifest timeout, and replace a failed CLI invocation with a local structured error:

```json
{
  "schemaVersion": "structured-action-error-v1",
  "action": "doctor",
  "code": "command-failed",
  "retryable": false,
  "message": "Permission diagnosis could not read one or more local sources."
}
```

Never include raw home-directory paths, command payloads, or stderr in that error. Use a stable local code such as `command-failed`, `timed-out`, `confirmation-required`, or `unavailable` and keep any diagnostic detail in a local operator view.

| Action | Wrapper command or behavior | Gate and output boundary |
| --- | --- | --- |
| `discover` | `icloud-cli providers list --format json` | No confirmation. Metadata only; do not cache remotely. |
| `status` | `icloud-cli snapshot --redaction safe --format json` | No confirmation. Return the safe summary only; discard it after the local status response unless the operator exports it. |
| `doctor` | `icloud-cli permissions doctor --format json` | No confirmation. Source readiness only; redact local paths in UI/logs. |
| `sync` | Currently `unavailable` | Do not emulate sync or cache arbitrary command output. It activates only when the resumable archive contract lands. |
| `query` | Select a command from `providerManifest.providers[].commands` | Explicit operator confirmation for every moderate/high-sensitivity provider and for any CLI `--confirm-sensitive` flag. Do not infer permission from discovery. |

The external manifest is authoritative for the command source and action availability. A wrapper must return `unavailable` for a disabled action instead of guessing a future command.

### Minimal wrapper examples

```sh
# Discovery (metadata only)
icloud-cli providers external-manifest --format json

# Safe local status
icloud-cli snapshot --redaction safe --format json

# Permission diagnosis without reading payload data
icloud-cli permissions doctor --format json
```

A query wrapper first loads `providerManifest`, validates that the selected command path belongs to the requested provider, asks the operator for confirmation where the action says it is required, and then invokes exactly that argument array. For example, the retained Safari path remains available after confirmation:

```sh
icloud-cli safari tabs --format json
```

Safari tab URLs and titles are sensitive. A wrapper must present a redacted local summary by default and only return full raw JSON to an explicitly confirmed local consumer. It must not send that data to a remote planner or log sink.

## Retention and export

- All actions are local-only. No wrapper may upload provider output, error text, or source paths by default.
- Keep status/doctor response data only for the duration of the local request. Query output has the provider's own retention policy and is not a permission to create a general archive.
- Remote export is an explicit, separately named operator action with a destination and a redaction preview. It is outside this contract.
- `sync` remains unavailable until its archive issue supplies cursor, retention, deletion, and migration semantics. Search actions remain unavailable until the federated-search issue lands.

## CrawlBar-compatible mapping

The manifest can be adapted to a CrawlBar-style external tool declaration without a menu-bar process:

| External control-plane field | CrawlBar-style mapping |
| --- | --- |
| `schemaVersion` | External tool contract version |
| `providerManifest.providers` | Discoverable provider catalogue and provider-scoped query choices |
| `actions[].command` | Bounded executable argument array |
| `actions[].availability` | Tool enabled/disabled state |
| `confirmation`, `redaction`, `timeoutSeconds`, `retention` | Invocation policy and local execution limits |
| `errorShape` | Normalized local tool failure envelope |

This mapping is intentionally process-neutral: OpenClaw or another local controller can invoke the CLI directly. It does not require a menu-bar app, a persistent helper, a launchd service, or a privileged IPC channel.

## Compatibility

`icloud-cli.openclaw.external.v1` is additive within its major schema: consumers must ignore unknown fields and actions. Changing an action's safety boundary, removing an existing action, or changing the embedded provider-manifest semantics requires a new schema identifier and a migration period.
