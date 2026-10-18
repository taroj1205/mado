import AVFAudio
import Foundation
import Testing

@testable import AppCore

@Suite struct DictationLogTests {
    private static let start = 1_700_000_000.0

    private let root = FileManager.default.temporaryDirectory.appending(
        path: "DictationLogTests-\(UUID().uuidString)")

    private var log: DictationLog {
        DictationLog(directory: root)
    }

    private func entry(_ text: String, at seconds: TimeInterval) -> DictationLog.Entry {
        .init(
            date: Date(timeIntervalSince1970: seconds), model: "tiny", languages: ["en", "ja"],
            words: ["Mado"], text: text)
    }

    private func keep(_ text: String, at seconds: TimeInterval) async throws {
        try await log.keep(
            [0.5, -0.5], sampleRate: 16_000,
            as: entry(text, at: seconds))
    }

    private func files() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: root.path(percentEncoded: false))
    }

    @Test func aRecordingKeepsItsAudioAndWhatItWasHeardAs() async throws {
        try await keep("hello 窓", at: Self.start)
        #expect(try log.entries() == [entry("hello 窓", at: Self.start)])
        let name = DictationLog.name(for: Date(timeIntervalSince1970: Self.start))
        let audio = try AVAudioFile(forReading: root.appending(path: "\(name).wav"))
        #expect(audio.length == 2)
        #expect(audio.fileFormat.sampleRate == 16_000)
        #expect(audio.fileFormat.channelCount == 1)
        let buffer = try #require(
            AVAudioPCMBuffer(pcmFormat: audio.processingFormat, frameCapacity: 2))
        try audio.read(into: buffer)
        let heard = try unsafe #require(buffer.floatChannelData)
        #expect(unsafe abs(heard[0][0] - 0.5) < 0.001)
        #expect(unsafe abs(heard[0][1] + 0.5) < 0.001)
    }

    @Test func twoRecordingsInOneSecondAreBothKept() async throws {
        try await keep("first", at: Self.start)
        try await keep("second", at: Self.start + 0.5)
        #expect(try log.entries().map(\.text) == ["first", "second"])
    }

    @Test func onlyTheNewestRecordingsStay() async throws {
        for index in 0...DictationLog.limit {
            try await keep("take \(index)", at: Self.start + Double(index))
        }
        let texts = try log.entries().map(\.text)
        #expect(texts.count == DictationLog.limit)
        #expect(texts.first == "take 1")
        #expect(texts.last == "take \(DictationLog.limit)")
        #expect(try files().count == DictationLog.limit * 2)
    }
}
