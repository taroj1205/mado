import Foundation
import whisper

@safe
final class WhisperEngine: Engine, @unchecked Sendable {
    private static let language = "auto"

    private let pointer: OpaquePointer

    init(model: URL) throws {
        var params = unsafe whisper_context_default_params()
        unsafe params.use_gpu = true
        guard
            let loaded = unsafe whisper_init_from_file_with_params(
                model.path(percentEncoded: false), params)
        else { throw Transcriber.Failure.notLoaded }
        unsafe pointer = loaded
    }

    func transcribe(_ samples: [Float]) throws -> String {
        var params = unsafe whisper_full_default_params(WHISPER_SAMPLING_BEAM_SEARCH)
        unsafe params.print_progress = false
        let code = Self.language.withCString { language in
            unsafe params.language = language
            return samples.withUnsafeBufferPointer { buffer in
                unsafe whisper_full(pointer, params, buffer.baseAddress, Int32(buffer.count))
            }
        }
        guard code == 0 else { throw Transcriber.Failure.failed(code: code) }
        return Transcriber.text(
            unsafe (0..<whisper_full_n_segments(pointer)).map { index in
                unsafe String(cString: whisper_full_get_segment_text(pointer, index))
            })
    }

    deinit {
        unsafe whisper_free(pointer)
    }
}
