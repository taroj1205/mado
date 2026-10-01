import AppCore
import Testing

@testable import InputKit

@Suite struct SystemShortcutConflictsTests {
    static let commandSpace = Shortcut(keyCode: 49, modifiers: .command)
    static let optionCommandSpace = Shortcut(keyCode: 49, modifiers: [.command, .option])

    @Test func defaultsReportSpotlightAndFinderSearch() {
        #expect(
            SystemShortcutConflicts.conflict(for: Self.commandSpace, symbolicHotKeys: [:])
                == .spotlight)
        #expect(
            SystemShortcutConflicts.conflict(for: Self.optionCommandSpace, symbolicHotKeys: [:])
                == .finderSearch)
    }

    @Test func disabledSpotlightIsNotAConflict() {
        let hotKeys: [String: Any] = [
            "64": [
                "enabled": false,
                "value": ["parameters": [32, 49, 1_048_576], "type": "standard"],
            ]
        ]
        #expect(
            SystemShortcutConflicts.conflict(for: Self.commandSpace, symbolicHotKeys: hotKeys)
                == nil)
    }

    @Test func rebindingMovesTheConflict() {
        let hotKeys: [String: Any] = [
            "64": [
                "enabled": true,
                "value": ["parameters": [65_535, 49, 1_572_864], "type": "standard"],
            ]
        ]
        #expect(
            SystemShortcutConflicts.conflict(for: Self.commandSpace, symbolicHotKeys: hotKeys)
                == nil)
        #expect(
            SystemShortcutConflicts.conflict(
                for: Self.optionCommandSpace, symbolicHotKeys: hotKeys) == .spotlight)
    }

    @Test func unrelatedShortcutHasNoConflict() {
        let shortcut = Shortcut(keyCode: 0, modifiers: .command)
        #expect(SystemShortcutConflicts.conflict(for: shortcut, symbolicHotKeys: [:]) == nil)
    }
}
