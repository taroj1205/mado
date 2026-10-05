#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
if [ -z "${MADO_BUILD_LOCKED:-}" ]; then
  git_dir=$(git rev-parse --git-common-dir)
  export MADO_BUILD_LOCKED=1
  exec lockf -k "$git_dir/mado-build.lock" scripts/install.sh "$@"
fi
app=/Applications/Mado.app
arch=$([ "$(sysctl -n hw.optional.arm64 2>/dev/null)" = 1 ] && echo arm64 || echo x86_64)
xcodegen generate --quiet
xcodebuild build -project Mado.xcodeproj -scheme Mado -configuration Release -destination generic/platform=macOS -derivedDataPath build ARCHS="$arch" LM_SKIP_METADATA_EXTRACTION=YES -quiet
pkill -x Mado || true
while pgrep -x Mado >/dev/null; do sleep 0.1; done
rm -rf "$app"
cp -R build/Build/Products/Release/Mado.app "$app"
open "$app"
