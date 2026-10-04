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
            if self?.launcherView.showsGrid == true {
                self?.searchAgain()
            }
        }
        emojiPicker.onLoad = { [weak self] tabs in
            self?.launcherView.emojiGrid.tabs = tabs
            self?.searchAgain()
        }
        launcherView.emojiGrid.accessory = emojiPicker.toneAccessory
        launcherView.onGridChange = { [weak self] _ in self?.fitLauncher() }
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
