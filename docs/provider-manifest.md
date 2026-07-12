# Provider capability manifest

`icloud-cli providers list --format json` emits the static capability contract used by local agents and control planes to discover Apple-data providers without parsing help text or probing private stores.

The top-level object has this shape:

```json
{
  "schemaVersion": "icloud-cli.providers.v1",
  "providers": []
}
```

Each provider declares:

- `id`: stable lowercase provider identifier.
- `displayName`: operator-facing name.
- `maturity`: `stable`, `beta`, or `experimental`.
- `sourceKind`: `preferences`, `filesystem`, `sqlite`, or `mixed`.
- `accessMode`: currently always `read-only`.
- `sensitivity`: `low`, `moderate`, or `high`.
- `permissionExpectations`: generic macOS permission expectations, never live authorization state.
- `commands`: deterministically ordered CLI command paths owned by the provider.
- `capabilities`: deterministically ordered discovery keywords.
- `defaultPolling`: whether the provider is safe and suitable for the default local polling set.

The registry is static: it contains no payload records, account identifiers, user paths, permission probes, or other machine-local state. `--format text` renders the same fields for operators.

## External control-plane projection

`icloud-cli providers external-manifest --format json` embeds this exact registry in the `providerManifest` field of `icloud-cli.openclaw.external.v1`. The projection adds action-class policy only; it does not repeat per-provider command metadata. See [the OpenClaw control-plane contract](openclaw-skill-contract.md) for wrapper, confirmation, redaction, timeout, retention, and structured-error requirements.

## Compatibility policy

Within `icloud-cli.providers.v1`, provider `id` values and existing field meanings are stable. New providers, commands, capabilities, maturity values, and optional fields may be added without changing the schema version. Consumers must ignore unknown fields and enum values and must not rely on array position beyond the documented deterministic ordering.

Removing or renaming a provider id, removing a required field, or changing a field's meaning requires a new schema identifier. During a schema transition, the CLI should keep the preceding schema available long enough for local control-plane consumers to migrate.
