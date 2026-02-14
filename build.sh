#!/bin/bash
set -euo pipefail

APP_NAME="InputSoundSwitcher"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "Building ${APP_NAME} (release)..."
swift build -c release 2>&1

echo "Creating app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

# Copy executable
cp "${BUILD_DIR}/${APP_NAME}" "${MACOS_DIR}/"

# Create full Info.plist for the app bundle
cat > "${CONTENTS_DIR}/Info.plist" << 'EOF'
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
EOF

echo "Installing to /Applications..."
rm -rf "/Applications/${APP_BUNDLE}"
cp -r "${APP_BUNDLE}" /Applications/

echo ""
echo "Done! Installed to /Applications/${APP_BUNDLE}"
echo ""
echo "To run:"
echo "  open /Applications/${APP_BUNDLE}"
