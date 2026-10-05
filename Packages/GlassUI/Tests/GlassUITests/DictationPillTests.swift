import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct DictationPillTests {
    private let pill = DictationPill()

    private var shown: [NSView] {
        pill.stack.arrangedSubviews.filter { !$0.isHidden }
    }

    private var glassOnScreen: CGRect {
        pill.panel.convertToScreen(pill.glass.frame)
    }

    init() {
        pill.reducesMotion = { false }
    }

    @Test func readySaysWhichKeyToHold() {
        pill.show(.ready(hint: "hold right ⌥ to talk"), on: nil)
        defer { pill.hide() }
        #expect(shown == [pill.icon, pill.title, pill.detail])
        #expect(pill.title.stringValue == "Ready")
        #expect(pill.detail.stringValue == "hold right ⌥ to talk")
        #expect(pill.icon.contentTintColor == .labelColor)
        #expect(pill.panel.ignoresMouseEvents)
        #expect(pill.stack.accessibilityLabel() == "Ready, hold right ⌥ to talk")
    }

    @Test func listeningShowsTheDotTheMeterAndTheTime() {
        let start = ContinuousClock.now
        pill.show(.listening(since: start), on: nil)
        defer { pill.hide() }
        #expect(shown == [pill.dot, pill.meter, pill.clock])
        #expect(pill.clock.stringValue == "0:00")
        pill.hear(0.5, at: start + .milliseconds(7_400))
        #expect(pill.clock.stringValue == "0:07")
        #expect(pill.meter.levels.last == 0.5)
        #expect(pill.panel.ignoresMouseEvents)
        #expect(pill.stack.accessibilityLabel() == "Listening")
    }

    @Test func transcribingNamesTheModelOnTheMac() {
        pill.show(.transcribing(model: "Whisper Small"), on: nil)
        defer { pill.hide() }
        #expect(shown == [pill.spinner, pill.title, pill.detail])
        #expect(pill.title.stringValue == "Transcribing…")
        #expect(pill.detail.stringValue == "Whisper Small · on device")
        #expect(pill.panel.ignoresMouseEvents)
        #expect(pill.stack.accessibilityLabel() == "Transcribing, Whisper Small on device")
    }

    @Test func aNewRecordingStartsWithAQuietMeter() {
        let start = ContinuousClock.now
        pill.show(.listening(since: start), on: nil)
        defer { pill.hide() }
        pill.hear(1, at: start)
        pill.show(.listening(since: start), on: nil)
        #expect(pill.meter.levels.allSatisfy { $0 == 0 })
    }

    @Test func levelsOnlyMoveTheMeterWhileListening() {
        pill.show(.ready(hint: ""), on: nil)
        defer { pill.hide() }
        pill.hear(1)
        #expect(pill.meter.levels.allSatisfy { $0 == 0 })
    }

    @Test func aFailureOffersItsFixAndTakesTheClick() {
        var fixed = 0
        pill.onFix = { fixed += 1 }
        pill.show(.failed("Microphone not allowed", fix: "Open Settings"), on: nil)
        #expect(shown == [pill.icon, pill.title, pill.fix])
        #expect(pill.title.stringValue == "Microphone not allowed")
        #expect(pill.fix.title == "Open Settings")
        #expect(pill.icon.contentTintColor == .systemOrange)
        #expect(!pill.panel.ignoresMouseEvents)
        #expect(pill.fix.acceptsFirstMouse(for: nil))
        pill.fix.performClick(nil)
        #expect(fixed == 1)
        #expect(pill.state == nil)
        #expect(pill.panel.ignoresMouseEvents)
        pill.advance(by: 2)
        #expect(!pill.panel.isVisible)
    }

    @Test func aFailureWithoutAFixShowsNoButton() {
        pill.show(.failed("Microphone unavailable", fix: nil), on: nil)
        defer { pill.hide() }
        #expect(shown == [pill.icon, pill.title])
        #expect(pill.panel.ignoresMouseEvents)
    }

    @Test func aFailureGoesAwayOnItsOwn() async throws {
        let quick = DictationPill()
        quick.failureDuration = .milliseconds(20)
        quick.show(.failed("Microphone not allowed", fix: "Open Settings"), on: nil)
        #expect(quick.panel.isVisible)
        for _ in 0..<100 where quick.state != nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(quick.state == nil)
    }

    @Test func showingAnotherStateKeepsAFailureFromHidingIt() async throws {
        let quick = DictationPill()
        quick.failureDuration = .milliseconds(20)
        quick.show(.failed("Microphone not allowed", fix: "Open Settings"), on: nil)
        quick.show(.listening(since: .now), on: nil)
        defer { quick.hide() }
        try await Task.sleep(for: .milliseconds(80))
        #expect(quick.panel.isVisible)
    }

    @Test(.enabled(if: !NSScreen.screens.isEmpty, "Placing the pill needs a screen"))
    func floatsAtTheBottomCentreOfTheScreen() throws {
        let screen = try #require(NSScreen.screens.first)
        pill.show(.listening(since: .now), on: screen)
        defer { pill.hide() }
        pill.advance(by: 2)
        let frame = glassOnScreen
        #expect(pill.panel.isVisible)
        #expect(frame.height == 44)
        #expect(abs(frame.midX - screen.visibleFrame.midX) <= 1)
        #expect(frame.minY == screen.visibleFrame.minY + 32)
    }

    @Test(.enabled(if: !NSScreen.screens.isEmpty, "Placing the pill needs a screen"))
    func staysCentredWhenTheTimeGrowsWider() throws {
        let screen = try #require(NSScreen.screens.first)
        let start = ContinuousClock.now
        pill.show(.listening(since: start), on: screen)
        defer { pill.hide() }
        pill.advance(by: 2)
        let narrow = glassOnScreen
        pill.hear(0, at: start + .seconds(600))
        pill.advance(by: 2)
        #expect(pill.clock.stringValue == "10:00")
        #expect(glassOnScreen.width > narrow.width)
        #expect(abs(glassOnScreen.midX - narrow.midX) <= 1)
    }

    @Test(.enabled(if: !NSScreen.screens.isEmpty, "Placing the pill needs a screen"))
    func aNewStateWithoutAScreenStaysWhereThePillIs() throws {
        let screen = try #require(NSScreen.screens.first)
        pill.show(.ready(hint: "hold right ⌥ to talk"), on: screen)
        defer { pill.hide() }
        pill.advance(by: 2)
        let ready = glassOnScreen
        let canvas = pill.panel.frame
        pill.show(.listening(since: .now), on: nil)
        #expect(pill.panel.frame == canvas)
        pill.advance(by: 2)
        #expect(glassOnScreen.width < ready.width)
        #expect(abs(glassOnScreen.midX - ready.midX) <= 1)
        #expect(glassOnScreen.minY == ready.minY)
    }

    @Test(.enabled(if: !NSScreen.screens.isEmpty, "Placing the pill needs a screen"))
    func bloomsFromADropletAndCollapsesBeforeLeaving() throws {
        let screen = try #require(NSScreen.screens.first)
        pill.show(.ready(hint: "hold right ⌥ to talk"), on: screen)
        #expect(pill.panel.isVisible)
        #expect(pill.glass.frame.size == CGSize(width: 16, height: 16))
        #expect(pill.panel.alphaValue == 0)
        pill.advance(by: 2)
        #expect(
            pill.glass.frame.size
                == CGSize(width: pill.stack.fittingSize.width.rounded(.up), height: 44))
        #expect(pill.panel.alphaValue == 1)
        pill.hide()
        #expect(pill.state == nil)
        #expect(pill.panel.isVisible)
        pill.advance(by: 2)
        #expect(!pill.panel.isVisible)
        #expect(pill.glass.frame.size == CGSize(width: 16, height: 16))
    }

    @Test(.enabled(if: !NSScreen.screens.isEmpty, "Placing the pill needs a screen"))
    func reducedMotionShowsTheRestingShapeAndFades() throws {
        let screen = try #require(NSScreen.screens.first)
        pill.reducesMotion = { true }
        pill.show(.listening(since: .now), on: screen)
        defer { pill.hide() }
        #expect(pill.glass.frame.height == 44)
        #expect(pill.panel.alphaValue == 0)
        pill.advance(by: 0.05)
        #expect(pill.panel.alphaValue > 0)
        pill.advance(by: 2)
        #expect(pill.panel.alphaValue == 1)
        let listening = pill.glass.frame.width
        pill.show(.ready(hint: "hold right ⌥ to talk"), on: nil)
        #expect(pill.glass.frame.width > listening)
        #expect(pill.stack.layer?.animation(forKey: kCATransition) != nil)
    }

    @Test(.enabled(if: !NSScreen.screens.isEmpty, "Placing the pill needs a screen"))
    func aWiderStateWidensTheCanvasAroundTheSameCentre() throws {
        let screen = try #require(NSScreen.screens.first)
        pill.show(.listening(since: .now), on: screen)
        defer { pill.hide() }
        let canvas = pill.panel.frame
        pill.show(.failed("Microphone not allowed", fix: "Open Settings"), on: nil)
        #expect(pill.panel.frame.width > canvas.width)
        #expect(abs(pill.panel.frame.midX - canvas.midX) <= 1)
        let transition = pill.stack.layer?.animation(forKey: kCATransition) as? CATransition
        #expect(transition?.type == .fade)
        pill.advance(by: 2)
        #expect(pill.panel.frame.contains(glassOnScreen))
    }

    @Test func theClockCountsMinutesAndSeconds() {
        #expect(DictationPill.clock(.zero) == "0:00")
        #expect(DictationPill.clock(.milliseconds(59_999)) == "0:59")
        #expect(DictationPill.clock(.seconds(61)) == "1:01")
        #expect(DictationPill.clock(.seconds(3_725)) == "62:05")
    }

    @Test func theMeterKeepsTheLoudestLevelOfEachStep() {
        let meter = LevelMeter()
        let start = ContinuousClock.now
        meter.add(0.2, at: start)
        meter.add(0.9, at: start + .milliseconds(40))
        meter.add(0.1, at: start + .milliseconds(80))
        #expect(meter.levels.suffix(1) == [0.2])
        meter.add(0.3, at: start + LevelMeter.step)
        #expect(meter.levels.suffix(2) == [0.2, 0.9])
        #expect(meter.levels.count == LevelMeter.count)
    }

    @Test func theMeterScrollsOldLevelsOff() {
        let meter = LevelMeter()
        let start = ContinuousClock.now
        for index in 0...LevelMeter.count {
            meter.add(Double(index) / 100, at: start + LevelMeter.step * index)
        }
        #expect(meter.levels.first == 0.01)
        #expect(meter.levels.last == 0.12)
    }

    @Test func barsRunFromAStubToTheFullHeight() {
        #expect(LevelMeter.height(for: 0) == 6)
        #expect(LevelMeter.height(for: 0.5) == 15)
        #expect(LevelMeter.height(for: 1) == 24)
        #expect(LevelMeter.height(for: 2) == 24)
        #expect(LevelMeter().intrinsicContentSize == NSSize(width: 69, height: 24))
    }
}
