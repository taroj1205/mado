import AppCore
import AppKit
import os

final class SettingsPopUp: NSPopUpButton {
    struct Section {
        let title: String?
        let choices: [Choice]
    }

    struct Choice {
        let title: String
        let isSelected: Bool
        var isEnabled = true
        let select: () throws -> Void
    }

    var takesSearchFocus = false {
        didSet { cell?.showsFirstResponder = takesSearchFocus }
    }
    var choiceTitles: [String] {
        choices.map(\.title)
    }
    override var acceptsFirstResponder: Bool {
        takesSearchFocus || super.acceptsFirstResponder
    }

    private let logger = Log.logger("Settings")
    private let sections: () -> [Section]
    private var choices: [Choice] = []

    init(_ sections: @escaping () -> [Section]) {
        self.sections = sections
        super.init(frame: .zero, pullsDown: false)
        autoenablesItems = false
        setContentHuggingPriority(.defaultHigh, for: .horizontal)
        target = self
        action = #selector(changed)
        refresh()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func resignFirstResponder() -> Bool {
        takesSearchFocus = false
        return super.resignFirstResponder()
    }

    func refresh() {
        let menu = NSMenu()
        var selected: NSMenuItem?
        choices = []
        for section in sections() where !section.choices.isEmpty {
            if !menu.items.isEmpty {
                menu.addItem(.separator())
            }
            if let title = section.title {
                menu.addItem(.sectionHeader(title: title))
            }
            for choice in section.choices {
                let item = NSMenuItem(title: choice.title, action: nil, keyEquivalent: "")
                item.tag = choices.count
                item.isEnabled = choice.isEnabled
                menu.addItem(item)
                choices.append(choice)
                if choice.isSelected {
                    selected = item
                }
            }
        }
        self.menu = menu
        select(selected)
    }

    @objc
    private func changed() {
        do {
            try choices[selectedTag()].select()
        } catch {
            let name = accessibilityLabel() ?? ""
            logger.error("\(name, privacy: .public) failed: \(error, privacy: .public)")
            presentError(error)
        }
        refresh()
    }
}
