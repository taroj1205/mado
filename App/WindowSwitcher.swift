import AppKit
import GlassUI
import InputKit
import os
import WindowKit

@MainActor
final class WindowSwitcher {
    private enum Phase {
        case idle
        case loading(steps: Int, backward: Bool, chosen: Bool)
        case shown
    }

    private let logger: Logger
    private let overlay = SwitcherOverlay()
    private var phase = Phase.idle
    private var windows: [WindowList.Window] = []
    private var selected = 0
    private var loading: Task<Void, Never>?
    private var capturing: Task<Void, Never>?
    private var thumbnails: [CGWindowID: CGImage] = [:]
    private var askedForThumbnails = false

    var isOpen: Bool {
        if case .idle = phase { false } else { true }
    }

    init(logger: Logger) {
        self.logger = logger
        overlay.onPick = { [weak self] index in
            self?.select(index)
            self?.choose()
        }
        overlay.onHover = { [weak self] in self?.select($0) }
    }

    @AccessibilityActor
    private static func load(_ pids: [pid_t]) -> [WindowList.Window] {
        WindowList.shared.load(from: pids)
    }

    @AccessibilityActor
    private static func focus(_ id: Int) throws(WindowList.Failure) {
        try WindowList.shared.focus(id)
    }

    @AccessibilityActor
    private static func close(_ id: Int) throws(WindowList.Failure) {
        try WindowList.shared.close(id)
    }

    private static func first(backward: Bool, count: Int) -> Int {
        backward ? count - 1 : min(1, count - 1)
    }

    private static func step(_ index: Int, by offset: Int, count: Int) -> Int {
        ((index + offset) % count + count) % count
    }

    private static func types(_ character: String, _ keyCode: Int64) -> Bool {
        KeyboardLayout.commandKeyCode(typing: character).map(Int64.init) == keyCode
    }

    func step(backward: Bool) {
        let offset = backward ? -1 : 1
        switch phase {
        case .idle:
            open(backward: backward)

        case let .loading(steps, start, chosen):
            phase = .loading(steps: steps + offset, backward: start, chosen: chosen)

        case .shown:
            guard !windows.isEmpty else { return }
            select(Self.step(selected, by: offset, count: windows.count))
        }
    }

    func handle(_ event: SwitcherKeys.Event) {
        switch event {
        case .pressed(let keyCode):
            if case .shown = phase { press(keyCode) }

        case .chosen:
            choose()

        case .cancelled:
            stop()
        }
    }

    func stop() {
        loading?.cancel()
        loading = nil
        capturing?.cancel()
        capturing = nil
        thumbnails = [:]
        phase = .idle
        windows = []
        overlay.hide()
    }

    private func open(backward: Bool) {
        stop()
        if !askedForThumbnails, !WindowThumbnails.isAllowed {
            askedForThumbnails = true
            WindowThumbnails.requestAccess()
        }
        phase = .loading(steps: 0, backward: backward, chosen: false)
        let pids = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .map(\.processIdentifier)
        loading = Task { [weak self] in
            let list = await Self.load(pids)
            guard !Task.isCancelled else { return }
            self?.loaded(list)
        }
    }

    private func loaded(_ list: [WindowList.Window]) {
        loading = nil
        guard case let .loading(steps, backward, chosen) = phase, !list.isEmpty else {
            stop()
            return
        }
        windows = list
        selected = Self.step(
            Self.first(backward: backward, count: list.count), by: steps, count: list.count)
        phase = .shown
        if chosen {
            choose()
        } else {
            show()
        }
    }

    private func show() {
        let location = NSEvent.mouseLocation
        guard !windows.isEmpty,
            let screen = NSScreen.screens.first(where: { NSMouseInRect(location, $0.frame, false) })
                ?? NSScreen.main
        else {
            overlay.hide()
            return
        }
        let cards = windows.map { window in
            let app = NSRunningApplication(processIdentifier: window.pid)
            let name = app?.localizedName ?? ""
            return SwitcherOverlay.Card(
                title: window.title.isEmpty ? name : window.title, app: name, icon: app?.icon,
                thumbnail: window.number.flatMap { thumbnails[$0] })
        }
        overlay.show(cards, selected: selected, on: screen)
        if capturing == nil {
            capture(scale: screen.backingScaleFactor)
        }
    }

    private func capture(scale: CGFloat) {
        let numbers = windows.compactMap(\.number)
        let box = SwitcherOverlay.thumbnailSize
        capturing = Task { [weak self] in
            await WindowThumbnails.capture(
                numbers, fitting: CGSize(width: box.width * scale, height: box.height * scale)
            ) { number, image in
                guard !Task.isCancelled else { return }
                self?.received(image, for: number)
            }
        }
    }

    private func received(_ image: CGImage, for number: CGWindowID) {
        thumbnails[number] = image
        if let index = windows.firstIndex(where: { $0.number == number }) {
            overlay.showThumbnail(image, at: index)
        }
    }

    private func select(_ index: Int) {
        guard windows.indices.contains(index) else { return }
        selected = index
        overlay.select(index)
    }

    private func choose() {
        switch phase {
        case let .loading(steps, backward, _):
            phase = .loading(steps: steps, backward: backward, chosen: true)

        case .shown:
            let window = windows.indices.contains(selected) ? windows[selected] : nil
            stop()
            guard let window else { return }
            Task { [logger] in
                do throws(WindowList.Failure) {
                    try await Self.focus(window.id)
                } catch {
                    logger.error(
                        "Window switch failed: \(String(describing: error), privacy: .public)")
                }
            }

        case .idle:
            break
        }
    }

    private func press(_ keyCode: Int64) {
        guard windows.indices.contains(selected) else { return }
        let window = windows[selected]
        let app = NSRunningApplication(processIdentifier: window.pid)
        if Self.types("q", keyCode) {
            if app?.terminate() == true {
                remove { $0.pid == window.pid }
            }
        } else if Self.types("w", keyCode) {
            Task { [weak self, logger] in
                do throws(WindowList.Failure) {
                    try await Self.close(window.id)
                    self?.remove { $0.id == window.id }
                } catch {
                    logger.error(
                        "Window close failed: \(String(describing: error), privacy: .public)")
                }
            }
        } else if Self.types("h", keyCode) {
            app?.hide()
        }
    }

    private func remove(where gone: (WindowList.Window) -> Bool) {
        guard case .shown = phase, windows.contains(where: gone) else { return }
        let current = windows.indices.contains(selected) ? windows[selected].id : nil
        windows.removeAll(where: gone)
        selected = windows.firstIndex { $0.id == current } ?? min(selected, windows.count - 1)
        show()
    }
}
