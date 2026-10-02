import AppCore
import Dispatch

@globalActor
public actor AccessibilityActor {
    public static let shared = AccessibilityActor()

    private let queue = DispatchSerialQueue(label: "\(Log.subsystem).accessibility")

    nonisolated public var unownedExecutor: UnownedSerialExecutor {
        unsafe queue.asUnownedSerialExecutor()
    }
}
