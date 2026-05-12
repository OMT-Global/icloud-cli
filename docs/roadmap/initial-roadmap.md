# Initial Roadmap

This roadmap is mirrored into GitHub issues after repository creation.

## 1. Bootstrap repository governance and CI

- Keep `project.bootstrap.yaml` as the control plane.
- Require `CI Gate` for PRs.
- Run `swift build`, `swift test`, and the repo secret scan in the fast gate.

## 2. Ship `icloud-cli safari tabs`

- Read local Safari session files.
- Emit stable JSON for OpenClaw ingestion.
- Provide a text format for operator use.
- Avoid requiring live Safari data in tests.

## 3. Map cross-device iCloud Safari tab state

- Investigate `~/Library/Safari/CloudTabs.db` and related Safari sync artifacts.
- Document Full Disk Access and privacy constraints.
- Decide whether the CLI should read the database directly or expose a guarded helper.

## 4. Add OpenClaw skill integration

- Define the OpenClaw skill command contract.
- Add a sample scheduler or polling command for a MacBook OpenClaw node.
- Keep raw browsing data local unless explicitly exported by the operator.

## 5. Package and install

- Add a release build path.
- Decide whether this should publish through Homebrew, an OpenClaw tap, or a signed binary artifact.
