public struct CommandAction: Sendable {
    public let id: String
    public let title: String
    public let perform: @MainActor @Sendable () async throws -> Void

    public init(
        id: String, title: String,
        perform: @escaping @MainActor @Sendable () async throws -> Void
    ) {
        self.id = id
        self.title = title
        self.perform = perform
    }
}
