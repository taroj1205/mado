public import Foundation
import whisper

public actor Transcriber {
    public enum Failure: Error {
        case notLoaded
        case failed(code: Int32)
    }

    @safe
    private final class Context {
        let model: URL
        let pointer: OpaquePointer

        init(model: URL) throws {
            var params = unsafe whisper_context_default_params()
            unsafe params.use_gpu = true
            guard
                let loaded = unsafe whisper_init_from_file_with_params(
                    model.path(percentEncoded: false), params)
            else { throw Failure.notLoaded }
            self.model = model
            unsafe pointer = loaded
        }

        deinit {
            unsafe whisper_free(pointer)
        }
    }

    public static let sampleRate = Double(WHISPER_SAMPLE_RATE)
    private static let language = "auto"
    private static let shortestSeconds = 0.1

    private var context: Context?

    public init() {
        context = nil
    }

    static func text(_ segments: [String]) -> String {
        segments.joined()
            .replacing(/\[[^\]]*\]/, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func load(_ model: URL) throws {
        guard context?.model != model else { return }
        context = nil
        context = try Context(model: model)
    }

    public func unload() {
        context = nil
    }

    public func transcribe(_ samples: [Float], with model: URL) throws -> String {
        defer { unload() }
        guard Double(samples.count) >= Self.sampleRate * Self.shortestSeconds else { return "" }
        try load(model)
        guard let pointer = unsafe context?.pointer else { throw Failure.notLoaded }
        var params = unsafe whisper_full_default_params(WHISPER_SAMPLING_BEAM_SEARCH)
        unsafe params.print_progress = false
        let code = Self.language.withCString { language in
            unsafe params.language = language
            return samples.withUnsafeBufferPointer { buffer in
                unsafe whisper_full(pointer, params, buffer.baseAddress, Int32(buffer.count))
            }
        }
        guard code == 0 else { throw Failure.failed(code: code) }
        return Self.text(
            unsafe (0..<whisper_full_n_segments(pointer)).map { index in
                unsafe String(cString: whisper_full_get_segment_text(pointer, index))
            })
    }
}
