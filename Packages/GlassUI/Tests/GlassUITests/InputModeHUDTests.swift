import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct InputModeHUDTests {
    private let visible = CGRect(x: 0, y: 0, width: 1_440, height: 875)
    private let size = CGSize(width: 130, height: InputModeHUD.height)
    private let caret = CGRect(x: 400, y: 500, width: 2, height: 18)

    @Test func sitsJustBelowTheCaretFromItsLeftEdge() {
        let frame = InputModeHUD.frame(of: size, below: caret, in: visible)
        #expect(frame == CGRect(x: 400, y: 458, width: 130, height: 34))
    }

    @Test func movesAboveTheCaretWhenThereIsNoRoomBelow() {
        let low = CGRect(x: 400, y: 20, width: 2, height: 18)
        let frame = InputModeHUD.frame(of: size, below: low, in: visible)
        #expect(frame.minY == low.maxY + InputModeHUD.gap)
    }

    @Test func staysOnScreenNearTheRightEdge() {
        let nearEdge = CGRect(x: 1_430, y: 500, width: 2, height: 18)
        let frame = InputModeHUD.frame(of: size, below: nearEdge, in: visible)
        #expect(frame.maxX == visible.maxX)
        #expect(visible.contains(frame))
    }

    @Test func showsTheModeAndFadesOut() async throws {
        let hud = InputModeHUD()
        defer { hud.close() }
        hud.show(glyph: "あ", title: "かな", detail: "right ⌘", below: caret)
        #expect([hud.glyph, hud.title, hud.detail].map(\.stringValue) == ["あ", "かな", "right ⌘"])
        #expect(hud.panel.isVisible)
        #expect(hud.panel.frame.height == InputModeHUD.height)
        #expect(try await timeUntil(hud) { $0.panel.alphaValue < 1 } >= InputModeHUD.visibleFor)
        _ = try await timeUntil(hud) { !$0.panel.isVisible }
        #expect(!hud.panel.isVisible)
    }

    @Test(arguments: [Duration.zero, .milliseconds(80)])
    func aNewSwitchAsTheFadeStartsStaysUpForItsOwnTime(_ late: Duration) async throws {
        let hud = InputModeHUD()
        defer { hud.close() }
        hud.show(glyph: "あ", title: "かな", detail: "right ⌘", below: caret)
        try await Task.sleep(for: InputModeHUD.visibleFor + late)
        hud.show(glyph: "A", title: "英数", detail: "left ⌘", below: caret)
        #expect(hud.panel.isVisible)
        #expect(hud.title.stringValue == "英数")
        #expect(try await timeUntil(hud) { $0.panel.alphaValue < 1 } >= InputModeHUD.visibleFor)
    }

    private func timeUntil(
        _ hud: InputModeHUD, _ condition: (InputModeHUD) -> Bool
    ) async throws -> Duration {
        let clock = ContinuousClock()
        let start = clock.now
        while !condition(hud), start.duration(to: clock.now) < .seconds(10) {
            try await Task.sleep(for: .milliseconds(10))
        }
        return start.duration(to: clock.now)
    }
}
