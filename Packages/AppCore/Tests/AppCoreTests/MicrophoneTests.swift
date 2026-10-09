import AVFAudio
import Foundation
import Testing

@testable import AppCore

@Suite struct MicrophoneTests {
    private enum EngineFailure: Error {
        case formatNotSupported
    }

    private final class TestEngine: AVAudioEngine, @unchecked Sendable {
        private static let maximumFrames: AVAudioFrameCount = 1_024
        var failsToStart = false

        init(format: AVAudioFormat) throws {
            super.init()
            try enableManualRenderingMode(
                .offline, format: format, maximumFrameCount: Self.maximumFrames)
        }

        override func start() throws {
            if failsToStart { throw EngineFailure.formatNotSupported }
        }
    }

    @Test func levelsSpanQuietRoomToLoudSpeech() {
        #expect(Microphone.level(decibels: -.infinity) == 0)
        #expect(Microphone.level(decibels: -60) == 0)
        #expect(Microphone.level(decibels: -50) == 0)
        #expect(Microphone.level(decibels: -30) == 0.5)
        #expect(Microphone.level(decibels: -10) == 1)
        #expect(Microphone.level(decibels: 0) == 1)
    }

    @Test func aBufferIsMeasuredByItsLoudness() throws {
        #expect(try Microphone.level(of: buffer(0, frames: 480)) == 0)
        let quiet = try Microphone.level(of: buffer(0.01, frames: 480))
        let loud = try Microphone.level(of: buffer(0.2, frames: 480))
        #expect(abs(quiet - 0.25) < 0.001)
        #expect(loud > quiet)
        #expect(try Microphone.level(of: buffer(1, frames: 480)) == 1)
    }

    @Test func anEmptyBufferIsSilent() throws {
        let empty = try buffer(1, frames: 0)
        #expect(Microphone.level(of: empty) == 0)
    }

    @MainActor
    @Test func recordingKeepsSpeechRateMonoAcrossInputRates() {
        let microphone = Microphone(sampleRate: 16_000)
        for _ in 0..<50 {
            microphone.record(tone(frames: 960, at: 48_000), at: 48_000)
        }
        for _ in 0..<25 {
            microphone.record(tone(frames: 960, at: 24_000), at: 24_000)
        }
        let samples = microphone.recorded
        #expect(abs(samples.count - 32_000) < 200)
        #expect(samples.contains { abs($0) > 0.4 })
    }

    @MainActor
    @Test func eachRecordingUsesANewEngineAfterStartFailure() throws {
        let prepared = try (0..<3).map { _ in try TestEngine(format: hardwareFormat()) }
        var engines: [TestEngine] = []
        let microphone = Microphone(sampleRate: 16_000) {
            let engine = prepared[engines.count]
            engine.failsToStart = engines.isEmpty
            engines.append(engine)
            return engine
        }
        #expect(throws: EngineFailure.self) {
            try microphone.start(onLevel: { _ in () }, onFailure: { _ in () })
        }
        #expect(!microphone.isRunning)
        try microphone.start(onLevel: { _ in () }, onFailure: { _ in () })
        #expect(microphone.isRunning)
        #expect(engines.count == 2)
        microphone.stop()
        try microphone.start(onLevel: { _ in () }, onFailure: { _ in () })
        #expect(engines.count == 3)
        microphone.stop()
    }

    @MainActor
    @Test func configurationChangeRebuildsEngineAfterNotificationReturns() async throws {
        let prepared = try (0..<3).map { _ in try TestEngine(format: hardwareFormat()) }
        var engines: [TestEngine] = []
        let microphone = Microphone(sampleRate: 16_000) {
            let engine = prepared[engines.count]
            engines.append(engine)
            return engine
        }
        var failures = 0
        try microphone.start(onLevel: { _ in () }, onFailure: { _ in failures += 1 })
        microphone.record(tone(frames: 960, at: 48_000), at: 48_000)
        let samples = microphone.recorded
        NotificationCenter.default.post(name: .AVAudioEngineConfigurationChange, object: engines[0])
        #expect(engines.count == 1)
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
        #expect(engines.count == 2)
        #expect(microphone.isRunning)
        #expect(microphone.recorded == samples)
        #expect(failures == 0)
        microphone.stop()
    }

    @MainActor
    @Test func failedReconfigurationStopsOnceAndNextRecordingCanStart() async throws {
        let prepared = try (0..<3).map { _ in try TestEngine(format: hardwareFormat()) }
        prepared[1].failsToStart = true
        var engines: [TestEngine] = []
        let microphone = Microphone(sampleRate: 16_000) {
            let engine = prepared[engines.count]
            engines.append(engine)
            return engine
        }
        var failures = 0
        try microphone.start(onLevel: { _ in () }, onFailure: { _ in failures += 1 })
        NotificationCenter.default.post(name: .AVAudioEngineConfigurationChange, object: engines[0])
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
        #expect(!microphone.isRunning)
        #expect(failures == 1)
        try microphone.start(onLevel: { _ in () }, onFailure: { _ in failures += 1 })
        #expect(microphone.isRunning)
        #expect(engines.count == 3)
        #expect(failures == 1)
        microphone.stop()
    }

    @MainActor
    @Test func queuedConfigurationChangeDoesNotRestartANewerRecording() async throws {
        let prepared = try (0..<3).map { _ in try TestEngine(format: hardwareFormat()) }
        var engines: [TestEngine] = []
        let microphone = Microphone(sampleRate: 16_000) {
            let engine = prepared[engines.count]
            engines.append(engine)
            return engine
        }
        try microphone.start(onLevel: { _ in () }, onFailure: { _ in () })
        NotificationCenter.default.post(name: .AVAudioEngineConfigurationChange, object: engines[0])
        try microphone.start(onLevel: { _ in () }, onFailure: { _ in () })
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
        #expect(engines.count == 2)
        #expect(microphone.isRunning)
        microphone.stop()
    }

    private func hardwareFormat() throws -> AVAudioFormat {
        try #require(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1))
    }

    private func tone(frames: Int, at sampleRate: Double) -> [Float] {
        (0..<frames).map { Float(0.5 * sin(2 * Double.pi * 440 * Double($0) / sampleRate)) }
    }

    private func buffer(_ amplitude: Float, frames: AVAudioFrameCount) throws -> AVAudioPCMBuffer {
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1))
        let buffer = try #require(
            AVAudioPCMBuffer(pcmFormat: format, frameCapacity: max(frames, 1)))
        buffer.frameLength = frames
        let samples = try unsafe #require(buffer.floatChannelData)
        for index in 0..<Int(frames) {
            unsafe samples[0][index] = index.isMultiple(of: 2) ? amplitude : -amplitude
        }
        return buffer
    }
}
