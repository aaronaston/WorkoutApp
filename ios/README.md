# iOS App

Open `ios/WorkoutApp/WorkoutApp.xcodeproj` in Xcode to run the app.

## Troubleshooting

### xcodebuild warning: `DVTDeviceOperation` build number `""`
This warning can appear when Xcode enumerates paired devices that have no OS build info (for example, a disconnected Apple Watch). Remove or reconnect/update the watch in Xcode Devices, or disable automatic device discovery.

### xcodebuild warning: `IDERunDestination` supported platforms is empty
When building via CLI with `-scheme` and `-destination`, Xcode 26.2 may log this warning even though the build succeeds. Workarounds:
- Use `-target WorkoutApp -sdk iphonesimulator -configuration Debug` for CLI builds, or
- Create/share an explicit scheme in Xcode (Manage Schemes -> Shared).
