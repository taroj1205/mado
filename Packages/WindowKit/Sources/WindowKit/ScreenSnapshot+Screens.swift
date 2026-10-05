public import AppKit

extension ScreenSnapshot {
    @MainActor
    public static func capture(on screens: [NSScreen]) async throws -> [PixelLoupe.Snapshot] {
        let ids = screens.map { (screen: $0, id: displayID(of: $0)) }
        let images = try await capture(displays: Set(ids.compactMap(\.id)))
        return ids.compactMap { entry in
            entry.id.flatMap { images[$0] }.map { image in
                PixelLoupe.Snapshot(image: image, frame: entry.screen.frame)
            }
        }
    }

    @MainActor
    private static func displayID(of screen: NSScreen) -> CGDirectDisplayID? {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
