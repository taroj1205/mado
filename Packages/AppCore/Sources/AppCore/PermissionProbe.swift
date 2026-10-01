public protocol PermissionProbe: Sendable {
    func status(for permission: Permission) -> PermissionStatus
}
