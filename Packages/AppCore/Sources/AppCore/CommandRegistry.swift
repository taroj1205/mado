import Foundation

@MainActor
public final class CommandRegistry {
    public var all: [Command] {
        commands
    }

    private var commands: [Command]

    public init() {
        commands = []
    }

    public func register(_ command: Command) throws {
        guard !commands.contains(where: { $0.id == command.id }) else {
            throw CommandError.duplicateCommand(command.id)
        }
        commands.append(command)
    }

    public func unregister(_ id: String) {
        commands.removeAll { $0.id == id }
    }

    public func command(id: String) -> Command? {
        commands.first { $0.id == id }
    }

    public func commands(matching text: String) -> [Command] {
        let needle = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return commands }
        return commands.filter { command in
            ([command.name] + command.keywords).contains { candidate in
                candidate.localizedCaseInsensitiveContains(needle)
            }
        }
    }
}
