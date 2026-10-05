import AppCore
import ApplicationServices
import Dispatch
import Foundation

@globalActor
public actor AccessibilityActor {
    public static let shared = AccessibilityActor()

    private let queue = DispatchSerialQueue(label: "\(Log.subsystem).accessibility")

    nonisolated public var unownedExecutor: UnownedSerialExecutor {
        unsafe queue.asUnownedSerialExecutor()
    }

    nonisolated static func call<T>(on element: AXUIElement, _ request: () -> T) -> T {
        var pid: pid_t = 0
        guard !Thread.isMainThread, unsafe AXUIElementGetPid(element, &pid) == .success,
            pid == getpid()
        else { return request() }
        return DispatchQueue.main.sync(execute: request)
    }
}
