import AppCore
import AppKit
import GlassUI

extension Widgets {
    private static let openCamera = "Open Camera"

    static func widget(for feed: CameraFeed) -> WidgetGrid.Widget {
        let name = name(of: camera)
        switch feed.state {
        case .idle, .starting:
            return .init(
                id: camera, name: name, content: .loading(title: name), action: openCamera,
                spoken: "\(name): starting")

        case .needsPermission:
            return .init(
                id: camera, name: name,
                content: .permission(title: name, request: "Allow camera", reason: ""),
                action: "Allow Camera Access",
                spoken: "\(name): allow camera access to see yourself")

        case .denied:
            return notice("Camera off", "Open Settings", "Open Camera Settings")

        case .noCamera:
            return notice("No camera", "Plug one in", openCamera)

        case .failed:
            return notice("Can’t open", "Try again", openCamera)

        case .live:
            return .init(
                id: camera, name: name,
                live: .init(session: feed.session, mirrored: feed.mirrored),
                action: openCamera, spoken: "\(name): live preview")
        }
    }

    private static func notice(
        _ headline: String, _ detail: String, _ action: String
    ) -> WidgetGrid.Widget {
        let name = name(of: camera)
        return .init(
            id: camera, name: name,
            content: .notice(title: name, headline: headline, detail: detail), action: action,
            spoken: "\(name): \(headline). \(detail)")
    }

    func refreshCamera() {
        if shown.contains(Self.camera) {
            cameraFeed.start()
        } else {
            cameraFeed.stop()
        }
    }

    func cameraAction(titled title: String) -> CommandAction {
        switch cameraFeed.state {
        case .needsPermission:
            return CommandAction(id: "allow", title: title) { [cameraFeed] in
                cameraFeed.allow()
            }

        case .denied:
            return CommandAction(id: "open", title: title) {
                NSWorkspace.shared.open(PermissionManager.settingsURL(for: .camera))
            }

        default:
            return CommandAction(id: "open", title: title) { [cameraMirror] in
                cameraMirror.show()
            }
        }
    }
}
