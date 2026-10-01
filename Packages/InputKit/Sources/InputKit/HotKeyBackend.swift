import AppCore

@MainActor
protocol HotKeyBackend: AnyObject {
    var onPressed: (@MainActor (UInt32) -> Void)? { get set }

    func register(_ shortcut: Shortcut, id: UInt32) -> Int32
    func unregister(id: UInt32)
}
