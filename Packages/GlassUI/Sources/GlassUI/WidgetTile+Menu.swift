import AppKit

extension WidgetTile {
    private static let moreInset: CGFloat = 5

    func arrangeMenu() {
        hover.frame = bounds
        hover.autoresizingMask = [.width, .height]
        hover.onChange = { [weak self] hovered in self?.hovered = hovered }
        more.onPress = { [weak self] in self?.onMenu?() }
        more.translatesAutoresizingMaskIntoConstraints = false
        more.isHidden = true
        addSubview(hover)
        addSubview(more)
        NSLayoutConstraint.activate([
            more.widthAnchor.constraint(equalToConstant: WidgetMoreButton.size),
            more.heightAnchor.constraint(equalToConstant: WidgetMoreButton.size),
            more.topAnchor.constraint(equalTo: topAnchor, constant: Self.moreInset),
            more.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.moreInset),
        ])
    }

    func showMore() {
        more.isHidden = !(widget?.isMedia == true && (selected || hovered) && !editing)
    }
}
