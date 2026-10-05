import AVFAudio
import Testing

@testable import AppCore

@Suite struct MicrophoneTests {
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
