import AppKit
import GlassUI

extension LyricsStage {
    private static let barPadding: CGFloat = 12

    func showMenuBarLine(_ verse: WidgetGrid.Verse) {
        guard let item = statusItem(), let button = item.button else { return }
        if unsafe line.superview !== button {
            menu = item.menu
            item.menu = nil
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            line.frame = button.bounds
            line.autoresizingMask = [.width, .height]
            button.addSubview(line)
        }
        button.image = nil
        line.show(verse)
        item.length = line.naturalWidth + Self.barPadding
        if isCardOpen, let screen = unsafe button.window?.screen {
            float.show(
                verse, place: .menuBar(anchor: anchor(of: button)), look: .card, on: screen,
                hidesInSharing: settings.hidesInSharing)
        }
    }

    func hideMenuBarLine() {
        guard let item = statusItem(), let button = item.button, unsafe line.superview === button
        else {
            return
        }
        line.removeFromSuperview()
        item.length = NSStatusItem.squareLength
        item.menu = menu
        menu = nil
        button.action = nil
        button.target = nil
        restoreIcon()
    }

    @objc
    func clicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp, let item = statusItem() {
            item.menu = menu
            sender.performClick(nil)
            item.menu = nil
            return
        }
        isCardOpen.toggle()
        if isCardOpen {
            update()
        } else {
            float.hide(animated: true)
        }
    }

    private func anchor(of button: NSStatusBarButton) -> NSRect {
        guard let window = unsafe button.window else { return .zero }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }
}
