# Mado

Native macOS launcher (AppKit only, no SwiftUI). Plan: see the "Mado — AppKit 実装プランとマイルストーン" doc.

## M0-01: project and local packages

    brew install xcodegen swiftlint
    xcodegen generate
    open Mado.xcodeproj

Debug builds are signed with a local certificate named `Mado Development`, so the Accessibility grant survives rebuilds. Create it once per Mac in Keychain Access: Certificate Assistant, Create a Certificate, name `Mado Development`, type Code Signing.

To use Mado day to day, run `scripts/install.sh` from an up-to-date `main`. It builds Release, quits the copy in `/Applications`, replaces it and opens the new one. Turn on Launch at Login in that copy's Settings once. Release reads `settings.json` and keeps its own clipboard history, separate from Debug builds. Run the script again to update.

To run a Debug build from a worktree next to another Mado, launch it without its hotkeys and open its launcher with a signal instead. The build writes `Mado.ready` next to `Mado.app` once it handles the signal; until then the signal quits it. It also starts with keyboard features paused, so right ⌥, Caps Lock, snippets and other keys reach only the other Mado. To try them in this build, uncheck Pause Keyboard Features in its menu bar icon.

    xcodebuild build -project Mado.xcodeproj -scheme Mado -derivedDataPath build
    rm -f build/Build/Products/Debug/Mado.ready
    open -n build/Build/Products/Debug/Mado.app --args -MadoNoHotKey YES
    until [ -e build/Build/Products/Debug/Mado.ready ]; do sleep 0.1; done
    pkill -USR1 -f "$PWD/build/Build/Products/Debug/"

To let a script drive that launcher while you keep typing in another app, also pass `-MadoNoFocus YES`. The launcher then opens without taking focus, and keys the script posts to the Mado process with `CGEvent.postToPid` reach it as if typed there: the query, arrows, ↵, ⌘↵, ⌘K and Esc, including inside the action panel. Keys posted to `.cghidEventTap` still go to the app you are typing in.

Tests: `xcodebuild test -project Mado.xcodeproj -scheme Mado -destination 'platform=macOS'` runs the app and package tests in one build, which is what CI runs. A single package also runs with `swift test` from its directory.

Branches and commits start with the goal ID, e.g. `M0-01-xcode-project`.

Commit messages follow Conventional Commits with a required scope (`type(scope): summary`), enforced by `.githooks/commit-msg`. Enable it once per clone:

    git config core.hooksPath .githooks

Format with `swift format -i -r App Packages Tests`. The pre-commit hook runs `swift format lint --strict` and `swiftlint lint --strict`; CI runs the same, and every warning is an error.
