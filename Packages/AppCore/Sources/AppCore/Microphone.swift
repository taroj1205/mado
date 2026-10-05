import AVFAudio
import Foundation
import os

@MainActor
public final class Microphone {
    enum Failure: Error {
        case noInput
    }

    struct Chunk: Sendable {
        let samples: [Float]
        let sampleRate: Double
    }

    private static let bus: AVAudioNodeBus = 0
    private static let bufferSize: AVAudioFrameCount = 1_024
    nonisolated private static let silence = -50.0
    nonisolated private static let loud = -10.0
    nonisolated private static let decibelsPerPowerDecade = 10.0

    private let engine: AVAudioEngine
    private let sampleRate: Double
    nonisolated private let pending = OSAllocatedUnfairLock<[Chunk]>(initialState: [])
    private var converter: AVAudioConverter?
    private(set) var recorded: [Float] = []
    private var onLevel: (@MainActor (Double) -> Void)?
    private var onFailure: (@MainActor (any Error) -> Void)?
    private var observer: (any NSObjectProtocol)?
    private var session = 0

    public var isRunning: Bool {
        onLevel != nil
    }

    public init(sampleRate: Double) {
        engine = AVAudioEngine()
        self.sampleRate = sampleRate
    }

    nonisolated private static func mono(at rate: Double) -> AVAudioFormat? {
        AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: rate, channels: 1, interleaved: false)
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

    nonisolated static func samples(of buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channels = unsafe buffer.floatChannelData else { return [] }
        return unsafe Array(UnsafeBufferPointer(start: channels[0], count: Int(buffer.frameLength)))
    }

    nonisolated private static func tap(
        into pending: OSAllocatedUnfairLock<[Chunk]>, _ send: @escaping @Sendable (Double) -> Void
    ) -> AVAudioNodeTapBlock {
        { buffer, _ in
            let chunk = Chunk(samples: samples(of: buffer), sampleRate: buffer.format.sampleRate)
            pending.withLock { $0.append(chunk) }
            send(level(of: buffer))
        }
    }

    public func start(
        onLevel: @escaping @MainActor (Double) -> Void,
        onFailure: @escaping @MainActor (any Error) -> Void
    ) throws {
        stop()
        pending.withLock { $0 = [] }
        try run()
        self.onLevel = onLevel
        self.onFailure = onFailure
        observer = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.restart() }
        }
    }

    @discardableResult
    public func stop() -> [Float] {
        guard isRunning else { return [] }
        defer {
            recorded = []
            converter = nil
        }
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        observer = nil
        onLevel = nil
        onFailure = nil
        engine.inputNode.removeTap(onBus: Self.bus)
        engine.stop()
        drain()
        return recorded
    }

    private func drain() {
        let chunks = pending.withLock { queued in
            defer { queued = [] }
            return queued
        }
        for chunk in chunks {
            record(chunk.samples, at: chunk.sampleRate)
        }
    }

    func record(_ chunk: [Float], at chunkRate: Double) {
        guard let input = Self.mono(at: chunkRate), let speech = Self.mono(at: sampleRate),
            let buffer = AVAudioPCMBuffer(
                pcmFormat: input, frameCapacity: AVAudioFrameCount(chunk.count)),
            let channels = unsafe buffer.floatChannelData
        else { return }
        if converter?.inputFormat != input {
            converter = AVAudioConverter(from: input, to: speech)
        }
        let frames = AVAudioFrameCount((Double(chunk.count) * sampleRate / chunkRate).rounded(.up))
        guard let converter,
            let output = AVAudioPCMBuffer(pcmFormat: speech, frameCapacity: frames)
        else { return }
        buffer.frameLength = buffer.frameCapacity
        _ = unsafe UnsafeMutableBufferPointer(start: channels[0], count: chunk.count)
            .update(fromContentsOf: chunk)
        var unread: AVAudioPCMBuffer? = buffer
        unsafe converter.convert(to: output, error: nil) { _, status in
            defer { unread = nil }
            unsafe status.pointee = unread == nil ? .noDataNow : .haveData
            return unread
        }
        recorded += Self.samples(of: output)
    }

    private func run() throws {
        let input = engine.inputNode
        let hardware = input.inputFormat(forBus: Self.bus)
        guard hardware.channelCount > 0, hardware.sampleRate > 0 else { throw Failure.noInput }
        session += 1
        let current = session
        input.installTap(
            onBus: Self.bus, bufferSize: Self.bufferSize, format: nil,
            block: Self.tap(into: pending) { [weak self] level in
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
        guard delivered == session, isRunning else { return }
        drain()
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
