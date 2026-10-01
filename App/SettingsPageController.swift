import AppCore
import AppKit

final class SettingsPageController: NSViewController {
    private static let titleHeight: CGFloat = 52
    private static let titleCenter: CGFloat = 26
    private static let titleSize: CGFloat = 15
    private static let headerSize: CGFloat = 12
    private static let headerInset: CGFloat = 4
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
    private var switches: [SettingsSwitch] = []

    init(page: SettingsPage, modules: ModuleManager?) {
        self.page = page
        self.modules = modules
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func loadView() {
        var sections = page.sections()
        if let module = page.module {
            sections.insert(moduleSection(module), at: 0)
        }
        switches = sections.flatMap(\.rows).compactMap { $0.control as? SettingsSwitch }

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
        for toggle in switches {
            toggle.refresh()
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

        let header = NSTextField(labelWithString: title)
        header.font = .systemFont(ofSize: Self.headerSize, weight: .semibold)
        header.textColor = .secondaryLabelColor
        let group = NSStackView(views: [header, box])
        group.orientation = .vertical
        group.alignment = .leading
        group.spacing = Self.headerSpacing
        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(
                equalTo: group.leadingAnchor, constant: Self.headerInset),
            box.widthAnchor.constraint(equalTo: group.widthAnchor),
        ])
        return group
    }

    private func rowView(_ row: SettingsSection.Row) -> NSView {
        row.control.setAccessibilityLabel(row.label)
        let label = NSTextField(labelWithString: row.label)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let view = NSStackView(views: [label, row.control])
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
