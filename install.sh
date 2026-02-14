#!/bin/bash
set -euo pipefail

APP_NAME="InputSoundSwitcher"
REPO="https://github.com/michlo23/InputSoundSwitcher.git"
TMP_DIR=$(mktemp -d)

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

echo "Cloning ${APP_NAME}..."
git clone --depth 1 "$REPO" "$TMP_DIR" 2>/dev/null

echo "Building (this may take a minute on first run)..."
cd "$TMP_DIR"
swift build -c release 2>&1 | tail -1

echo "Installing to /Applications..."
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
mkdir -p "${CONTENTS_DIR}/MacOS" "${CONTENTS_DIR}/Resources"
cp "${BUILD_DIR}/${APP_NAME}" "${CONTENTS_DIR}/MacOS/"

cat > "${CONTENTS_DIR}/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>InputSoundSwitcher</string>
    <key>CFBundleDisplayName</key>
    <string>InputSoundSwitcher</string>
    <key>CFBundleIdentifier</key>
    <string>com.michlo23.InputSoundSwitcher</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleExecutable</key>
    <string>InputSoundSwitcher</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>InputSoundSwitcher needs access to manage audio input devices.</string>
</dict>
</plist>
PLIST

rm -rf "/Applications/${APP_BUNDLE}"
cp -r "${APP_BUNDLE}" /Applications/

echo ""
echo "Installed! Run with:"
echo "  open /Applications/${APP_BUNDLE}"
