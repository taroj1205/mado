import AppKit
import ClipboardKit
import GlassUI

extension AppDelegate {
    private static let gridHeight: CGFloat = 580
    private static let half: CGFloat = 0.5

    func connectEmoji() {
        emojiPicker.settings = .load(from: modules)
        emojiPicker.onOpen = { [weak self] in self?.openEmoji() }
        emojiPicker.onChange = { [weak self] settings in
            settings.save(to: self?.modules)
            self?.emojiChanged()
        }
        emojiPicker.onLoad = { [weak self] in self?.emojiChanged() }
        emojiPicker.onUnload = { [weak self] in self?.emojiChanged() }
        launcherView.emojiGrid.accessory = emojiPicker.toneAccessory
        launcherView.onGridChange = { [weak self] _ in self?.fitLauncher() }
    }

    private func emojiChanged() {
        launcherView.emojiGrid.tabs = emojiPicker.tabs
        if launcherView.showsGrid || emojiPicker.query(in: launcherView.field.stringValue) != nil {
            searchAgain()
        }
    }

    func gridHeight(otherwise height: CGFloat) -> CGFloat {
        launcherView.showsGrid ? Self.gridHeight : height
    }

    private func fitLauncher() {
        guard let launcher, launcher.isVisible else { return }
        let size = launcherSize
        var frame = launcher.frame
        frame.origin.y += (frame.height - size.height) * Self.half
        frame.size = size
        launcher.setFrame(frame, display: true)
    }

    private func openEmoji() {
        if launcher?.isVisible != true {
            showLauncher()
        }
        editor.close()
        enteredScope = .emoji
        launcherView.enter(placeholder: EmojiPicker.placeholder)
    }
}
