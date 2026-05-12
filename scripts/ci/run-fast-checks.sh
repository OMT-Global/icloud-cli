#!/usr/bin/env bash
set -euo pipefail

bash scripts/ci/check-ci-policy.sh
bash scripts/ci/check-shell-syntax.sh
bash scripts/check-detect-secrets.sh --all-files
bash scripts/check-privacy-fixtures.sh
swift test
swift build
swift build -c release
swift run icloud-cli --help
