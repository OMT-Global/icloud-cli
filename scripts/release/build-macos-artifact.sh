#!/bin/bash
set -euo pipefail

version="${1:?usage: build-macos-artifact.sh VERSION [OUTPUT_DIR]}"
output_dir="${2:-dist}"
identifier="com.omtglobal.icloud-cli"
sign_identity="${SIGN_IDENTITY:-}"

if [[ "$output_dir" = /* || "$output_dir" == *".."* || "$output_dir" == "." || -z "$output_dir" ]]; then
  echo "output directory must be a safe relative path" >&2
  exit 2
fi

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "version must be semantic x.y.z" >&2
  exit 2
fi
if [[ -z "$sign_identity" && "${ALLOW_ADHOC_SIGNING:-0}" != "1" ]]; then
  echo "SIGN_IDENTITY must name a Developer ID Application identity" >&2
  exit 2
fi
sign_identity="${sign_identity:--}"

rm -rf "$output_dir"
mkdir -p "$output_dir" "$output_dir/stage"
swift build -c release --arch arm64 --scratch-path .build/release-arm64 --product icloud-cli
swift build -c release --arch x86_64 --scratch-path .build/release-x86_64 --product icloud-cli
lipo -create .build/release-arm64/arm64-apple-macosx/release/icloud-cli .build/release-x86_64/x86_64-apple-macosx/release/icloud-cli -output "$output_dir/stage/icloud-cli"
chmod 0755 "$output_dir/stage/icloud-cli"
sign_args=(--force --options runtime --identifier "$identifier" --sign "$sign_identity")
if [[ "$sign_identity" != "-" ]]; then sign_args+=(--timestamp); fi
codesign "${sign_args[@]}" "$output_dir/stage/icloud-cli"
codesign --verify --strict --verbose=2 "$output_dir/stage/icloud-cli"
lipo "$output_dir/stage/icloud-cli" -verify_arch arm64 x86_64
cp README.md LICENSE "$output_dir/stage/"

artifact="$output_dir/icloud-cli-$version-macos-universal.dmg"
hdiutil create -quiet -fs HFS+ -volname "iCloud CLI $version" -srcfolder "$output_dir/stage" "$artifact"
dmg_sign_args=(--force --sign "$sign_identity")
if [[ "$sign_identity" != "-" ]]; then dmg_sign_args+=(--timestamp); fi
codesign "${dmg_sign_args[@]}" "$artifact"

if [[ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
  xcrun notarytool submit "$artifact" --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" --wait
elif [[ -n "${APPLE_API_KEY_ID:-}" && -n "${APPLE_API_ISSUER_ID:-}" && -n "${APPLE_API_KEY_FILE:-}" ]]; then
  xcrun notarytool submit "$artifact" --key "$APPLE_API_KEY_FILE" --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_ISSUER_ID" --wait
elif [[ "${REQUIRE_NOTARIZATION:-0}" == "1" ]]; then
  echo "notarization credentials are required" >&2
  exit 2
else
  echo "warning: artifact signed but not notarized" >&2
fi

if [[ -n "${NOTARY_KEYCHAIN_PROFILE:-}${APPLE_API_KEY_ID:-}" ]]; then
  xcrun stapler staple "$artifact"
  xcrun stapler validate "$artifact"
fi
shasum -a 256 "$artifact" > "$artifact.sha256"
codesign -d -r- "$output_dir/stage/icloud-cli" 2> "$output_dir/designated-requirement.txt"
rm -rf "$output_dir/stage"
printf '%s\n' "$artifact"
