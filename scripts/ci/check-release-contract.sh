#!/bin/bash
set -euo pipefail

grep -Fq 'public static let version = "0.2.0"' Sources/ICloudCLICore/CommandLine.swift
grep -Fq 'release:' project.bootstrap.yaml
grep -Fq 'enabled: true' project.bootstrap.yaml
grep -Fq 'com.omtglobal.icloud-cli' scripts/release/build-macos-artifact.sh
grep -Fq 'notarytool submit' scripts/release/build-macos-artifact.sh
grep -Fq 'stapler staple' scripts/release/build-macos-artifact.sh
grep -Fq 'macos-14' .github/workflows/release.yml
grep -Fq 'Developer ID Application' docs/release.md
grep -Fq 'permission continuity' docs/release.md
