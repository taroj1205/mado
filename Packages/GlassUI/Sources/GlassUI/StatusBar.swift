public import AppKit

public final class StatusBar: NSScrollView {
    public struct Pill: Sendable, Equatable {
        public let id: String
        public let name: String
        public let symbol: String
        public let value: String
        public let unit: String
        public let action: String

        var spoken: String {
            unit.isEmpty ? "\(name): \(value)" : "\(name): \(value) \(unit)"
        }

        public init(
            id: String, name: String, symbol: String, value: String, action: String,
            unit: String = ""
        ) {
            self.id = id
            self.name = name
            self.symbol = symbol
            self.value = value
            self.unit = unit
            self.action = action
        }
    }

    static let height: CGFloat = 60
    private static let gap: CGFloat = 6
    private static let edge: CGFloat = 2

    var pills: [Pill] = [] {
        didSet {
            guard pills != oldValue else { return }
            stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            for (index, pill) in pills.enumerated() {
                stack.addArrangedSubview(makeView(for: pill, at: index))
            }
        }
    }

    var onPress: ((Int) -> Void)?
    private let stack = NSStackView()

    var views: [StatusPill] {
        stack.arrangedSubviews.compactMap { $0 as? StatusPill }
    }

    init() {
        super.init(frame: .zero)
        stack.spacing = Self.gap
        stack.edgeInsets = NSEdgeInsets(top: 0, left: Self.edge, bottom: 0, right: Self.edge)
        stack.translatesAutoresizingMaskIntoConstraints = false
        documentView = stack
        drawsBackground = false
        hasHorizontalScroller = false
        verticalScrollElasticity = .none
        translatesAutoresizingMaskIntoConstraints = false
        let fit = widthAnchor.constraint(equalTo: stack.widthAnchor)
        fit.priority = .defaultLow
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: Self.height),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            fit,
        ])
        setAccessibilityRole(.group)
        setAccessibilityLabel("Status widgets")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    func highlight(_ index: Int?) {
        for (position, view) in views.enumerated() {
            view.selected = position == index
            if position == index {
                view.scrollToVisible(view.bounds)
            }
        }
    }

    private func makeView(for pill: Pill, at index: Int) -> StatusPill {
        let view = StatusPill()
        let unit = pill.unit.isEmpty ? "" : " \(pill.unit)"
        view.show(StatusPill.styled(bold: pill.value, rest: unit), symbol: pill.symbol)
        view.onPress = { [weak self] in self?.onPress?(index) }
        view.setAccessibilityElement(true)
        view.setAccessibilityRole(.button)
        view.setAccessibilityLabel(pill.spoken)
        return view
    }
}
