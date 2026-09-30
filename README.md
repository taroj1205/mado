# Mado

Native macOS launcher (AppKit only, no SwiftUI). Plan: see the "Mado — AppKit 実装プランとマイルストーン" doc.

## M0-01: project and local packages

    brew install xcodegen
    xcodegen generate
    open Mado.xcodeproj

Debug builds are signed with a local certificate named `Mado Development`, so the Accessibility grant survives rebuilds. Create it once per Mac:

    scripts/create-dev-cert.sh

After a build, check that the app starts and stays out of the Dock:

    scripts/smoke-launch.sh "$(xcodebuild -project Mado.xcodeproj -scheme Mado -showBuildSettings 2>/dev/null | awk '/ TARGET_BUILD_DIR =/{print $3}')/Mado.app"

Tests: `for p in Packages/*/; do (cd "$p" && swift test); done`, or `xcodebuild test -project Mado.xcodeproj -scheme Mado -destination 'platform=macOS'`.

Branches and commits start with the goal ID, e.g. `M0-01-xcode-project`.

Commit messages follow Conventional Commits with a required scope (`type(scope): summary`), enforced by `.githooks/commit-msg`. Enable it once per clone:

    git config core.hooksPath .githooks
