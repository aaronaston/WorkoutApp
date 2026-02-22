#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="${ROOT_DIR}/ios/WorkoutApp/WorkoutApp.xcodeproj"
SCHEME="${SCHEME:-WorkoutApp}"
CONFIGURATION="${CONFIGURATION:-Release}"
TEAM_ID="${APPLE_TEAM_ID:?APPLE_TEAM_ID is required}"

KEY_PATH="${APP_STORE_CONNECT_KEY_PATH:-}"
KEY_ID="${APP_STORE_CONNECT_KEY_ID:-}"
ISSUER_ID="${APP_STORE_CONNECT_ISSUER_ID:-}"

ARCHIVE_ROOT="${RUNNER_TEMP:-${ROOT_DIR}/build}/archives"
EXPORT_ROOT="${RUNNER_TEMP:-${ROOT_DIR}/build}/export"
ARCHIVE_PATH="${ARCHIVE_ROOT}/${SCHEME}.xcarchive"
EXPORT_OPTIONS_PATH="${EXPORT_ROOT}/ExportOptions.plist"

mkdir -p "${ARCHIVE_ROOT}" "${EXPORT_ROOT}"

PROJECT_TARGETS="$(xcodebuild -list -project "${PROJECT_PATH}" | sed -n '/Targets:/,/Build Configurations:/p')"
if [[ "${REQUIRE_WATCH_TARGETS:-false}" == "true" ]] && ! grep -Eiq 'watch' <<<"${PROJECT_TARGETS}"; then
  echo "Expected watchOS targets in the Xcode project, but none were found."
  exit 1
fi

cat > "${EXPORT_OPTIONS_PATH}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>app-store</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>teamID</key>
  <string>${TEAM_ID}</string>
  <key>destination</key>
  <string>export</string>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>uploadSymbols</key>
  <true/>
</dict>
</plist>
EOF

ARCHIVE_ARGS=(
  -project "${PROJECT_PATH}"
  -scheme "${SCHEME}"
  -configuration "${CONFIGURATION}"
  -destination "generic/platform=iOS"
  -archivePath "${ARCHIVE_PATH}"
  -allowProvisioningUpdates
  DEVELOPMENT_TEAM="${TEAM_ID}"
  CODE_SIGN_STYLE=Automatic
)

if [[ -n "${KEY_PATH}" && -n "${KEY_ID}" && -n "${ISSUER_ID}" ]]; then
  ARCHIVE_ARGS+=(
    -authenticationKeyPath "${KEY_PATH}"
    -authenticationKeyID "${KEY_ID}"
    -authenticationKeyIssuerID "${ISSUER_ID}"
  )
fi

xcodebuild archive "${ARCHIVE_ARGS[@]}"

xcodebuild -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportPath "${EXPORT_ROOT}" \
  -exportOptionsPlist "${EXPORT_OPTIONS_PATH}"

echo "Archive: ${ARCHIVE_PATH}"
echo "Export: ${EXPORT_ROOT}"
