# iOS App

Open `ios/WorkoutApp/WorkoutApp.xcodeproj` in Xcode to run the app.

## Release Archive Workflow (Xcode/CI)

The release archive pipeline is defined in:

- `scripts/ci-archive-release.sh`
- `docs/release/ios-watch-release-archive.md`

It archives the shared `WorkoutApp` scheme in `Release` configuration using automatic signing with an Apple Distribution certificate and App Store Connect API key.

## Physical iPhone Setup

For this project (current branch), signing for a physical iPhone is blocked until a development team is selected in Xcode.

1. Connect your iPhone and trust this Mac on the device.
2. Open `ios/WorkoutApp/WorkoutApp.xcodeproj` in Xcode.
3. Select target `WorkoutApp` -> Signing & Capabilities.
4. Set:
   - Team: your Apple Developer team
   - Signing Certificate: `Apple Development`
   - Bundle Identifier: `ca.twisted-pair.WorkoutApp`
5. If prompted, let Xcode manage the provisioning profile automatically.
6. Select your iPhone as run destination and press Run.

Notes:
- The test target bundle ID is `ca.twisted-pair.WorkoutAppTests`.
- This repo currently has iOS app + tests targets only; no watchOS target is present in the Xcode project.
- When watchOS targets are added, include them in the shared `WorkoutApp` scheme so one archive contains both phone and watch binaries.

## Troubleshooting

### xcodebuild warning: `DVTDeviceOperation` build number `""`
This warning can appear when Xcode enumerates paired devices that have no OS build info (for example, a disconnected Apple Watch). Remove or reconnect/update the watch in Xcode Devices, or disable automatic device discovery.

### xcodebuild warning: `IDERunDestination` supported platforms is empty
When building via CLI with `-scheme` and `-destination`, Xcode 26.2 may log this warning even though the build succeeds. Workarounds:
- Use `-scheme WorkoutApp -sdk iphonesimulator -configuration Debug` for CLI builds.
- If simulator destination resolution is flaky, select a concrete available simulator by UDID.

### Simulator architecture policy
Simulator builds in this project are arm64-only by default. x86_64 is excluded in project build settings for `iphonesimulator` SDK.

Recommended CLI test command:

```bash
xcodebuild -project ios/WorkoutApp/WorkoutApp.xcodeproj \
  -scheme WorkoutApp \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=<SIMULATOR_UDID>' \
  test
```
