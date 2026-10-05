import AppKit
import Carbon.HIToolbox
import Foundation
import Testing

@testable import GlassUI

@MainActor
@Suite struct LoupeKeysTests {
    @Test func startsWithVimKeysAlongsideTheArrows() {
        let keys = LoupeKeys()
        #expect(keys.preset == .vim)
        #expect(keys.hint == "arrows or HJKL")
        #expect(keys.input(for: kVK_ANSI_H) == .nudged(across: -1, down: 0))
        #expect(keys.input(for: kVK_ANSI_J) == .nudged(across: 0, down: 1))
        #expect(keys.input(for: kVK_ANSI_K) == .nudged(across: 0, down: -1))
        #expect(keys.input(for: kVK_ANSI_L) == .nudged(across: 1, down: 0))
        #expect(keys.input(for: kVK_LeftArrow) == .nudged(across: -1, down: 0))
        #expect(keys.input(for: kVK_Return) == .picked)
        #expect(keys.input(for: kVK_Escape) == .cancelled)
        #expect(keys.input(for: kVK_ANSI_A) == nil)
    }

    @Test func presetsSwapTheLettersAndOffKeepsOnlyTheArrows() {
        var keys = LoupeKeys()
        keys.choose(.wasd)
        #expect(keys.preset == .wasd)
        #expect(keys.hint == "arrows or WASD")
        #expect(keys.input(for: kVK_ANSI_W) == .nudged(across: 0, down: -1))
        #expect(keys.input(for: kVK_ANSI_H) == nil)
        keys.choose(.ijkl)
        #expect(keys.input(for: kVK_ANSI_J) == .nudged(across: -1, down: 0))
        keys.choose(.off)
        #expect(keys.preset == .off)
        #expect(keys.hint == "arrow keys")
        #expect(keys.input(for: kVK_ANSI_J) == nil)
        #expect(keys.input(for: kVK_DownArrow) == .nudged(across: 0, down: 1))
        keys.choose(.vim)
        #expect(keys.input(for: kVK_ANSI_J) == .nudged(across: 0, down: 1))
    }

    @Test func assigningAKeyMakesTheSetCustom() {
        var keys = LoupeKeys()
        keys.choose(.off)
        #expect(keys.assign(kVK_ANSI_E, to: .top) == nil)
        #expect(keys.isEnabled)
        #expect(keys.preset == nil)
        #expect(keys.hint == "arrows or EHJL")
        #expect(keys.input(for: kVK_ANSI_E) == .nudged(across: 0, down: -1))
        #expect(keys.input(for: kVK_ANSI_K) == nil)
        #expect(keys.label(of: .top) == "E")
    }

    @Test func reservedAndRepeatedKeysAreRefused() {
        var keys = LoupeKeys()
        #expect(keys.assign(kVK_Return, to: .top) == "Return picks the colour.")
        #expect(keys.assign(kVK_ANSI_KeypadEnter, to: .top) == "Return picks the colour.")
        #expect(keys.assign(kVK_Escape, to: .top) == "Esc cancels the picker.")
        #expect(keys.assign(kVK_UpArrow, to: .top) == "The arrow keys always work.")
        #expect(keys.assign(kVK_ANSI_J, to: .top) == "J already moves down.")
        #expect(keys == LoupeKeys())
        #expect(keys.assign(kVK_ANSI_K, to: .top) == nil)
    }

    @Test func savedKeysRoundTripAndMissingFieldsFallBack() throws {
        var keys = LoupeKeys()
        keys.choose(.wasd)
        let data = try JSONEncoder().encode(keys)
        #expect(try JSONDecoder().decode(LoupeKeys.self, from: data) == keys)
        #expect(try JSONDecoder().decode(LoupeKeys.self, from: Data("{}".utf8)) == LoupeKeys())
        let off = try JSONDecoder().decode(LoupeKeys.self, from: Data(#"{"isEnabled":false}"#.utf8))
        #expect(off.preset == .off)
    }

    @Test func theEditorShowsTheKeysAndReportsAcceptedChanges() throws {
        let editor = LoupeKeysEditor()
        #expect(editor.caps[.left]?.letter == "H")
        var changes: [LoupeKeys] = []
        editor.onChange = { changes.append($0) }
        editor.keys.choose(.wasd)
        #expect(editor.caps[.top]?.letter == "W")
        #expect(editor.caps[.right]?.isDimmed == false)
        #expect(changes.isEmpty)
        try #require(editor.caps[.left]).onKey?(kVK_ANSI_Q)
        #expect(editor.caps[.left]?.letter == "Q")
        #expect(changes.map { $0[.left] } == [kVK_ANSI_Q])
        try #require(editor.caps[.bottom]).onKey?(kVK_Return)
        #expect(changes.count == 1)
        #expect(editor.note.stringValue == "Return picks the colour.")
        editor.keys.choose(.off)
        #expect(editor.caps[.top]?.isDimmed == true)
        #expect(editor.note.stringValue.hasPrefix("Click a key"))
    }
}
