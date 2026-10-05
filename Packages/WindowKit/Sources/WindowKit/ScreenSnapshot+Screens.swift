public import AppKit

extension ScreenSnapshot {
    @MainActor
    public static func capture(on screens: [NSScreen]) async throws -> [PixelLoupe.Snapshot] {
        let images = try await capture()
        return screens.compactMap { screen in
            let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
            return (number as? CGDirectDisplayID).flatMap { images[$0] }.map { image in
                PixelLoupe.Snapshot(image: image, frame: screen.frame)
            }
        }
    }
}
