#!/bin/bash
set -e

echo "Building binaries..."
swift build

echo "Copying Helper to expected SMAppService location..."
APP_DIR=".build/debug/MacNTFS.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
HELPERS_DIR="$CONTENTS_DIR/Library/LaunchServices"
DAEMONS_DIR="$CONTENTS_DIR/Library/LaunchDaemons"

mkdir -p "$MACOS_DIR"
mkdir -p "$HELPERS_DIR"
mkdir -p "$DAEMONS_DIR"

cp .build/debug/MacNTFS "$MACOS_DIR/"
cp .build/debug/MacNTFSHelper "$HELPERS_DIR/com.macntfs.Helper"
cp Sources/MacNTFSHelper/Resources/com.macntfs.Helper.plist "$DAEMONS_DIR/"

echo "Signing binaries locally to test XPC..."
codesign -s - -f --entitlements Sources/MacNTFS/Resources/MacNTFS.entitlements "$MACOS_DIR/MacNTFS"
codesign -s - -f --entitlements Sources/MacNTFSHelper/Resources/MacNTFSHelper.entitlements "$HELPERS_DIR/com.macntfs.Helper"

echo "Done! You can manually test the UI and install the daemon by running:"
echo "$MACOS_DIR/MacNTFS"
