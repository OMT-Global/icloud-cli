#!/usr/bin/env bash
set -euo pipefail

bash scripts/check-detect-secrets.sh --all-files
bash scripts/check-privacy-fixtures.sh
swift test
swift build
