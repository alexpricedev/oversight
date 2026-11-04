#!/usr/bin/env bash
# Build a Release copy of Oversight and install it into /Applications.
#
# Usage: Scripts/install.sh
#
# Builds whatever is checked out right now; pull first if you want the latest
# main. Quits a running Oversight before replacing it, then opens the new copy.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Oversight"
DEST="/Applications/${APP_NAME}.app"
BUILT="build/Build/Products/Release/${APP_NAME}.app"

echo "Building ${APP_NAME} (Release) from $(git rev-parse --short HEAD)..."
xcodebuild \
  -project Oversight.xcodeproj \
  -scheme Oversight \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath build \
  -quiet \
  build

if [[ ! -d "$BUILT" ]]; then
  echo "Build finished but $BUILT is missing." >&2
  exit 1
fi

if pgrep -x "$APP_NAME" >/dev/null; then
  echo "Quitting the running ${APP_NAME}..."
  osascript -e "tell application \"${APP_NAME}\" to quit" || true
  for _ in {1..20}; do
    pgrep -x "$APP_NAME" >/dev/null || break
    sleep 0.5
  done
  if pgrep -x "$APP_NAME" >/dev/null; then
    echo "${APP_NAME} is still running. Quit it and run this script again." >&2
    exit 1
  fi
fi

# Copy next to the destination first, so a failed copy never leaves
# /Applications without a working app.
STAGING="/Applications/.${APP_NAME}.app.installing"
rm -rf "$STAGING"
ditto "$BUILT" "$STAGING"
rm -rf "$DEST"
mv "$STAGING" "$DEST"

echo "Installed ${DEST}"
open "$DEST"
