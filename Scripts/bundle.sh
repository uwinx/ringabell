#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BINARY="${PROJECT_DIR}/.build/release/ringabell"
APP_BUNDLE="${PROJECT_DIR}/ringabell.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS="${CONTENTS}/MacOS"

if [ ! -f "$BINARY" ]; then
    echo "Error: Binary not found at ${BINARY}" >&2
    echo "Run 'swift build -c release' first." >&2
    exit 1
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS"

cp "$BINARY" "$MACOS/ringabell"
chmod +x "$MACOS/ringabell"

cat > "${CONTENTS}/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>ringabell</string>
    <key>CFBundleIdentifier</key>
    <string>com.ringabell.cli</string>
    <key>CFBundleName</key>
    <string>ringabell</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

RESOURCES="${CONTENTS}/Resources"
mkdir -p "$RESOURCES"
swift "${SCRIPT_DIR}/generate-icon.swift" "🎉" "$RESOURCES"

codesign --force --sign - "$MACOS/ringabell"
codesign --force --sign - "$APP_BUNDLE"
echo "Created ${APP_BUNDLE}"
