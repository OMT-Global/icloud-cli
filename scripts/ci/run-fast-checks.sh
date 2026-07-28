#!/usr/bin/env bash
set -euo pipefail

bash scripts/ci/check-ci-policy.sh
bash scripts/ci/check-shell-syntax.sh
bash scripts/check-detect-secrets.sh --all-files
bash scripts/check-privacy-fixtures.sh
bash scripts/ci/check-release-contract.sh
swift test
bash scripts/ci/test-coverage-indicators.sh
bash scripts/ci/check-coverage.sh
bash scripts/ci/run-mutation-smoke.sh
swift build
swift build -c release
swift run icloud-cli --help
