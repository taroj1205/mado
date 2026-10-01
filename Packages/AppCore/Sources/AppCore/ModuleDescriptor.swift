public struct ModuleDescriptor: Equatable, Sendable {
    public let id: String
    public let name: String
    public let permissions: Set<Permission>
    public let commandIDs: [String]
    public let hasSettingsPage: Bool
    public let enabledByDefault: Bool

    public init(
        id: String,
        name: String,
        enabledByDefault: Bool,
        permissions: Set<Permission> = [],
        commandIDs: [String] = [],
        hasSettingsPage: Bool = false
    ) {
        self.id = id
        self.name = name
        self.permissions = permissions
        self.commandIDs = commandIDs
        self.hasSettingsPage = hasSettingsPage
        self.enabledByDefault = enabledByDefault
    }
}
