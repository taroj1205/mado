import Foundation

@testable import AppCore

final class FakeProbe: PermissionProbe, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Permission: PermissionStatus] = [:]
    private var answers: [Permission: PermissionStatus] = [:]
    private var asked: [Permission] = []

    var requested: [Permission] {
        lock.withLock { asked }
    }

    func set(_ permission: Permission, _ status: PermissionStatus) {
        lock.withLock { values[permission] = status }
    }

    func answer(_ permission: Permission, with status: PermissionStatus) {
        lock.withLock { answers[permission] = status }
    }

    func status(for permission: Permission) -> PermissionStatus {
        lock.withLock { values[permission] ?? .denied }
    }

    func request(_ permission: Permission) async -> PermissionStatus {
        await Task.yield()
        return lock.withLock {
            asked.append(permission)
            if let answer = answers[permission] {
                values[permission] = answer
            }
            return values[permission] ?? .denied
        }
    }
}
