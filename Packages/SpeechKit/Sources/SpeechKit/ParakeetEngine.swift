import FluidAudio
import Foundation

final class ParakeetEngine: Engine {
    private let manager: AsrManager

    init(folder: URL, version: AsrModelVersion) async throws {
        let models = try await Self.models(in: folder, version: version)
        manager = AsrManager(config: .default)
        try await manager.loadModels(models)
    }

    @concurrent
    private static func models(in folder: URL, version: AsrModelVersion) async throws -> AsrModels {
        try AsrModels.loadLocal(from: folder, version: version)
    }

    func transcribe(_ samples: [Float]) async throws -> String {
        let sampleRate = Int(Transcriber.sampleRate)
        guard samples.count >= ASRConstants.minimumRequiredSamples(forSampleRate: sampleRate) else {
            return ""
        }
        var state = TdtDecoderState.make(decoderLayers: await manager.decoderLayerCount)
        let result = try await manager.transcribe(samples, decoderState: &state)
        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
