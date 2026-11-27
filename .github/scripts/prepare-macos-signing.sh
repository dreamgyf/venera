#!/usr/bin/env bash

# Never trace certificate/password arguments, even if invoked with bash -x.
set +x
set -euo pipefail
umask 077

: "${GITHUB_ENV:?GITHUB_ENV is required}"
certificate=${CERTIFICATE:-}
certificate_password=${CERTIFICATE_PASSWORD:-}

if [[ -z "$certificate" && -z "$certificate_password" ]]; then
  printf '%s\n' \
    'FLUTTER_XCODE_CODE_SIGN_IDENTITY=-' \
    'FLUTTER_XCODE_CODE_SIGN_STYLE=Manual' \
    'FLUTTER_XCODE_CODE_SIGNING_ALLOWED=YES' \
    'MACOS_ARTIFACT_SUFFIX=-adhoc' >> "$GITHUB_ENV"
  echo 'macOS: building an ad hoc signed package without a Developer ID certificate.'
  exit 0
fi

if [[ -z "$certificate" || -z "$certificate_password" ]]; then
  echo '::error::Set both CERTIFICATE and CERTIFICATE_PASSWORD, or leave both empty.' >&2
  exit 1
fi

: "${RUNNER_TEMP:?RUNNER_TEMP is required}"
signing_dir=$(mktemp -d "$RUNNER_TEMP/venera-signing.XXXXXX")
certificate_path="$signing_dir/certificate.p12"
keychain_path="$signing_dir/signing.keychain-db"

cleanup() {
  local status=$?
  rm -f "$certificate_path"
  if [[ $status -ne 0 ]]; then
    security delete-keychain "$keychain_path" >/dev/null 2>&1 || true
    rmdir "$signing_dir" 2>/dev/null || true
  fi
}
trap cleanup EXIT

printf '%s' "$certificate" | base64 --decode > "$certificate_path"
keychain_password=$(openssl rand -hex 32)
security create-keychain -p "$keychain_password" "$keychain_path"
security set-keychain-settings -lut 21600 "$keychain_path"
security unlock-keychain -p "$keychain_password" "$keychain_path"
security import "$certificate_path" -k "$keychain_path" \
  -P "$certificate_password" -t cert -f pkcs12 -T /usr/bin/codesign >/dev/null
security set-key-partition-list -S apple-tool:,apple:,codesign: \
  -s -k "$keychain_password" "$keychain_path" >/dev/null

identity_output=$(security find-identity -v -p codesigning "$keychain_path")
identities=()
while IFS= read -r identity; do
  [[ -z "$identity" ]] || identities+=("$identity")
done < <(printf '%s\n' "$identity_output" | awk \
  '$2 ~ /^[[:xdigit:]]+$/ && length($2) == 40 { print $2 }')
if [[ ${#identities[@]} -ne 1 ]]; then
  echo '::error::The certificate must contain exactly one valid code-signing identity.' >&2
  exit 1
fi

# Hosted runners are isolated; make the imported identity visible to Xcode.
security list-keychains -d user -s "$keychain_path"
printf '%s\n' \
  "FLUTTER_XCODE_CODE_SIGN_IDENTITY=${identities[0]}" \
  'FLUTTER_XCODE_CODE_SIGN_STYLE=Manual' \
  'FLUTTER_XCODE_CODE_SIGNING_ALLOWED=YES' \
  'MACOS_ARTIFACT_SUFFIX=' \
  "MACOS_SIGNING_KEYCHAIN=$keychain_path" >> "$GITHUB_ENV"
echo 'macOS: using the configured code-signing identity.'
