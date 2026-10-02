import AppCore
import AppKit
import SearchKit

final class SettingsPageController: NSViewController {
    private static let titleHeight: CGFloat = 52
    private static let titleCenter: CGFloat = 26
    private static let titleSize: CGFloat = 15
    private static let headerSize: CGFloat = 12
    private static let headerInset: CGFloat = 4
    private static let captionSize: CGFloat = 11
    private static let rowHeight: CGFloat = 40
    private static let rowPadding: CGFloat = 12
    private static let cornerRadius: CGFloat = 10
    private static let sectionSpacing: CGFloat = 14
    private static let headerSpacing: CGFloat = 6
    private static let leading: CGFloat = 20
    private static let trailing: CGFloat = 24
    private static let bottom: CGFloat = 16

    private let page: SettingsPage
    private let modules: ModuleManager?
    private let hotKeys: LauncherHotKeys
    private let rates: ExchangeRateFeed
    private var switches: [SettingsSwitch] = []
    private var popUps: [SettingsPopUp] = []
    private var details: [(label: NSTextField, text: () -> String)] = []

    init(
        page: SettingsPage, modules: ModuleManager?, hotKeys: LauncherHotKeys,
        rates: ExchangeRateFeed
    ) {
        self.page = page
        self.modules = modules
        self.hotKeys = hotKeys
        self.rates = rates
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func loadView() {
        var sections = page.sections(modules, hotKeys, rates)
        if let module = page.module {
            sections.insert(moduleSection(module), at: 0)
        }
        let controls = sections.flatMap(\.rows).map(\.control)
        switches = controls.compactMap { $0 as? SettingsSwitch }
        popUps = controls.compactMap { $0 as? SettingsPopUp }

        let heading = NSTextField(labelWithString: page.title)
        heading.font = .systemFont(ofSize: Self.titleSize, weight: .semibold)
        heading.translatesAutoresizingMaskIntoConstraints = false
        let stack = NSStackView(views: sections.map(sectionView))
        stack.orientation = .vertical
        stack.spacing = Self.sectionSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        let view = NSView()
        view.addSubview(heading)
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            heading.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Self.leading),
            heading.centerYAnchor.constraint(equalTo: view.topAnchor, constant: Self.titleCenter),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: Self.titleHeight),
            stack.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Self.trailing),
            stack.bottomAnchor.constraint(
                lessThanOrEqualTo: view.bottomAnchor, constant: -Self.bottom),
        ])
        for section in stack.arrangedSubviews {
            section.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        self.view = view
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        refresh()
    }

    func refresh() {
        for toggle in switches {
            toggle.refresh()
        }
        for popUp in popUps {
            popUp.refresh()
        }
        for detail in details {
            detail.label.stringValue = detail.text()
        }
    }

    private func moduleSection(_ module: ModuleDescriptor) -> SettingsSection {
        let toggle = SettingsSwitch(
            read: { [modules] in modules?.isEnabled(module.id) ?? false },
            write: { [modules] in try modules?.setEnabled(module.id, $0) })
        toggle.isEnabled = modules != nil
        return SettingsSection(nil, [.init(module.name, toggle)])
    }

    private func sectionView(_ section: SettingsSection) -> NSView {
        let rows = NSStackView()
        rows.orientation = .vertical
        rows.spacing = 0
        rows.translatesAutoresizingMaskIntoConstraints = false
        for (index, row) in section.rows.enumerated() {
            if index > 0 {
                rows.addArrangedSubview(separator())
            }
            rows.addArrangedSubview(rowView(row))
        }
        for row in rows.arrangedSubviews {
            row.widthAnchor.constraint(equalTo: rows.widthAnchor).isActive = true
        }
        let box = NSBox()
        box.boxType = .custom
        box.titlePosition = .noTitle
        box.cornerRadius = Self.cornerRadius
        box.fillColor = .quaternarySystemFill
        box.borderColor = .separatorColor
        box.addSubview(rows)
        NSLayoutConstraint.activate([
            rows.topAnchor.constraint(equalTo: box.topAnchor),
            rows.bottomAnchor.constraint(equalTo: box.bottomAnchor),
            rows.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            rows.trailingAnchor.constraint(equalTo: box.trailingAnchor),
        ])
        guard let title = section.title else { return box }

        let header = header(title, note: section.note)
        let group = NSStackView(views: [header, box])
        group.orientation = .vertical
        group.alignment = .leading
        group.spacing = Self.headerSpacing
        box.widthAnchor.constraint(equalTo: group.widthAnchor).isActive = true
        header.widthAnchor.constraint(equalTo: group.widthAnchor).isActive = true
        return group
    }

    private func header(_ title: String, note: String?) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: Self.headerSize, weight: .semibold)
        label.textColor = .secondaryLabelColor
        let header = NSStackView(views: [label])
        header.edgeInsets = NSEdgeInsets(
            top: 0, left: Self.headerInset, bottom: 0, right: Self.headerInset)
        if let note {
            let noteLabel = NSTextField(labelWithString: note)
            noteLabel.font = .systemFont(ofSize: Self.headerSize)
            noteLabel.textColor = .secondaryLabelColor
            header.addArrangedSubview(NSView())
            header.addArrangedSubview(noteLabel)
        }
        return header
    }

    private func rowView(_ row: SettingsSection.Row) -> NSView {
        row.control.setAccessibilityLabel(row.label)
        let label = NSTextField(labelWithString: row.label)
        var title: NSView = label
        if let detail = row.detail {
            let detailLabel = NSTextField(labelWithString: detail())
            detailLabel.font = .systemFont(ofSize: Self.captionSize)
            detailLabel.textColor = .secondaryLabelColor
            details.append((detailLabel, detail))
            let lines = NSStackView(views: [label, detailLabel])
            lines.orientation = .vertical
            lines.alignment = .leading
            lines.spacing = 0
            title = lines
        }
        title.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let view = NSStackView(views: [title])
        if let example = row.example {
            let exampleLabel = NSTextField(labelWithString: example)
            exampleLabel.font = .monospacedSystemFont(ofSize: Self.captionSize, weight: .regular)
            exampleLabel.textColor = .secondaryLabelColor
            view.addArrangedSubview(exampleLabel)
        }
        view.addArrangedSubview(row.control)
        view.distribution = .fill
        view.edgeInsets = NSEdgeInsets(
            top: 0, left: Self.rowPadding, bottom: 0, right: Self.rowPadding)
        view.heightAnchor.constraint(equalToConstant: Self.rowHeight).isActive = true
        return view
    }

    private func separator() -> NSView {
        let line = NSBox()
        line.boxType = .separator
        let inset = NSStackView(views: [line])
        inset.edgeInsets = NSEdgeInsets(
            top: 0, left: Self.rowPadding, bottom: 0, right: Self.rowPadding)
        return inset
    }
}
