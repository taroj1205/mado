import AppCore
import AppKit
import ClipboardKit
import GlassUI
import WindowKit

@MainActor
final class TextCapture {
    enum Failure: Error {
        case nothingCaptured
    }

    static let commandID = "system.capture-text"
    private static let cardSeconds = 6
    private static let cardMargin: CGFloat = 20

    private let selector = AreaSelector()
    private let card = TextCaptureCard()
    private var capturing = false
    private var dismissal: Task<Void, Never>?

    var command: Command {
        Command(
            id: Self.commandID, name: "Capture Text", icon: "text.viewfinder",
            actions: [
                CommandAction(id: "capture", title: "Capture Text") { [weak self] in
                    try await self?.capture()
                }
            ],
            keywords: [
                "ocr", "screenshot", "screen text", "recognise text", "recognize text",
                "scan text", "text from screen", "copy text",
            ])
    }

    private static func place(_ size: CGSize, in visible: CGRect) -> CGRect {
        CGRect(
            x: visible.maxX - size.width - cardMargin, y: visible.maxY - size.height - cardMargin,
            width: size.width, height: size.height)
    }

    private func capture() async throws {
        guard !capturing else { return }
        try ScreenCaptureAccess.require()
        capturing = true
        defer { capturing = false }
        dismissal?.cancel()
        card.hide()
        let area = try await select()
        let screens = NSScreen.screens
        let snapshots = try await ScreenSnapshot.capture(on: screens)
        guard let image = snapshots.lazy.compactMap({ $0.crop(area) }).first else {
            throw Failure.nothingCaptured
        }
        let recognition = try await ImageText.recognize(image)
        let found = !recognition.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if found {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(recognition.text, forType: .string)
        }
        let visible = (screens.first { $0.frame.contains(area) } ?? NSScreen.main)?.visibleFrame
        card.show(
            found ? .copied(text: recognition.text, language: recognition.language) : .nothingFound
        ) { size in
            Self.place(size, in: visible ?? CGRect(origin: .zero, size: size))
        }
        dismissal = Task { [card] in
            try? await Task.sleep(for: .seconds(Self.cardSeconds))
            if !Task.isCancelled { card.hide() }
        }
    }

    private func select() async throws -> CGRect {
        let previous = NSWorkspace.shared.frontmostApplication
        NSApp.activate()
        let area = await withCheckedContinuation { continuation in
            selector.onFinish = { continuation.resume(returning: $0) }
            selector.show(on: NSScreen.screens)
        }
        selector.onFinish = nil
        previous?.activate(from: .current, options: [])
        guard let area else { throw CocoaError(.userCancelled) }
        return area
    }
}
