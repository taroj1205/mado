import Foundation
import whisper

@safe
final class WhisperEngine: Engine, @unchecked Sendable {
    private static let automatic = "auto"

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

    private func language(
        of samples: [Float], among languages: [String], threads: Int32
    ) -> String {
        guard languages.count > 1 else { return languages.first ?? Self.automatic }
        guard unsafe whisper_is_multilingual(pointer) != 0 else { return Self.automatic }
        let converted = samples.withUnsafeBufferPointer { buffer in
            unsafe whisper_pcm_to_mel(pointer, buffer.baseAddress, Int32(buffer.count), threads)
        }
        var probabilities = [Float](repeating: 0, count: Int(whisper_lang_max_id()) + 1)
        guard converted == 0,
            unsafe whisper_lang_auto_detect(pointer, 0, threads, &probabilities) >= 0
        else { return Self.automatic }
        let scored = languages.compactMap { code -> (code: String, score: Float)? in
            let id = Int(unsafe whisper_lang_id(code))
            return probabilities.indices.contains(id) ? (code, probabilities[id]) : nil
        }
        return scored.max { $0.score < $1.score }?.code ?? Self.automatic
    }

    func transcribe(_ samples: [Float], languages: [String]) throws -> String {
        var params = unsafe whisper_full_default_params(WHISPER_SAMPLING_BEAM_SEARCH)
        unsafe params.print_progress = false
        let spoken = language(of: samples, among: languages, threads: unsafe params.n_threads)
        let code = spoken.withCString { language in
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
