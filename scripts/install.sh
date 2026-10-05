#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
if [ -z "${MADO_BUILD_LOCKED:-}" ]; then
  git_dir=$(git rev-parse --git-common-dir)
  export MADO_BUILD_LOCKED=1
  exec lockf -k "$git_dir/mado-build.lock" scripts/install.sh "$@"
fi
app=/Applications/Mado.app
xcodegen generate --quiet
xcodebuild build -project Mado.xcodeproj -scheme Mado -configuration Release -destination generic/platform=macOS -derivedDataPath build -quiet
pkill -x Mado || true
while pgrep -x Mado >/dev/null; do sleep 0.1; done
rm -rf "$app"
cp -R build/Build/Products/Release/Mado.app "$app"
open "$app"
