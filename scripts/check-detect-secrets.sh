#!/usr/bin/env bash
set -euo pipefail

mode="${1:---all-files}"

files=()
if [[ "$mode" == "--staged" ]]; then
  while IFS= read -r -d '' file; do
    files+=("$file")
  done < <(git diff --cached --name-only --diff-filter=ACMR -z)
else
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    while IFS= read -r -d '' file; do
      files+=("$file")
    done < <(git ls-files -z)
  fi

  if [[ ${#files[@]} -eq 0 ]]; then
    while IFS= read -r -d '' file; do
      files+=("$file")
    done < <(find . -type f -print0)
  fi
fi

patterns=(
  'ghp_'
  'github_pat_'
  'sk-live-'
  'sk-proj-'
  'AKIA[0-9A-Z]{16}'
  'BEGIN (RSA|OPENSSH|EC) PRIVATE KEY'
  'OPENAI_API_KEY='
  'SUDO_PASS='
  'BW_SESSION='
)

failed=0
for file in "${files[@]+"${files[@]}"}"; do
  [[ -f "$file" ]] || continue
  case "$file" in
    ./.build/*|.build/*|.git/*|./scripts/check-detect-secrets.sh|scripts/check-detect-secrets.sh)
      continue
      ;;
  esac

  for pattern in "${patterns[@]}"; do
    if grep -E -n "$pattern" "$file" >/dev/null 2>&1; then
      echo "Potential secret pattern '$pattern' found in $file" >&2
      failed=1
    fi
  done
done

exit "$failed"
