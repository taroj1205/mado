import AppCore
import SearchKit

extension Usage {
    private static let key = "usage"

    @MainActor
    static func load(from modules: ModuleManager?) throws -> Self {
        try modules?.value(Self.self, for: key) ?? Self()
    }

    @MainActor
    func save(to modules: ModuleManager?) throws {
        try modules?.setValue(self, for: Self.key)
    }
}
