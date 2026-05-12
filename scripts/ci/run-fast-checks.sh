#!/usr/bin/env bash
set -euo pipefail

bash scripts/check-detect-secrets.sh --all-files
swift test
swift build
