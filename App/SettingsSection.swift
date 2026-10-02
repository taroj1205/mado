import AppKit

struct SettingsSection {
    struct Row {
        let label: String
        let control: NSView
        let icon: NSImage?

        init(_ label: String, _ control: NSView) {
            self.init(label, control, icon: nil)
        }

        init(_ label: String, _ control: NSView, icon: NSImage?) {
            self.label = label
            self.control = control
            self.icon = icon
        }
    }

    let title: String?
    let rows: [Row]
    let footer: NSAttributedString?
    let accessory: NSView?

    init(_ title: String?, _ rows: [Row]) {
        self.init(title, rows, footer: nil, accessory: nil)
    }

    init(_ title: String?, _ rows: [Row], footer: NSAttributedString?, accessory: NSView?) {
        self.title = title
        self.rows = rows
        self.footer = footer
        self.accessory = accessory
    }
}
