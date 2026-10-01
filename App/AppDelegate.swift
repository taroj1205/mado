import AppKit
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let signposter: OSSignposter
    private let launch: OSSignpostIntervalState

    init(signposter: OSSignposter, launch: OSSignpostIntervalState) {
        self.signposter = signposter
        self.launch = launch
    }

    func applicationDidFinishLaunching(_: Notification) {
        signposter.endInterval("launch", launch)
    }
}
