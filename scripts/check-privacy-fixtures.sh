#!/usr/bin/env bash
set -euo pipefail

fixture_root="${1:-Tests/Fixtures}"

if [[ ! -d "$fixture_root" ]]; then
  echo "No fixture directory found at $fixture_root."
  exit 0
fi

failed=0

while IFS= read -r -d '' file; do
  if grep -E -n '(/Users/|~/Library/|file://|CloudTabs\.db|chat\.db)' "$file" >/dev/null 2>&1; then
    echo "Privacy-sensitive local path or database reference found in fixture: $file" >&2
    failed=1
  fi

  while IFS= read -r url; do
    case "$url" in
      http://example.com|https://example.com|http://example.org|https://example.org|http://example.net|https://example.net)
        ;;
      http://example.com/*|https://example.com/*|http://example.org/*|https://example.org/*|http://example.net/*|https://example.net/*)
        ;;
      http://www.apple.com/DTDs/PropertyList-1.0.dtd|https://www.apple.com/DTDs/PropertyList-1.0.dtd)
        ;;
      *)
        echo "Non-synthetic fixture URL found in $file: $url" >&2
        failed=1
        ;;
    esac
  done < <(grep -E -o 'https?://[^<>"[:space:]]+' "$file" || true)
done < <(find "$fixture_root" -type f -print0)

exit "$failed"
