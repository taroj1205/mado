import AppCore
import AppKit

final class MenuBarTimerPanel: NSView, MenuBarPanel {
    private typealias Style = MenuBarPanelStyle

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

    private static let heroSpacing: CGFloat = 16
    private static let buttonSpacing: CGFloat = 6
    private static let hint = "New timer — or type “timer 25m” in the launcher"

    var onResize: ((NSSize) -> Void)?
    private let handlers: Handlers
    private let stack = NSStackView()
    private let ring = TimerRing()
    private let caption = Style.label(Style.captionSize, weight: .semibold, secondary: true)
    private let title = Style.label(Style.titleSize, weight: .semibold, secondary: false)
    private let detail = Style.label(Style.detailSize, weight: .regular, secondary: true)
    private var timeRows: [Countdown.ID: MenuBarPanelRow] = [:]
    private var shape: Shape?

    init(_ handlers: Handlers) {
        self.handlers = handlers
        super.init(frame: .zero)
        Style.install(stack, in: self)
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
        let hero = NSStackView(views: [ring, Style.info([caption, title, detail])])
        hero.spacing = Self.heroSpacing
        stack.addArrangedSubview(hero)
        if !model.buttons.isEmpty {
            let buttons = NSStackView(
                views: model.buttons.map { button in
                    MenuBarPanelButton(button.title, isPrimary: button.isPrimary) { [handlers] in
                        handlers.act(button.action)
                    }
                })
            buttons.spacing = Self.buttonSpacing
            stack.addArrangedSubview(buttons)
        }
        Style.addRule(to: stack)
        for row in model.rows { addRow(row) }
        let newRow = MenuBarPanelRow(
            symbol: "plus", text: Self.hint, trailing: "", isHint: true, isDimmed: false
        ) { [handlers] in
            handlers.newTimer()
        }
        Style.addFullWidth(newRow, to: stack)
        layoutSubtreeIfNeeded()
        setFrameSize(fittingSize)
        onResize?(frame.size)
    }

    private func addRow(_ row: TimerPanel.Row) {
        let view = MenuBarPanelRow(
            symbol: "timer", text: row.name, trailing: "", isHint: false, isDimmed: false
        ) { [handlers] in
            handlers.select(row.id)
        }
        timeRows[row.id] = view
        Style.addFullWidth(view, to: stack)
    }

    private func modes(selected: Timers.Mode) -> NSSegmentedControl {
        let control = NSSegmentedControl(
            labels: Timers.Mode.allCases.map(\.title), trackingMode: .selectOne,
            target: self, action: #selector(modeChanged))
        control.selectedSegment = Timers.Mode.allCases.firstIndex(of: selected) ?? 0
        control.refusesFirstResponder = true
        control.widthAnchor.constraint(equalToConstant: Style.inner).isActive = true
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
