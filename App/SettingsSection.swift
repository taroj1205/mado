import AppKit

struct SettingsSection {
    struct Row {
        let label: String
        let control: NSView
        let icon: NSImage?
        let example: String?
        let detail: (() -> String)?

        init(_ label: String, _ control: NSView) {
            self.init(label, control, icon: nil, example: nil, detail: nil)
        }

        init(_ label: String, _ control: NSView, icon: NSImage?) {
            self.init(label, control, icon: icon, example: nil, detail: nil)
        }

        init(_ label: String, _ control: NSView, example: String?, detail: (() -> String)?) {
            self.init(label, control, icon: nil, example: example, detail: detail)
        }

        private init(
            _ label: String, _ control: NSView, icon: NSImage?, example: String?,
            detail: (() -> String)?
        ) {
            self.label = label
            self.control = control
            self.icon = icon
            self.example = example
            self.detail = detail
        }
    }

    let title: String?
    let note: String?
    let rows: [Row]
    let footer: NSAttributedString?
    let accessory: NSView?
    let content: NSView?

    init(_ title: String?, _ rows: [Row]) {
        self.init(title, note: nil, rows, footer: nil, accessory: nil, content: nil)
    }

    init(_ title: String?, note: String?, _ rows: [Row]) {
        self.init(title, note: note, rows, footer: nil, accessory: nil, content: nil)
    }

    init(_ title: String?, _ rows: [Row], footer: NSAttributedString?, accessory: NSView?) {
        self.init(title, note: nil, rows, footer: footer, accessory: accessory, content: nil)
    }

    init(content: NSView) {
        self.init(nil, note: nil, [], footer: nil, accessory: nil, content: content)
    }

    private init(
        _ title: String?, note: String?, _ rows: [Row], footer: NSAttributedString?,
        accessory: NSView?, content: NSView?
    ) {
        self.title = title
        self.note = note
        self.rows = rows
        self.footer = footer
        self.accessory = accessory
        self.content = content
    }
}
