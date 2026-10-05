import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct StatusBarFadeTests {
    private let bar = StatusBar()
    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 300, height: 60),
        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private let container = NSView()

    private var clip: NSClipView { bar.contentView }

    private var alphas: [CGFloat?] {
        let colors = bar.edges.colors as? [CGColor] ?? []
        return [colors.first?.alpha, colors.last?.alpha]
    }

    init() {
        panel.contentView = container
        container.addSubview(bar)
        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            bar.topAnchor.constraint(equalTo: container.topAnchor),
        ])
    }

    private func show(_ count: Int, last: String? = nil) {
        bar.pills = (0..<count).map { index in
            StatusBar.Pill(
                id: "pill\(index)", name: "Pill", symbol: "cpu",
                value: (index == count - 1 ? last : nil) ?? "\(index)",
                action: "Open Activity Monitor")
        }
        container.layoutSubtreeIfNeeded()
    }

    @Test func theFadeDeepensWithTheDistanceScrolled() {
        show(12)
        let ramp: [(offset: CGFloat, alpha: CGFloat)] = [
            (0, 1), (7, 0.75), (14, 0.5), (28, 0), (60, 0),
        ]
        for (offset, alpha) in ramp {
            clip.scroll(to: NSPoint(x: offset, y: 0))
            bar.reflectScrolledClipView(clip)
            #expect(alphas.first == alpha)
        }
    }

    @Test func arrowsGlideThePillsAndTheFadeFollows() async throws {
        bar.reducesMotion = { false }
        show(12)
        bar.highlight(11)
        #expect(clip.bounds.minX == 0)
        #expect(alphas == [1, 0])
        let end = bar.documentView?.frame.maxX
        for _ in 0..<500 where clip.bounds.maxX != end {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(clip.bounds.maxX == end)
        #expect(alphas == [0, 1])
    }

    @Test func aNewValueThatOverflowsBlendsTheFadeIn() {
        bar.reducesMotion = { false }
        show(2)
        #expect(alphas == [1, 1])
        show(2, last: String(repeating: "9", count: 40))
        #expect(alphas == [1, 0])
        #expect(bar.edges.animation(forKey: "colors") != nil)
        clip.scroll(to: NSPoint(x: 1, y: 0))
        bar.reflectScrolledClipView(clip)
        #expect(bar.edges.animation(forKey: "colors") == nil)
    }

    @Test func scrollingByHandStopsTheGlide() throws {
        bar.reducesMotion = { false }
        show(12)
        bar.highlight(11)
        let wheel = try #require(
            CGEvent(
                scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: 0, wheel2: 0,
                wheel3: 0
            )
            .flatMap(NSEvent.init))
        bar.scrollWheel(with: wheel)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.5))
        #expect(clip.bounds.minX == 0)
    }
}
