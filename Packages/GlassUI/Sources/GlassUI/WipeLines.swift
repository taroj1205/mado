import AppCore
import AppKit

final class WipeLines: CALayer {
    private struct Running {
        let sweep: WipeSweep
        let playing: Bool
        let began: ContinuousClock.Instant
    }

    private static let attosecond = 1e-18

    private(set) var strips: [WipeMask] = []
    private var rects: [CGRect] = []
    private var running: Running?

    private static func share(_ reach: Double, of width: Double, after before: Double) -> Double {
        min(max((reach - before) / width, 0), 1)
    }

    private static func resume(_ sweep: WipeSweep, after gone: Double) -> WipeSweep {
        let left = sweep.remaining.map { max($0 - gone, 0) }
        guard !sweep.ahead.isEmpty else {
            let covered = sweep.remaining.flatMap { $0 > 0 ? min(gone / $0, 1) : nil } ?? 0
            return WipeSweep(
                start: sweep.start + (1 - sweep.start) * covered, remaining: left, ahead: [])
        }
        guard let next = sweep.ahead.firstIndex(where: { step in step.seconds > gone }) else {
            return WipeSweep(start: 1, remaining: left, ahead: [])
        }
        let before =
            next == 0 ? Lyrics.Step(seconds: 0, reach: sweep.start) : sweep.ahead[next - 1]
        let after = sweep.ahead[next]
        let span = after.seconds - before.seconds
        let into = span > 0 ? (gone - before.seconds) / span : 0
        return WipeSweep(
            start: before.reach + (after.reach - before.reach) * into, remaining: left,
            ahead: sweep.ahead[next...].map { step in
                Lyrics.Step(seconds: step.seconds - gone, reach: step.reach)
            })
    }

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
        guard let running else { return }
        let gone = running.playing ? seconds(from: running.began) : 0
        run(Self.resume(running.sweep, after: gone), playing: running.playing, restart: true)
    }

    func forget() {
        running = nil
    }

    func run(_ sweep: WipeSweep, playing: Bool, restart: Bool) {
        running = Running(sweep: sweep, playing: playing, began: .now)
        let total = rects.reduce(0.0) { $0 + Double($1.width) }
        guard total > 0 else { return }
        let reach = sweep.start * total
        let pace = sweep.remaining.map { $0 > 0 ? (1 - sweep.start) * total / $0 : 0 } ?? 0
        var before = 0.0
        for (strip, rect) in zip(strips, rects) where rect.width > 0 {
            let width = Double(rect.width)
            let done = Self.share(reach, of: width, after: before)
            let local = sweep.ahead.map { step in
                Lyrics.Step(
                    seconds: step.seconds,
                    reach: Self.share(step.reach * total, of: width, after: before))
            }
            let stepped = !sweep.ahead.isEmpty
            let left = pace > 0 ? (1 - done) * width / pace : 0
            strip.run(
                WipeSweep(start: done, remaining: stepped ? sweep.remaining : left, ahead: local),
                delay: !stepped && pace > 0 ? max(before - reach, 0) / pace : 0,
                playing: playing, restart: restart)
            before += width
        }
    }

    private func seconds(from instant: ContinuousClock.Instant) -> Double {
        let span = (ContinuousClock.now - instant).components
        return Double(span.seconds) + Double(span.attoseconds) * Self.attosecond
    }
}
