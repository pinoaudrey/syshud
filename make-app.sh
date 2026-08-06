#!/bin/bash
# Builds SysHUD.app into build/ from the SwiftPM release binary.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP=build/SysHUD.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/SysHUD "$APP/Contents/MacOS/SysHUD"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>SysHUD</string>
  <key>CFBundleDisplayName</key><string>SysHUD</string>
  <key>CFBundleIdentifier</key><string>com.audreypino.syshud</string>
  <key>CFBundleExecutable</key><string>SysHUD</string>
  <key>CFBundleVersion</key><string>1.0</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF

codesign --force -s - "$APP"
echo "Built $APP"
