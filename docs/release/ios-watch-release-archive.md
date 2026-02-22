# iPhone + Watch Release Archive Workflow

This document defines the Apple-approved release archive path for TestFlight/App Store uploads.

## Scope

- Source of truth: `ios/WorkoutApp/WorkoutApp.xcodeproj`
- Shared scheme: `WorkoutApp` (`xcshareddata/xcschemes/WorkoutApp.xcscheme`)
- Build configuration: `Release`
- Archive destination: `generic/platform=iOS`

If watchOS app/extension targets are included in the shared scheme, they are signed and archived in the same iOS archive.

## Signing Model

- Signing style: Automatic (`CODE_SIGN_STYLE=Automatic`)
- Team: from `APPLE_TEAM_ID`
- Certificate: Apple Distribution certificate imported in CI keychain
- Provisioning: generated/updated by Xcode via `-allowProvisioningUpdates`
- Authentication: App Store Connect API key (`.p8`, key ID, issuer ID)

This supports iPhone and Watch targets under the same team without manual profile mapping in CI.

## Local Archive Command

```bash
APPLE_TEAM_ID=<team-id> \
APP_STORE_CONNECT_KEY_PATH=/path/to/AuthKey_XXXX.p8 \
APP_STORE_CONNECT_KEY_ID=<key-id> \
APP_STORE_CONNECT_ISSUER_ID=<issuer-id> \
scripts/ci-archive-release.sh
```

Optional strict check for watch targets:

```bash
REQUIRE_WATCH_TARGETS=true scripts/ci-archive-release.sh
```

## CI Workflow

- File: `.github/workflows/ios-release-archive.yml`
- Trigger: manual (`workflow_dispatch`)
- Inputs:
  - `scheme` (default `WorkoutApp`)
  - `require_watch_targets` (default `false`)
- Artifacts:
  - `.xcarchive` bundle
  - exported app-store payload (`.ipa` / export metadata)

## Required CI Secrets

- `APPLE_TEAM_ID`
- `APP_STORE_CONNECT_KEY_BASE64`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `IOS_DISTRIBUTION_CERT_BASE64`
- `IOS_DISTRIBUTION_CERT_PASSWORD`
