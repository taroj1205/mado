import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite(.enabled(if: !NSScreen.screens.isEmpty, "Showing the pill needs a screen"))
struct DictationPillTests {
    private let pill = DictationPill()

    @Test func readyFloatsBottomCentreWithTheHint() throws {
        let screen = try #require(NSScreen.screens.first)
        pill.showReady(on: screen)
        defer { pill.hide() }
        #expect(pill.panel.isVisible)
        #expect(pill.state == .ready)
        #expect(pill.stack.views == [pill.icon, pill.title, pill.detail])
        #expect(pill.title.stringValue == "Ready")
        #expect(pill.detail.stringValue == "hold right ⌥ to talk")
        #expect(pill.panel.ignoresMouseEvents)
        #expect(pill.panel.frame.height == 44)
        #expect(pill.panel.frame.minY == screen.visibleFrame.minY + 32)
        #expect(abs(pill.panel.frame.midX - screen.visibleFrame.midX) <= 1)
    }

    @Test func listeningShowsTheDotTheMeterAndTheTime() throws {
        pill.showReady(on: try #require(NSScreen.screens.first))
        defer { pill.hide() }
        pill.listen(level: 1, elapsed: .milliseconds(7_900))
        #expect(pill.state == .listening)
        #expect(pill.stack.views == [pill.dot, pill.meter, pill.time])
        #expect(pill.time.stringValue == "0:07")
        #expect(pill.meter.heights.last == 24)
        #expect(pill.panel.contentView?.accessibilityLabel() == "Listening, 0:07")
        #expect(pill.panel.ignoresMouseEvents)
    }

    @Test func showingReadyAgainClearsTheMeter() throws {
        let screen = try #require(NSScreen.screens.first)
        pill.showReady(on: screen)
        defer { pill.hide() }
        pill.listen(level: 1, elapsed: .zero)
        pill.hide()
        pill.showReady(on: screen)
        #expect(pill.meter.heights.allSatisfy { $0 == 6 })
    }

    @Test func aFailureSaysWhatWentWrongAndOffersAFix() throws {
        pill.showReady(on: try #require(NSScreen.screens.first))
        defer { pill.hide() }
        var fixed: [DictationPill.Problem] = []
        pill.onFix = { fixed.append($0) }
        pill.fail(.notAllowed)
        #expect(pill.isFailed)
        #expect(pill.stack.views == [pill.icon, pill.title, pill.fix])
        #expect(pill.title.stringValue == "Microphone not allowed")
        #expect(pill.fix.title == "Open Settings")
        #expect(!pill.panel.ignoresMouseEvents)
        pill.fix.performClick(nil)
        #expect(fixed == [.notAllowed])
        #expect(!pill.panel.isVisible)
        #expect(pill.state == nil)
    }

    @Test func anUnavailableMicrophoneHasItsOwnMessage() throws {
        pill.showReady(on: try #require(NSScreen.screens.first))
        defer { pill.hide() }
        pill.fail(.unavailable)
        #expect(pill.title.stringValue == "Microphone not available")
    }
}
