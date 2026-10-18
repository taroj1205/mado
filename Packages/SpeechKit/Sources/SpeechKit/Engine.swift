protocol Engine: Sendable {
    func transcribe(
        _ samples: [Float], languages: [String], words: SpeechWords
    ) async throws -> String
}
