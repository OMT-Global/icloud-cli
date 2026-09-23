# Signed release operations

Release artifacts are universal macOS DMGs containing a hardened-runtime binary with identifier `com.omtglobal.icloud-cli`. Production signing uses the same Developer ID Application certificate for every release. The workflow notarizes the DMG, staples and validates its ticket, publishes a checksum, and records the designated requirement without exposing credentials or private test data.

The protected `release` environment needs these secrets: `APPLE_DEVELOPER_ID_P12_BASE64`, `APPLE_DEVELOPER_ID_P12_PASSWORD`, `APPLE_BUILD_KEYCHAIN_PASSWORD`, `APPLE_DEVELOPER_ID_APPLICATION`, `APPLE_NOTARY_API_KEY_BASE64`, `APPLE_NOTARY_KEY_ID`, and `APPLE_NOTARY_ISSUER_ID`. They are not currently configured; the first production run is blocked until a maintainer adds them.

## Permission continuity evidence

Stable-path permission continuity is a release gate, not an assumption.

Before publishing the first production tag, use a clean macOS test account or VM:

1. Install v0.2.0 at the final path and record `codesign -d -r-`, `spctl --assess`, and `stapler validate` output.
2. Grant Photos and Reminders access through normal system prompts and record only authorization states, never payloads.
3. Replace the binary at the same path with the next candidate signed by the same Developer ID identity.
4. Confirm the designated requirement is unchanged and both providers retain authorization without another prompt.
5. Attach the redacted command transcript and macOS version to the GitHub release.

Local verification found `Developer ID Application: John TenEyck (TFGKTMNSZV)`, but its private key was unavailable to noninteractive `codesign` (`errSecInternalComponent`). The universal DMG, checksum, and architecture path passed with an explicitly non-distributable ad-hoc signature. Production Developer ID signing, clean-account TCC continuity, and Apple notarization have not yet been completed. A release must not be described as validated until that evidence is attached.

## GitHub security decision

Branch protection currently enforces `CI Gate`, one CODEOWNER approval, stale-review dismissal, last-push approval, and administrators.

Secret scanning, secret-scanning push protection, Dependabot alerts, and Dependabot security updates are enabled on the repository (toggled 2026-09-23; exact API evidence recorded on issue #98). These were the protections required before adding release credentials, so that precondition is now met.

Two flags remain disabled because they require GitHub Advanced Security, which is not licensed for this repository or organization: `secret_scanning_validity_checks` and `secret_scanning_non_provider_patterns`. A `PATCH` to `security_and_analysis` setting either to `enabled` returns HTTP 200 but leaves the status `disabled` (silently ignored, no error body). Enabling them later is an organization plan and licensing decision, not a repository-level toggle.

Because those two premium flags are unavailable, retain the existing repository secret-pattern gate (`scripts/check-detect-secrets.sh`, run by `scripts/ci/run-fast-checks.sh`) and do not weaken release-environment approval. If GHAS becomes available, enable validity checks and non-provider patterns and update this section.

No daemon or privileged helper is introduced for signing. The executable's stable identity and install path solve this release requirement independently of the execution-model decision in issue #83.

The proposed [execution-model ADR](adr/001-execution-model.md) keeps this signed executable as the only required product. Any future helper needs its own stable identity and permission-continuity validation; it cannot inherit this binary's release evidence.
