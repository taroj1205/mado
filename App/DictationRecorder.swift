import Accelerate
import AVFoundation

@MainActor
final class DictationRecorder {
    enum Failure: Error {
        case noInput
    }

    private static let bufferFrames: AVAudioFrameCount = 4_096

    var onLevel: ((Float, Duration) -> Void)?
    private var engine: AVAudioEngine?
    private var earlier: Duration = .zero
    private var frames = 0
    private var sampleRate: Double = 0
    private var session = 0

    private var elapsed: Duration {
        earlier + .seconds(Double(frames) / sampleRate)
    }

    nonisolated private static func tap(
        _ deliver: @escaping @Sendable (Float, Int) -> Void
    ) -> AVAudioNodeTapBlock {
        { buffer, _ in
            guard let channel = unsafe buffer.floatChannelData?[0] else { return }
            let samples = unsafe UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength))
            deliver(unsafe vDSP.rootMeanSquare(samples), samples.count)
        }
    }

    func start() throws {
        stop()
        try open()
        earlier = .zero
    }

    func switchInput() throws {
        guard engine != nil else { return }
        let sofar = elapsed
        stop()
        try open()
        earlier = sofar
    }

    func stop() {
        guard let engine else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        self.engine = nil
        session += 1
    }

    private func open() throws {
        let next = AVAudioEngine()
        let input = next.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.channelCount > 0, format.sampleRate > 0 else { throw Failure.noInput }
        let current = session
        input.installTap(
            onBus: 0, bufferSize: Self.bufferFrames, format: format,
            block: Self.tap { [weak self] level, count in
                Task { @MainActor in self?.receive(level, frames: count, session: current) }
            })
        do {
            try next.start()
        } catch {
            input.removeTap(onBus: 0)
            throw error
        }
        engine = next
        frames = 0
        sampleRate = format.sampleRate
    }

    private func receive(_ level: Float, frames count: Int, session: Int) {
        guard session == self.session else { return }
        frames += count
        onLevel?(level, elapsed)
    }
}
