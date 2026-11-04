import Foundation
import Testing

@testable import SpeechKit

@Suite struct DetectionWindowTests {
    private static let second = 16_000
    private static let voice = (0..<(5 * second)).map { Float(0.1 * sin(Double($0) * 0.1)) }

    private func recording(silence: Int, voice: Int) -> [Float] {
        [Float](repeating: 0, count: silence) + Self.voice.prefix(voice)
    }

    @Test func silenceHasNoWindow() {
        var window = DetectionWindow()
        #expect(window.range(in: [Float](repeating: 0, count: 10 * Self.second)) == nil)
    }

    @Test func theWindowIsThreeSecondsFromTheFirstSound() {
        var window = DetectionWindow()
        let samples = recording(silence: Self.second, voice: 4 * Self.second)
        #expect(window.range(in: samples) == Self.second..<4 * Self.second)
    }

    @Test func lessThanThreeSecondsOfSpeechHasNoWindowYet() {
        var window = DetectionWindow()
        let samples = recording(silence: Self.second, voice: 2 * Self.second)
        #expect(window.range(in: samples) == nil)
    }

    @Test func aGrowingRecordingFindsTheSameWindow() {
        var window = DetectionWindow()
        let samples = recording(silence: Self.second, voice: 4 * Self.second)
        var found: Range<Int>?
        for end in stride(from: 1_024, through: samples.count, by: 1_024) {
            found = found ?? window.range(in: Array(samples.prefix(end)))
        }
        #expect(found == Self.second..<4 * Self.second)
    }

    @Test func quietNoiseIsNotSpeech() {
        var window = DetectionWindow()
        let hiss = (0..<(5 * Self.second)).map { Float(0.001 * sin(Double($0) * 0.1)) }
        #expect(window.range(in: hiss) == nil)
    }
}
