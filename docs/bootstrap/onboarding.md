# Repository onboarding

This repository is a Swift macOS CLI using the generic-polyglot bootstrap archetype. Before merging, confirm `project.bootstrap.yaml` still names OMT-Global, requires `CI Gate`, one non-author CODEOWNER approval, auto-merge, and the hybrid-safe runner policy.

Shell-safe PR checks may use the public shell-only runner labels. Release jobs require Xcode, codesign, notarytool, and hdiutil and therefore run on GitHub-hosted `macos-14`, never the shell-only runner.

The `release` environment must require maintainer approval and contain only the secret names documented in [release.md](../release.md). Never place certificates, private keys, notarization credentials, or exported keychains in the repository or portable Codex profiles.
