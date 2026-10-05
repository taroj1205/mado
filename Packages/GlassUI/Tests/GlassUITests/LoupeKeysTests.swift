import AppKit
import Carbon.HIToolbox
import Foundation
import Testing

@testable import GlassUI

@MainActor
@Suite struct LoupeKeysTests {
    @Test func startsWithTheArrowsOnly() {
        let keys = LoupeKeys()
        #expect(keys.preset == .arrows)
        #expect(keys.hint == "arrow keys")
        #expect(keys.label(of: .top) == "↑")
        #expect(keys.input(for: kVK_ANSI_H) == nil)
        #expect(keys.input(for: kVK_LeftArrow) == .nudged(across: -1, down: 0))
        #expect(keys.input(for: kVK_Return) == .picked)
        #expect(keys.input(for: kVK_Escape) == .cancelled)
        #expect(keys.input(for: kVK_ANSI_A) == nil)
    }

    @Test func presetsSwapTheLettersAndArrowsKeepsOnlyTheArrows() {
        var keys = LoupeKeys()
        keys.choose(.vim)
        #expect(keys.preset == .vim)
        #expect(keys.hint == "arrows or HJKL")
        #expect(keys.input(for: kVK_ANSI_H) == .nudged(across: -1, down: 0))
        #expect(keys.input(for: kVK_ANSI_J) == .nudged(across: 0, down: 1))
        #expect(keys.input(for: kVK_ANSI_K) == .nudged(across: 0, down: -1))
        #expect(keys.input(for: kVK_ANSI_L) == .nudged(across: 1, down: 0))
        keys.choose(.wasd)
        #expect(keys.preset == .wasd)
        #expect(keys.hint == "arrows or WASD")
        #expect(keys.input(for: kVK_ANSI_W) == .nudged(across: 0, down: -1))
        #expect(keys.input(for: kVK_ANSI_H) == nil)
        keys.choose(.ijkl)
        #expect(keys.input(for: kVK_ANSI_J) == .nudged(across: -1, down: 0))
        keys.choose(.arrows)
        #expect(keys.preset == .arrows)
        #expect(keys.hint == "arrow keys")
        #expect(keys.input(for: kVK_ANSI_J) == nil)
        #expect(keys.input(for: kVK_DownArrow) == .nudged(across: 0, down: 1))
        keys.choose(.vim)
        #expect(keys.input(for: kVK_ANSI_J) == .nudged(across: 0, down: 1))
    }

    @Test func assigningAKeyMakesTheSetCustom() {
        var keys = LoupeKeys()
        #expect(keys.assign(kVK_ANSI_E, to: .top) == nil)
        #expect(keys.preset == nil)
        #expect(keys.hint == "arrows or E")
        #expect(keys.input(for: kVK_ANSI_E) == .nudged(across: 0, down: -1))
        #expect(keys.input(for: kVK_UpArrow) == .nudged(across: 0, down: -1))
        #expect(keys.label(of: .top) == "E")
        #expect(keys.assign(kVK_UpArrow, to: .top) == nil)
        #expect(keys.preset == .arrows)
    }

    @Test func reservedAndRepeatedKeysAreRefused() {
        var keys = LoupeKeys()
        keys.choose(.vim)
        #expect(keys.assign(kVK_Return, to: .top) == "Return picks the colour.")
        #expect(keys.assign(kVK_ANSI_KeypadEnter, to: .top) == "Return picks the colour.")
        #expect(keys.assign(kVK_Escape, to: .top) == "Esc cancels the picker.")
        #expect(keys.assign(kVK_LeftArrow, to: .top) == "The arrow keys always work.")
        #expect(keys.assign(kVK_ANSI_J, to: .top) == "J already moves down.")
        #expect(keys.preset == .vim)
        #expect(keys.assign(kVK_ANSI_K, to: .top) == nil)
    }

    @Test func savedKeysRoundTripAndMissingFieldsFallBack() throws {
        var keys = LoupeKeys()
        keys.choose(.wasd)
        let data = try JSONEncoder().encode(keys)
        #expect(try JSONDecoder().decode(LoupeKeys.self, from: data) == keys)
        #expect(try JSONDecoder().decode(LoupeKeys.self, from: Data("{}".utf8)) == LoupeKeys())
    }

    @Test func theEditorShowsTheKeysAndReportsAcceptedChanges() throws {
        let editor = LoupeKeysEditor()
        #expect(editor.caps[.left]?.letter == "←")
        var changes: [LoupeKeys] = []
        editor.onChange = { changes.append($0) }
        editor.keys.choose(.wasd)
        #expect(editor.caps[.top]?.letter == "W")
        #expect(changes.isEmpty)
        try #require(editor.caps[.left]).onKey?(kVK_ANSI_Q)
        #expect(editor.caps[.left]?.letter == "Q")
        #expect(changes.map { $0[.left] } == [kVK_ANSI_Q])
        try #require(editor.caps[.bottom]).onKey?(kVK_Return)
        #expect(changes.count == 1)
        #expect(editor.note.stringValue == "Return picks the colour.")
        editor.keys.choose(.arrows)
        #expect(editor.caps[.top]?.letter == "↑")
        try #require(editor.caps[.top]).onKey?(kVK_ANSI_E)
        #expect(editor.keys.preset == nil)
        #expect(editor.note.stringValue.hasPrefix("Click a key"))
    }
}
