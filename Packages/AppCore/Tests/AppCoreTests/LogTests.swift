import OSLog
import Testing

@testable import AppCore

@Suite struct LogTests {
    @Test func loggerUsesTheSharedSubsystemAndModuleCategory() throws {
        let marker = "log-test-\(UUID().uuidString)"
        Log.logger("clipboard").notice("\(marker, privacy: .public)")

        let store = try OSLogStore(scope: .currentProcessIdentifier)
        let entries = try store.getEntries()
        let logs = entries.compactMap { $0 as? OSLogEntryLog }
        let match = logs.last { $0.composedMessage == marker }
        #expect(match?.subsystem == Log.subsystem)
        #expect(match?.category == "clipboard")
    }
}
