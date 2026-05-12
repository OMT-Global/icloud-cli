# Bootstrap Governance Audit

`project.bootstrap.yaml` is the control plane for repo governance. The manifest keeps `CI Gate` as the intended required status check:

```yaml
github:
  requiredStatusChecks:
    - CI Gate
```

## Live State As Of 2026-05-12

The repository is public and live branch protection is available on `main`.

Verified settings:

- Repository visibility: `PUBLIC`.
- Delete branch on merge: enabled.
- Issues and Projects: enabled.
- Branch protection: enabled for `main`.
- Required status check: `CI Gate`.
- Required reviews: 1 approval.
- Code owner reviews: required.
- Last-push approval: required.
- Stale review dismissal: enabled.
- Linear history: required.
- Conversation resolution: required.

## Fallback Merge-Readiness Policy

If GitHub plan limits or a temporary GitHub API limitation make branch protection or protected environments unavailable, do not claim protected enforcement is active. Use this fallback policy until live settings can be applied and verified:

- `CI Gate` passes or is explicitly documented as intentionally skipped.
- Non-author approval is present when required by the repo governance contract.
- Code owner review requirements are satisfied where applicable.
- Review conversations are resolved.
- No blocking requested-changes review remains.
- The PR body records the plan-limit or API limitation evidence.
- A maintainer performs the final merge manually.

Once the repo is public or the org plan changes, rerun the audit command and bootstrap plan before relying on fallback policy.

## Audit Command

```sh
scripts/audit-github-settings.sh
```

The command prints repository features and branch-protection settings for `OMT-Global/icloud-cli` on `main`. Pass a repo and branch to audit another target:

```sh
scripts/audit-github-settings.sh OMT-Global/icloud-cli main
```

## Checklist After Bootstrap Changes

Run:

```sh
node ~/src/omt-global/bootstrap/dist/cli.js plan --manifest ./project.bootstrap.yaml --target .
scripts/audit-github-settings.sh
```

Confirm:

- The plan still names `CI Gate` as the intended required status check.
- The live branch protection API shows `CI Gate` in required checks.
- Required review count, code-owner review, last-push approval, stale-review dismissal, linear history, and conversation resolution match the manifest.
- Environments are handled by bootstrap when the plan and GitHub plan support them.
