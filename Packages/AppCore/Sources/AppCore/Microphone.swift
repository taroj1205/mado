import AVFAudio
import Foundation

@MainActor
public final class Microphone {
    enum Failure: Error {
        case noInput
    }

    private static let bus: AVAudioNodeBus = 0
    private static let bufferSize: AVAudioFrameCount = 1_024
    nonisolated private static let silence = -50.0
    nonisolated private static let loud = -10.0
    nonisolated private static let decibelsPerPowerDecade = 10.0

    private let engine: AVAudioEngine
    private var onLevel: (@MainActor (Double) -> Void)?
    private var onFailure: (@MainActor (any Error) -> Void)?
    private var observer: (any NSObjectProtocol)?
    private var session = 0

    public var isRunning: Bool {
        onLevel != nil
    }

    public init() {
        engine = AVAudioEngine()
    }

    nonisolated static func level(decibels: Double) -> Double {
        min(max((decibels - silence) / (loud - silence), 0), 1)
    }

    nonisolated static func level(of buffer: AVAudioPCMBuffer) -> Double {
        let count = Int(buffer.frameLength)
        guard count > 0, let channels = unsafe buffer.floatChannelData else { return 0 }
        let samples = unsafe UnsafeBufferPointer(start: channels[0], count: count)
        let power = unsafe samples.reduce(0) { $0 + Double($1) * Double($1) } / Double(count)
        return level(decibels: decibelsPerPowerDecade * log10(power))
    }

    nonisolated private static func tap(
        _ send: @escaping @Sendable (Double) -> Void
    ) -> AVAudioNodeTapBlock {
        { buffer, _ in send(level(of: buffer)) }
    }

    public func start(
        onLevel: @escaping @MainActor (Double) -> Void,
        onFailure: @escaping @MainActor (any Error) -> Void
    ) throws {
        stop()
        try run()
        self.onLevel = onLevel
        self.onFailure = onFailure
        observer = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.restart() }
        }
    }

    public func stop() {
        guard isRunning else { return }
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        observer = nil
        onLevel = nil
        onFailure = nil
        engine.inputNode.removeTap(onBus: Self.bus)
        engine.stop()
    }

    private func run() throws {
        let input = engine.inputNode
        let hardware = input.inputFormat(forBus: Self.bus)
        guard hardware.channelCount > 0, hardware.sampleRate > 0 else { throw Failure.noInput }
        session += 1
        let current = session
        input.installTap(
            onBus: Self.bus, bufferSize: Self.bufferSize, format: nil,
            block: Self.tap { [weak self] level in
                DispatchQueue.main.async { self?.deliver(level, in: current) }
            })
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: Self.bus)
            throw error
        }
    }

    private func deliver(_ level: Double, in delivered: Int) {
        guard delivered == session else { return }
        onLevel?(level)
    }

    private func restart() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: Self.bus)
        do {
            try run()
        } catch {
            let failed = onFailure
            stop()
            failed?(error)
        }
    }
}
