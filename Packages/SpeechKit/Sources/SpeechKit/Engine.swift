protocol Engine: Sendable {
    func transcribe(_ samples: [Float], languages: [String]) async throws -> String
}
