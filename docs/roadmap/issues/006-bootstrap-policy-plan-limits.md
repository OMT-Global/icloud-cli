## Problem / intent

Bootstrap GitHub provisioning succeeded for repo settings, labels, and environments, but GitHub plan limits blocked protected branches and protected environment rules while the repository is private.

## Acceptance criteria

- Record the exact fallback merge-readiness policy in repo docs.
- Recheck whether branch protection becomes available if the repo is made public or the org plan changes.
- Keep `CI Gate` as the intended required status check in `project.bootstrap.yaml`.
- Add a small audit command or checklist for verifying live repo settings after bootstrap changes.

## Validation commands

```sh
node ~/src/omt-global/bootstrap/dist/cli.js plan --manifest ./project.bootstrap.yaml --target .
gh repo view OMT-Global/icloud-cli --json nameWithOwner,visibility,deleteBranchOnMerge,hasIssuesEnabled,hasProjectsEnabled
```

## Notes

- Do not claim branch protection is active until live GitHub state confirms it.
