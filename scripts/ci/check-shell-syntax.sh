#!/usr/bin/env bash
set -euo pipefail

failed=0

while IFS= read -r -d '' file; do
  if ! bash -n "$file"; then
    failed=1
  fi
done < <(git ls-files -z '*.sh')

exit "$failed"
