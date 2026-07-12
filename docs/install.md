# Install and upgrade

The supported distribution is the signed, notarized, stapled universal macOS DMG attached to each GitHub release. Verify its adjacent SHA-256 file, mount it, and copy `icloud-cli` to a stable path such as `/usr/local/bin/icloud-cli`. Keeping the path and Developer ID designated requirement stable is required for macOS privacy-permission continuity.

For upgrades, verify the new checksum and replace the executable atomically at the same path. Do not strip or re-sign it. Run `codesign --verify --strict /usr/local/bin/icloud-cli` and `spctl --assess --type execute /usr/local/bin/icloud-cli` after replacement.

Homebrew installation is deferred until OMT-Global operates a reviewed tap: a formula that rebuilds from source would lose the notarized stable identity, while a cask can install the release DMG without changing it. The future cask must reference the exact release checksum and preserve the installed path. Until then, direct DMG installation is safer than an unsigned formula.

Developers may run `ALLOW_ADHOC_SIGNING=1 make release VERSION=0.2.0` only for packaging tests. Ad-hoc output is not a distributable release and does not provide permission continuity.

See [release.md](release.md) for signing, notarization, evidence, and clean-account validation.
