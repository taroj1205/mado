# Mado

Native macOS launcher (AppKit only, no SwiftUI). Plan: see the "Mado — AppKit 実装プランとマイルストーン" doc.

## M0-01: project and local packages

    brew install xcodegen swiftlint
    xcodegen generate
    open Mado.xcodeproj

Debug builds are signed with a local certificate named `Mado Development`, so the Accessibility grant survives rebuilds. Create it once per Mac in Keychain Access: Certificate Assistant, Create a Certificate, name `Mado Development`, type Code Signing.

Tests: `for p in Packages/*/; do (cd "$p" && swift test); done`, or `xcodebuild test -project Mado.xcodeproj -scheme Mado -destination 'platform=macOS'`.

Branches and commits start with the goal ID, e.g. `M0-01-xcode-project`.

Commit messages follow Conventional Commits with a required scope (`type(scope): summary`), enforced by `.githooks/commit-msg`. Enable it once per clone:

    git config core.hooksPath .githooks

Format with `swift format -i -r App Packages Tests`. The pre-commit hook runs `swift format lint --strict` and `swiftlint lint --strict`; CI runs the same, and every warning is an error.
