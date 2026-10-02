import AppCore
import AppKit
import os
import SearchKit

extension Quicklink {
    enum Failure: Error {
        case badLink
    }

    static let createID = "quicklinks.create"
    static let createTitle = "Create Quicklink"
    static let openTitle = "Open Quicklink"
    private static let iconSide: CGFloat = 64
    private static let found = 200
    private static let logger = Log.logger("Quicklinks")

    var image: NSImage? {
        icon.flatMap(NSImage.init(data:))
    }

    static func createCommand(open: @escaping @MainActor @Sendable () -> Void) -> Command {
        Command(
            id: createID, name: createTitle, icon: "link",
            actions: [CommandAction(id: "create", title: createTitle, perform: open)],
            keywords: ["quicklink", "bookmark", "link", "url"])
    }

    @MainActor
    static func applications(for link: String) -> [URL] {
        guard let url = Self(name: "", link: link).url(for: "") else { return [] }
        let all = NSWorkspace.shared.urlsForApplications(toOpen: url)
        guard let preferred = NSWorkspace.shared.urlForApplication(toOpen: url) else { return all }
        return [preferred] + all.filter { $0 != preferred }
    }

    @MainActor
    static func websiteIcon(for link: String) async -> Data? {
        guard let page = Self(name: "", link: link).url(for: ""), !page.isFileURL,
            let host = page.host(), !host.isEmpty
        else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.port = page.port
        components.path = "/favicon.ico"
        guard let address = components.url else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: address)
            guard (response as? HTTPURLResponse)?.statusCode == found,
                let favicon = NSImage(data: data)
            else { return nil }
            let size = NSSize(width: iconSide, height: iconSide)
            let resized = NSImage(size: size, flipped: false) { rect in
                favicon.draw(in: rect)
                return true
            }
            return resized.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:))?
                .representation(using: .png, properties: [:])
        } catch {
            logger.error("Website icon failed: \(error, privacy: .public)")
            return nil
        }
    }

    func open(query: String) -> CommandAction {
        CommandAction(id: "open", title: Self.openTitle) { [self] in
            guard let url = url(for: query) else { throw Failure.badLink }
            let configuration = NSWorkspace.OpenConfiguration()
            if let app {
                _ = try await NSWorkspace.shared.open(
                    [url], withApplicationAt: app, configuration: configuration)
            } else {
                _ = try await NSWorkspace.shared.open(url, configuration: configuration)
            }
        }
    }
}
