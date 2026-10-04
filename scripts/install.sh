#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
app=/Applications/Mado.app
xcodegen generate --quiet
xcodebuild build -project Mado.xcodeproj -scheme Mado -configuration Release -destination generic/platform=macOS -derivedDataPath build -quiet
pkill -f "$app/" || true
while pgrep -f "$app/" >/dev/null; do sleep 0.1; done
rm -rf "$app"
cp -R build/Build/Products/Release/Mado.app "$app"
open "$app"
