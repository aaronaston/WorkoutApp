# iOS App

Open `ios/WorkoutApp/WorkoutApp.xcodeproj` in Xcode to run the app.

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

## Troubleshooting

### xcodebuild warning: `DVTDeviceOperation` build number `""`
This warning can appear when Xcode enumerates paired devices that have no OS build info (for example, a disconnected Apple Watch). Remove or reconnect/update the watch in Xcode Devices, or disable automatic device discovery.

### xcodebuild warning: `IDERunDestination` supported platforms is empty
When building via CLI with `-scheme` and `-destination`, Xcode 26.2 may log this warning even though the build succeeds. Workarounds:
- Use `-scheme WorkoutApp -sdk iphonesimulator -configuration Debug` for CLI builds.
- If simulator destination resolution is flaky, select a concrete available simulator by UDID.
