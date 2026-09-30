import AppKit

// M0-01 placeholder entry point (no nib / storyboard). M0-03 turns this into the real agent startup.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
