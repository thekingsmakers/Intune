#!/bin/bash

# ==========================================
# Dropbox Installation Script for macOS
# Microsoft Intune Compatible
# ==========================================

set -e

DROPBOX_URL="https://www.dropbox.com/download?plat=mac&full=1"
DMG_FILE="/tmp/Dropbox.dmg"
MOUNT_POINT="/Volumes/Dropbox Installer"

echo "Downloading Dropbox..."

curl -L "$DROPBOX_URL" -o "$DMG_FILE"

if [ ! -f "$DMG_FILE" ]; then
    echo "Download failed."
    exit 1
fi

echo "Mounting DMG..."

hdiutil attach "$DMG_FILE" -nobrowse -quiet

sleep 5

# Find mounted volume automatically
VOLUME=$(find /Volumes -maxdepth 1 -name "Dropbox*" | head -1)

if [ -z "$VOLUME" ]; then
    echo "Unable to locate mounted installer."
    exit 1
fi

echo "Installing Dropbox..."

cp -R "$VOLUME/Dropbox.app" "/Applications/"

echo "Cleaning up..."

hdiutil detach "$VOLUME" -quiet || true
rm -f "$DMG_FILE"

echo "Launching Dropbox..."

open -a "/Applications/Dropbox.app"

echo "Dropbox installation completed successfully."

exit 0
