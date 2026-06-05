#!/bin/bash
# Build and run FullEngagement in the iOS Simulator — no Xcode GUI needed.
# Usage:
#   ./run.sh            build, install, launch in the simulator
#   ./run.sh check      compile only (fastest — just catches errors, no simulator)
set -euo pipefail

PROJECT="FullEngagement.xcodeproj"
SCHEME="FullEngagement"
BUNDLE_ID="AS.FullEngagement"
DEVICE="iPhone 17 Pro"

# --- compile-only mode: fastest feedback, no simulator -----------------------
if [[ "${1:-}" == "check" ]]; then
  xcodebuild build \
    -project "$PROJECT" -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,name=$DEVICE" \
    -quiet
  echo "✅ Compiles."
  exit 0
fi

# --- full run loop -----------------------------------------------------------
echo "▶︎ Booting ${DEVICE}…"
open -a Simulator
xcrun simctl boot "$DEVICE" 2>/dev/null || true   # ignore "already booted"

echo "▶︎ Building…"
# Use Xcode's default DerivedData so builds are incremental (fast, low disk)
# and shared with the Xcode GUI. (Previously this used a fresh `mktemp -d` per
# run, which rebuilt from scratch every time and never got cleaned up — that
# filled the disk.)
DEST="platform=iOS Simulator,name=$DEVICE"
xcodebuild build -project "$PROJECT" -scheme "$SCHEME" -destination "$DEST" -quiet

# Ask the build system where it put the .app.
APP_PATH="$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -destination "$DEST" \
  -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/ TARGET_BUILD_DIR =/{d=$2} / FULL_PRODUCT_NAME =/{n=$2} END{print d"/"n}')"
echo "▶︎ Installing $APP_PATH"
xcrun simctl install "$DEVICE" "$APP_PATH"

echo "▶︎ Launching…"
xcrun simctl launch "$DEVICE" "$BUNDLE_ID"
echo "✅ Running in the simulator."
