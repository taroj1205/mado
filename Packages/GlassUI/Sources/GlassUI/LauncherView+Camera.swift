import AppKit

extension LauncherView {
    public var showsCamera: Bool { !camera.isHidden }

    public func showCamera(_ shown: Bool) {
        let changed = shown != showsCamera
        camera.isHidden = !shown
        results.isHidden = shown || showsGrid || showsLyrics || editingWidgets
        showAction(of: selectedItem)
        if changed {
            onFit?()
        }
    }

    func placeCamera(below separator: NSView) {
        NSLayoutConstraint.activate([
            camera.leadingAnchor.constraint(equalTo: leadingAnchor),
            camera.trailingAnchor.constraint(equalTo: trailingAnchor),
            camera.topAnchor.constraint(equalTo: separator.bottomAnchor),
            camera.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    func cameraCommand(_ selector: Selector, in textView: NSTextView) -> Bool {
        guard selector == #selector(NSResponder.insertNewline), !textView.hasMarkedText()
        else { return false }
        camera.shoot()
        return true
    }
}
