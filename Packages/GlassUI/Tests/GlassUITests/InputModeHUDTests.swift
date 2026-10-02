import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct InputModeHUDTests {
    private let visible = CGRect(x: 0, y: 0, width: 1_440, height: 875)
    private let size = CGSize(width: 130, height: InputModeHUD.height)

    @Test func sitsJustBelowTheCaretFromItsLeftEdge() {
        let caret = CGRect(x: 400, y: 500, width: 2, height: 18)
        let frame = InputModeHUD.frame(of: size, below: caret, in: visible)
        #expect(frame == CGRect(x: 400, y: 458, width: 130, height: 34))
    }

    @Test func movesAboveTheCaretWhenThereIsNoRoomBelow() {
        let caret = CGRect(x: 400, y: 20, width: 2, height: 18)
        let frame = InputModeHUD.frame(of: size, below: caret, in: visible)
        #expect(frame.minY == caret.maxY + InputModeHUD.gap)
    }

    @Test func staysOnScreenNearTheRightEdge() {
        let caret = CGRect(x: 1_430, y: 500, width: 2, height: 18)
        let frame = InputModeHUD.frame(of: size, below: caret, in: visible)
        #expect(frame.maxX == visible.maxX)
        #expect(visible.contains(frame))
    }

    @Test func showsTheModeAndFadesOut() async throws {
        let hud = InputModeHUD()
        defer { hud.close() }
        hud.show(
            glyph: "あ", title: "かな", detail: "right ⌘",
            below: CGRect(x: 400, y: 500, width: 2, height: 18))
        #expect([hud.glyph, hud.title, hud.detail].map(\.stringValue) == ["あ", "かな", "right ⌘"])
        #expect(hud.panel.isVisible)
        #expect(hud.panel.frame.height == InputModeHUD.height)
        try await Task.sleep(for: InputModeHUD.visibleFor + .seconds(1))
        #expect(!hud.panel.isVisible)
    }

    @Test func aNewSwitchKeepsTheHUDUp() async throws {
        let hud = InputModeHUD()
        defer { hud.close() }
        let caret = CGRect(x: 400, y: 500, width: 2, height: 18)
        hud.show(glyph: "あ", title: "かな", detail: "right ⌘", below: caret)
        try await Task.sleep(for: InputModeHUD.visibleFor)
        hud.show(glyph: "A", title: "英数", detail: "left ⌘", below: caret)
        try await Task.sleep(for: InputModeHUD.visibleFor / 2)
        #expect(hud.panel.isVisible)
        #expect(hud.panel.alphaValue == 1)
        #expect(hud.title.stringValue == "英数")
    }

    @Test func aSwitchDuringTheFadeBringsTheHUDBack() async throws {
        let hud = InputModeHUD()
        defer { hud.close() }
        let caret = CGRect(x: 400, y: 500, width: 2, height: 18)
        hud.show(glyph: "あ", title: "かな", detail: "right ⌘", below: caret)
        try await Task.sleep(for: InputModeHUD.visibleFor + .milliseconds(80))
        hud.show(glyph: "A", title: "英数", detail: "left ⌘", below: caret)
        try await Task.sleep(for: .milliseconds(300))
        #expect(hud.panel.isVisible)
        #expect(hud.panel.alphaValue == 1)
    }
}
