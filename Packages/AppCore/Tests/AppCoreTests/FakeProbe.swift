import Foundation

@testable import AppCore

final class FakeProbe: PermissionProbe, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Permission: PermissionStatus] = [:]

    func set(_ permission: Permission, _ status: PermissionStatus) {
        lock.withLock { values[permission] = status }
    }

    func status(for permission: Permission) -> PermissionStatus {
        lock.withLock { values[permission] ?? .denied }
    }
}
