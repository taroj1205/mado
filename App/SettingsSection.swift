import AppKit

struct SettingsSection {
    struct Row {
        let label: String
        let control: NSControl

        init(_ label: String, _ control: NSControl) {
            self.label = label
            self.control = control
        }
    }

    let title: String?
    let rows: [Row]

    init(_ title: String?, _ rows: [Row]) {
        self.title = title
        self.rows = rows
    }
}
