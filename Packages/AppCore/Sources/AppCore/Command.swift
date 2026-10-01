public struct Command: Sendable {
    public let id: String
    public let name: String
    public let keywords: [String]
    public let icon: String
    public let actions: [CommandAction]
    public let hotkey: Shortcut?

    public init(
        id: String,
        name: String,
        icon: String,
        actions: [CommandAction],
        keywords: [String] = [],
        hotkey: Shortcut? = nil
    ) {
        self.id = id
        self.name = name
        self.keywords = keywords
        self.icon = icon
        self.actions = actions
        self.hotkey = hotkey
    }
}
