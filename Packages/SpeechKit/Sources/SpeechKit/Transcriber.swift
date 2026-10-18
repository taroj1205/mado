public import Foundation
import whisper

public actor Transcriber {
    public enum Failure: Error {
        case notLoaded
        case failed(code: Int32)
    }

    public static let sampleRate = Double(WHISPER_SAMPLE_RATE)
    private static let shortestSeconds = 0.1

    private static let soundWindowSeconds = 0.1
    private static let soundFloorPower: Float = 1e-5

    private var loaded: (model: URL, task: Task<any Engine, any Error>)?

    public init() {
        loaded = nil
    }

    static func hasSound(_ samples: [Float]) -> Bool {
        let size = min(Int(sampleRate * soundWindowSeconds), samples.count)
        guard size > 0 else { return false }
        let last = samples.count - size
        return (Array(stride(from: 0, to: last, by: size)) + [last]).contains { start in
            samples[start..<start + size].reduce(0) { $0 + $1 * $1 } / Float(size) > soundFloorPower
        }
    }

    static func text(_ segments: [String]) -> String {
        segments
            .filter { $0.trimmingCharacters(in: .whitespaces).wholeMatch(of: /\[[^\]]*\]/) == nil }
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func engine(for model: URL) async throws -> any Engine {
        guard let version = Parakeet.version(folder: model.lastPathComponent) else {
            return try WhisperEngine(model: model)
        }
        return try await ParakeetEngine(folder: model, version: version)
    }

    private func engine(for model: URL) async throws -> any Engine {
        if let loaded, loaded.model == model { return try await loaded.task.value }
        loaded?.task.cancel()
        let task = Task { try await Self.engine(for: model) }
        loaded = (model, task)
        do {
            return try await task.value
        } catch {
            if loaded?.task == task { loaded = nil }
            throw error
        }
    }

    public func load(_ model: URL) async throws {
        _ = try await engine(for: model)
    }

    public func unload() {
        loaded?.task.cancel()
        loaded = nil
    }

    public func transcribe(
        _ samples: [Float], with model: URL, languages: SpeechLanguages
    ) async throws -> String {
        defer { unload() }
        guard Double(samples.count) >= Self.sampleRate * Self.shortestSeconds,
            Self.hasSound(samples)
        else { return "" }
        return try await engine(for: model).transcribe(samples, languages: languages.codes)
    }
}
