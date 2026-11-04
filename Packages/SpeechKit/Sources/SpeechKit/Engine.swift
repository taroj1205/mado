protocol Engine: Sendable {
    func language(of samples: [Float], among languages: [String]) -> String?

    func transcribe(
        _ samples: [Float], languages: [String], words: SpeechWords
    ) async throws -> String
}
