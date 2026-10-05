import AppCore
import AppKit

final class MenuBarTimerPanel: NSView {
    struct Handlers {
        let act: (TimerPanel.Action) -> Void
        let show: (Timers.Mode) -> Void
        let select: (Countdown.ID) -> Void
        let newTimer: () -> Void
    }

    private struct Shape: Equatable {
        let mode: Timers.Mode
        let buttons: [TimerPanel.Button]
        let rows: [String]

        init(_ model: TimerPanel) {
            mode = model.mode
            buttons = model.buttons
            rows = model.rows.map { "\($0.id)\($0.name)" }
        }
    }

    private static let width: CGFloat = 320
    private static let padding: CGFloat = 14
    private static let spacing: CGFloat = 10
    private static let infoSpacing: CGFloat = 4
    private static let heroSpacing: CGFloat = 16
    private static let buttonSpacing: CGFloat = 6
    private static let captionSize: CGFloat = 11.5
    private static let titleSize: CGFloat = 14
    private static let detailSize: CGFloat = 12.5
    private static let inner = width - padding - padding
    private static let hint = "New timer — or type “timer 25m” in the launcher"

    var onResize: ((NSSize) -> Void)?
    private let handlers: Handlers
    private let stack = NSStackView()
    private let ring = TimerRing()
    private let caption = NSTextField(labelWithString: "")
    private let title = NSTextField(labelWithString: "")
    private let detail = NSTextField(labelWithString: "")
    private var timeRows: [Countdown.ID: TimerPanelRow] = [:]
    private var shape: Shape?

    init(_ handlers: Handlers) {
        self.handlers = handlers
        super.init(frame: .zero)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Self.spacing
        stack.edgeInsets = NSEdgeInsets(
            top: Self.padding, left: Self.padding, bottom: Self.padding, right: Self.padding)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            widthAnchor.constraint(equalToConstant: Self.width),
        ])
        caption.font = .systemFont(ofSize: Self.captionSize, weight: .semibold)
        caption.textColor = .secondaryLabelColor
        title.font = .systemFont(ofSize: Self.titleSize, weight: .semibold)
        detail.font = .systemFont(ofSize: Self.detailSize)
        detail.textColor = .secondaryLabelColor
        for label in [caption, title, detail] {
            label.lineBreakMode = .byTruncatingTail
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    func update(_ model: TimerPanel) {
        let next = Shape(model)
        if next != shape {
            shape = next
            rebuild(model)
        }
        caption.stringValue = model.caption
        title.stringValue = model.title
        detail.stringValue = model.detail
        ring.show(model.clock, fraction: model.fraction, state: model.state)
        for row in model.rows { timeRows[row.id]?.show(time: row.time) }
    }

    private func rebuild(_ model: TimerPanel) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        timeRows = [:]
        stack.addArrangedSubview(modes(selected: model.mode))
        let info = NSStackView(views: [caption, title, detail])
        info.orientation = .vertical
        info.alignment = .leading
        info.spacing = Self.infoSpacing
        let hero = NSStackView(views: [ring, info])
        hero.spacing = Self.heroSpacing
        stack.addArrangedSubview(hero)
        if !model.buttons.isEmpty {
            let buttons = NSStackView(
                views: model.buttons.map { button in
                    TimerPanelButton(button.title, isPrimary: button.isPrimary) { [handlers] in
                        handlers.act(button.action)
                    }
                })
            buttons.spacing = Self.buttonSpacing
            stack.addArrangedSubview(buttons)
        }
        let rule = NSBox()
        rule.boxType = .separator
        stack.addArrangedSubview(rule)
        rule.widthAnchor.constraint(equalToConstant: Self.inner).isActive = true
        for row in model.rows { addRow(row) }
        let newRow = TimerPanelRow(symbol: "plus", text: Self.hint, isHint: true) { [handlers] in
            handlers.newTimer()
        }
        stack.addArrangedSubview(newRow)
        newRow.widthAnchor.constraint(equalToConstant: Self.inner).isActive = true
        layoutSubtreeIfNeeded()
        setFrameSize(fittingSize)
        onResize?(frame.size)
    }

    private func addRow(_ row: TimerPanel.Row) {
        let view = TimerPanelRow(symbol: "timer", text: row.name, isHint: false) { [handlers] in
            handlers.select(row.id)
        }
        timeRows[row.id] = view
        stack.addArrangedSubview(view)
        view.widthAnchor.constraint(equalToConstant: Self.inner).isActive = true
    }

    private func modes(selected: Timers.Mode) -> NSSegmentedControl {
        let control = NSSegmentedControl(
            labels: Timers.Mode.allCases.map(\.title), trackingMode: .selectOne,
            target: self, action: #selector(modeChanged))
        control.selectedSegment = Timers.Mode.allCases.firstIndex(of: selected) ?? 0
        control.refusesFirstResponder = true
        control.widthAnchor.constraint(equalToConstant: Self.inner).isActive =
            true
        return control
    }

    @objc
    private func modeChanged(_ sender: NSSegmentedControl) {
        handlers.show(Timers.Mode.allCases[sender.selectedSegment])
    }
}

extension Timers.Mode {
    var title: String {
        switch self {
        case .timer: "Timer"
        case .stopwatch: "Stopwatch"
        case .pomodoro: "Pomodoro"
        }
    }
}
