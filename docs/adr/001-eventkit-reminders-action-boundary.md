# ADR 001: EventKit Reminders and the action boundary

Status: accepted

## Context

Reminders data is sensitive and Apple's private on-disk schema changes between macOS releases. Read-only inventory should use the supported EventKit API. Private-store access remains useful for explicit recovery and compatibility diagnostics, but must not be the normal path.

## Decision

- `reminders list` and `reminders lists` use EventKit by default and never request access implicitly.
- `reminders authorization` reports the current EventKit state without triggering a prompt.
- Operators may select the read-only, schema-checked private-store reader with `--degraded-private-store`. This path may require Full Disk Access and is not suitable for unattended default polling.
- Smart views (`flagged`, `today`, `scheduled`, and `assigned`) remain private-store compatibility commands until equivalent supported behavior is implemented. Their output is read-only and version/schema checked.
- This issue adds no mutation capability.

## Future actions

Any future Reminders mutation belongs under a separate `actions reminders` namespace and requires a new decision and implementation issue. That work must provide:

1. a dry-run default that describes the intended mutation;
2. explicit confirmation bound to the proposed operation;
3. a structured, locally retained audit record with reminder content redacted by default;
4. least-privilege EventKit authorization and a clear denied/restricted failure;
5. bounded execution and stable identifiers where EventKit supplies them.

EventKit does not provide transactions or guaranteed rollback across iCloud synchronization. A create may be compensatable by deleting the created identifier; an update may retain a best-effort preimage; and completion may be reversible while the identifier remains available. None of these are guaranteed rollback. The CLI must disclose that limit before confirmation and must not claim atomic recovery.

## Consequences

Supported reads become more resilient to macOS schema changes and permission diagnostics distinguish Reminders authorization from Full Disk Access. Some private smart-list concepts remain explicitly degraded until supported API semantics are defined.
