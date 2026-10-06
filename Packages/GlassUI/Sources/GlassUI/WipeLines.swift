import AppKit

final class WipeLines: CALayer {
    private struct Sweep {
        let start: Double
        let remaining: Double?
        let playing: Bool
        let began: ContinuousClock.Instant
    }

    private static let attosecond = 1e-18

    private(set) var strips: [WipeMask] = []
    private var rects: [CGRect] = []
    private var sweep: Sweep?

    func fit(_ next: [CGRect]) {
        guard next != rects else { return }
        rects = next
        while strips.count < next.count {
            let strip = WipeMask()
            strips.append(strip)
            addSublayer(strip)
        }
        while strips.count > next.count {
            strips.removeLast().removeFromSuperlayer()
        }
        for (strip, rect) in zip(strips, next) {
            strip.fit(rect)
        }
        guard let sweep else { return }
        let gone = sweep.playing ? seconds(from: sweep.began) : 0
        let left = sweep.remaining.map { max($0 - gone, 0) }
        let covered = sweep.remaining.flatMap { $0 > 0 ? min(gone / $0, 1) : nil } ?? 0
        run(
            from: sweep.start + (1 - sweep.start) * covered, remaining: left,
            playing: sweep.playing, restart: true)
    }

    func forget() {
        sweep = nil
    }

    func run(from start: Double, remaining: Double?, playing: Bool, restart: Bool) {
        sweep = Sweep(start: start, remaining: remaining, playing: playing, began: .now)
        let total = rects.reduce(0.0) { $0 + Double($1.width) }
        guard total > 0 else { return }
        let reach = start * total
        let pace = remaining.map { $0 > 0 ? (1 - start) * total / $0 : 0 } ?? 0
        var before = 0.0
        for (strip, rect) in zip(strips, rects) where rect.width > 0 {
            let width = Double(rect.width)
            let done = min(max((reach - before) / width, 0), 1)
            strip.run(
                from: done, remaining: pace > 0 ? (1 - done) * width / pace : 0,
                delay: pace > 0 ? max(before - reach, 0) / pace : 0, playing: playing,
                restart: restart)
            before += width
        }
    }

    private func seconds(from instant: ContinuousClock.Instant) -> Double {
        let span = (ContinuousClock.now - instant).components
        return Double(span.seconds) + Double(span.attoseconds) * Self.attosecond
    }
}
