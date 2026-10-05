protocol Engine: Sendable {
    func transcribe(_ samples: [Float]) async throws -> String
}
