import AppCore
import AppKit
import GlassUI
import SearchKit
import WindowKit

@MainActor
final class ColourPicker {
    enum Failure: Error {
        case screenRecordingDenied
        case nothingCaptured
    }

    static let commandID = "system.pick-colour"
    private static let byte: CGFloat = 255

    private let loupe = ColourLoupe()
    private var pixels = PixelLoupe(snapshots: [])
    private var capturing = false
    private var previous: NSRunningApplication?

    var command: Command {
        Command(
            id: Self.commandID, name: "Pick Colour", icon: "eyedropper",
            actions: [
                CommandAction(id: "pick", title: "Pick Colour") { [weak self] in
                    try await self?.pick()
                }
            ],
            keywords: ["color picker", "colour picker", "eyedropper", "sample"])
    }

    init() {
        loupe.onInput = { [weak self] input in self?.handle(input) }
    }

    private static func displayID(of screen: NSScreen) -> CGDirectDisplayID? {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    private static func colour(of sample: PixelLoupe.Sample) -> Colour {
        Colour(red: sample.red, green: sample.green, blue: sample.blue)
    }

    private func pick() async throws {
        guard !capturing, !loupe.isVisible else { return }
        guard CGPreflightScreenCaptureAccess() else {
            if !CGRequestScreenCaptureAccess() {
                NSWorkspace.shared.open(PermissionManager.settingsURL(for: .screenRecording))
            }
            throw Failure.screenRecordingDenied
        }
        capturing = true
        defer { capturing = false }
        let images = try await ScreenSnapshot.capture()
        let screens = NSScreen.screens
        pixels = PixelLoupe(
            snapshots: screens.compactMap { screen in
                Self.displayID(of: screen).flatMap { images[$0] }.map { image in
                    PixelLoupe.Snapshot(image: image, frame: screen.frame)
                }
            })
        pixels.move(to: NSEvent.mouseLocation)
        guard pixels.sample != nil else { throw Failure.nothingCaptured }
        previous = NSWorkspace.shared.frontmostApplication
        NSApp.activate()
        NSCursor.hide()
        loupe.show(on: screens)
        refresh()
    }

    private func handle(_ input: ColourLoupe.Input) {
        switch input {
        case .moved(let point):
            pixels.move(to: point)
            refresh()

        case let .nudged(across, down):
            pixels.nudge(across: across, down: down)
            refresh()

        case .picked:
            if let sample = pixels.sample {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(Self.colour(of: sample).hex, forType: .string)
            }
            finish()

        case .cancelled:
            finish()
        }
    }

    private func refresh() {
        guard let sample = pixels.sample else { return }
        let swatch = NSColor(
            srgbRed: CGFloat(sample.red) / Self.byte, green: CGFloat(sample.green) / Self.byte,
            blue: CGFloat(sample.blue) / Self.byte, alpha: 1)
        let rgb = "rgb(\(sample.red) \(sample.green) \(sample.blue))"
        loupe.show(
            ColourLoupe.Reading(
                grid: sample.grid, swatch: swatch, hex: Self.colour(of: sample).hex,
                detail: "\(rgb) · x \(sample.column) y \(sample.row)", centre: sample.centre))
    }

    private func finish() {
        loupe.hide()
        NSCursor.unhide()
        pixels = PixelLoupe(snapshots: [])
        previous?.activate(from: .current, options: [])
        previous = nil
    }
}
