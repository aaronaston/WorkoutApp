#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/ios-sim.sh [build|test|run] [--device-name "<name>"] [--device-id <udid>]

Defaults:
  command: run
  device-name: iPhone 16

Examples:
  scripts/ios-sim.sh
  scripts/ios-sim.sh run --device-name "iPhone 16 Pro"
  scripts/ios-sim.sh test --device-id 2C32766E-60FE-4ED0-9A62-6F3F772DAFCC
USAGE
}

command="run"
device_name="iPhone 16"
device_id=""

if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
  usage
  exit 0
fi

if [[ ${1:-} =~ ^(build|test|run)$ ]]; then
  command="$1"
  shift
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --device-name)
      device_name="${2:-}"
      shift 2
      ;;
    --device-id)
      device_id="${2:-}"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$device_id" ]]; then
  device_id=$(
    xcrun simctl list devices available -j \
      | jq -r --arg name "$device_name" '
          [
            .devices
            | to_entries[]
            | .key as $runtime
            | .value[]
            | select(.isAvailable == true and .name == $name)
            | {udid: .udid, runtime: $runtime}
          ]
          | sort_by(.runtime)
          | reverse
          | .[0].udid // empty
        '
  )
fi

if [[ -z "$device_id" ]]; then
  echo "No available simulator found." >&2
  echo "Try specifying --device-id or --device-name." >&2
  exit 1
fi

destination="platform=iOS Simulator,id=$device_id,arch=arm64"
project="ios/WorkoutApp/WorkoutApp.xcodeproj"
scheme="WorkoutApp"
bundle_id="ca.twisted-pair.WorkoutApp"

boot_simulator() {
  xcrun simctl boot "$device_id" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$device_id" -b
  open -a Simulator
}

build_app() {
  xcodebuild \
    -project "$project" \
    -scheme "$scheme" \
    -destination "$destination" \
    ONLY_ACTIVE_ARCH=YES \
    EXCLUDED_ARCHS="x86_64" \
    build
}

test_app() {
  xcodebuild \
    -project "$project" \
    -scheme "$scheme" \
    -destination "$destination" \
    ONLY_ACTIVE_ARCH=YES \
    EXCLUDED_ARCHS="x86_64" \
    test
}

install_and_launch() {
  local app_path
  app_path=$(find ~/Library/Developer/Xcode/DerivedData/WorkoutApp-*/Build/Products/Debug-iphonesimulator -maxdepth 1 -name 'WorkoutApp.app' | head -n 1)
  if [[ -z "$app_path" ]]; then
    echo "Built app not found under DerivedData. Run build first." >&2
    exit 1
  fi
  xcrun simctl install "$device_id" "$app_path"
  xcrun simctl launch "$device_id" "$bundle_id"
}

boot_simulator

case "$command" in
  build)
    build_app
    ;;
  test)
    test_app
    ;;
  run)
    build_app
    install_and_launch
    ;;
esac
