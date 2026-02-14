#!/bin/bash
set -euo pipefail

APP_NAME="InputSoundSwitcher"
DOWNLOAD_URL="https://github.com/michlo23/InputSoundSwitcher/releases/latest/download/${APP_NAME}.app.zip"
TMP_DIR=$(mktemp -d)

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

echo "Downloading ${APP_NAME}..."
curl -fsSL "$DOWNLOAD_URL" -o "$TMP_DIR/${APP_NAME}.app.zip"

echo "Installing to /Applications..."
unzip -q "$TMP_DIR/${APP_NAME}.app.zip" -d "$TMP_DIR"
rm -rf "/Applications/${APP_NAME}.app"
cp -r "$TMP_DIR/${APP_NAME}.app" /Applications/

echo ""
echo "Done! Run with:"
echo "  open /Applications/${APP_NAME}.app"
echo ""
echo "On first launch, macOS may block it. Go to:"
echo "  System Settings > Privacy & Security > click 'Open Anyway'"
