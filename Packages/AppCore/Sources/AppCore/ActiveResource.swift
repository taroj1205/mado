public struct ActiveResource: Equatable, Sendable {
    public let module: String
    public let kind: ResourceKind
    public let name: String

    public init(module: String, kind: ResourceKind, name: String) {
        self.module = module
        self.kind = kind
        self.name = name
    }
}
