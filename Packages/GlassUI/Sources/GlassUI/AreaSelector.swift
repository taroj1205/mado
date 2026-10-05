public import AppKit

@MainActor
public final class AreaSelector {
    private(set) var panels: [AreaPanel] = []
    public var onFinish: ((CGRect?) -> Void)?

    public var isVisible: Bool { !panels.isEmpty }

    public init(onFinish: ((CGRect?) -> Void)? = nil) {
        self.onFinish = onFinish
    }

    public func show(on screens: [NSScreen]) {
        hide()
        let mouse = NSEvent.mouseLocation
        panels = screens.map { screen in
            let panel = AreaPanel(frame: screen.frame)
            panel.onSelect = { [weak self] in self?.finish($0) }
            panel.onCancel = { [weak self] in self?.finish(nil) }
            return panel
        }
        let main = panels.first { NSMouseInRect(mouse, $0.frame, false) } ?? panels.first
        main?.takesKeys = true
        for panel in panels {
            panel.orderFrontRegardless()
        }
        main?.makeKey()
    }

    public func hide() {
        let shown = panels
        panels = []
        for panel in shown {
            panel.orderOut(nil)
        }
    }

    private func finish(_ area: CGRect?) {
        guard isVisible else { return }
        hide()
        onFinish?(area)
    }
}
