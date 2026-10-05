import AppKit
import QuartzCore

@MainActor
final class SettingsSpotlight {
    struct Focus: Equatable {
        let matches: [String: [Int]]
        let selected: String?
        let dimsOthers: Bool
    }

    private static let dimmed: CGFloat = 0.38
    private static let moduleOffAlpha: CGFloat = 0.45
    private static let tint = (dark: 0.14, light: 0.10)
    private static let flashTint: CGFloat = 0.45
    private static let edgeAlpha: CGFloat = 0.45
    private static let fade: TimeInterval = 0.2
    private static let flash: CFTimeInterval = 1.4
    private static let scrollMargin: CGFloat = 12
    private static let mark = (dark: 0.35, light: 0.45)

    private static var reducesMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    var moduleOff = false {
        didSet { restyle() }
    }
    var focus: Focus? {
        didSet {
            if focus != oldValue {
                refresh()
            }
        }
    }

    private var rows: [String: NSView] = [:]
    private var controls: [String: NSView] = [:]
    private var labels: [String: NSTextField] = [:]
    private var headers: [(view: NSView, ids: [String])] = []
    private var moduleRow: String?

    private static func isDark(_ view: NSView) -> Bool {
        view.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }

    private static func tintAlpha(_ view: NSView) -> CGFloat {
        isDark(view) ? tint.dark : tint.light
    }

    private static func mark(_ label: NSTextField, at offsets: [Int]) {
        let text = NSMutableAttributedString(
            string: label.stringValue,
            attributes: [.font: label.font ?? .systemFont(ofSize: NSFont.systemFontSize)])
        let yellow = NSColor.systemYellow.withAlphaComponent(isDark(label) ? mark.dark : mark.light)
        let string = label.stringValue
        for offset in offsets where offset < string.count {
            let index = string.index(string.startIndex, offsetBy: offset)
            text.addAttribute(
                .backgroundColor, value: yellow,
                range: NSRange(index..<string.index(after: index), in: string))
        }
        label.attributedStringValue = text
    }

    func reset(moduleRow: String?, moduleOff: Bool) {
        rows = [:]
        controls = [:]
        labels = [:]
        headers = []
        self.moduleRow = moduleRow
        self.moduleOff = moduleOff
    }

    func add(row: NSView, label: NSTextField, control: NSView, id: String) {
        row.wantsLayer = true
        rows[id] = row
        labels[id] = label
        controls[id] = control
    }

    func add(header: NSView, rows ids: [String]) {
        headers.append((header, ids))
    }

    func refresh() {
        restyle()
        scrollToSelected()
    }

    private func restyle() {
        for (id, row) in rows {
            let base = moduleOff && id != moduleRow ? Self.moduleOffAlpha : 1
            fade(row, to: isLit(id) ? base : min(base, Self.dimmed))
            let selected = focus?.selected == id
            row.layer?.backgroundColor = selected ? tint(row, Self.tintAlpha(row)) : nil
            row.layer?.borderWidth = selected && focus?.dimsOthers == true ? 1 : 0
            row.layer?.borderColor = tint(row, Self.edgeAlpha)
        }
        for header in headers {
            fade(header.view, to: header.ids.contains(where: isLit) ? 1 : Self.dimmed)
        }
        for (id, label) in labels {
            Self.mark(label, at: focus?.matches[id] ?? [])
        }
    }

    func land(on id: String) {
        guard let row = rows[id] else { return }
        if !Self.reducesMotion {
            let pulse = CABasicAnimation(keyPath: "backgroundColor")
            pulse.fromValue = tint(row, Self.flashTint)
            pulse.toValue = tint(row, Self.tintAlpha(row))
            pulse.duration = Self.flash
            pulse.timingFunction = CAMediaTimingFunction(name: .easeOut)
            row.layer?.add(pulse, forKey: "land")
        }
        guard let control = controls[id]?.firstVisible((any SearchFocusable).self) else {
            unsafe row.window?.makeFirstResponder(nil)
            return
        }
        control.takesSearchFocus = true
        if unsafe row.window?.makeFirstResponder(control) != true {
            control.takesSearchFocus = false
        }
    }

    private func isLit(_ id: String) -> Bool {
        guard let focus, focus.dimsOthers else { return true }
        return focus.selected == id || focus.matches[id] != nil
    }

    private func tint(_ view: NSView, _ alpha: CGFloat) -> CGColor {
        var color = NSColor.controlAccentColor.cgColor
        view.effectiveAppearance.performAsCurrentDrawingAppearance {
            color = NSColor.controlAccentColor.withAlphaComponent(alpha).cgColor
        }
        return color
    }

    private func fade(_ view: NSView, to alpha: CGFloat) {
        guard view.alphaValue != alpha else { return }
        guard !Self.reducesMotion, unsafe view.window != nil else {
            view.alphaValue = alpha
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fade
            view.animator().alphaValue = alpha
        }
    }

    private func scrollToSelected() {
        guard let id = focus?.selected, let row = rows[id], let scroll = row.enclosingScrollView,
            let document = scroll.documentView
        else { return }
        let clip = scroll.contentView
        document.layoutSubtreeIfNeeded()
        let frame = row.convert(row.bounds, to: document)
        let visible = clip.documentVisibleRect
        var top = visible.minY
        if frame.minY < visible.minY {
            top = frame.minY - Self.scrollMargin
        } else if frame.maxY > visible.maxY {
            top = frame.maxY - visible.height + Self.scrollMargin
        }
        top = max(0, min(top, document.frame.height - visible.height))
        guard top != visible.minY else { return }
        let origin = NSPoint(x: visible.minX, y: top)
        if Self.reducesMotion {
            clip.scroll(to: origin)
        } else {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = Self.fade
                clip.animator().setBoundsOrigin(origin)
            }
        }
        scroll.reflectScrolledClipView(clip)
    }
}
