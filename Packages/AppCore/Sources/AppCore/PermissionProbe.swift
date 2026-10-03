public protocol PermissionProbe: Sendable {
    func status(for permission: Permission) -> PermissionStatus
    func request(_ permission: Permission) async
}
