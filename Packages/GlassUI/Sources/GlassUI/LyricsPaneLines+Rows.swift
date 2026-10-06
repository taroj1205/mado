import AppKit

extension LyricsPaneLines {
    func makeRow(_ index: Int, text: String) -> Row {
        let box = CALayer()
        box.anchorPoint = CGPoint(x: 0, y: Self.half)
        layer?.addSublayer(box)
        let element = LyricsPaneRow()
        element.setAccessibilityParent(self)
        element.setAccessibilityLabel(text.isEmpty ? Self.gapLabel : text)
        element.setAccessibilityRole(mode == .synced ? .button : .staticText)
        if mode == .synced {
            element.setAccessibilityHelp(Self.seekHint)
            element.onPress = { [weak self] in self?.onSeek?(index) }
        }
        guard text.isEmpty else {
            let label = CATextLayer()
            style(label)
            label.string = text
            box.addSublayer(label)
            return Row(box: box, text: label, dots: nil, element: element)
        }
        let dots = mode == .synced ? LyricDots() : nil
        dots.map(box.addSublayer)
        return Row(box: box, text: nil, dots: dots, element: element)
    }

    func style(_ text: CATextLayer) {
        text.font = Self.font
        text.fontSize = Self.fontSize
        text.alignmentMode = .left
        text.truncationMode = .end
    }

    func lay(_ row: Row, at spot: Spot) {
        let width = bounds.width / spot.scale
        row.box.bounds = CGRect(x: 0, y: 0, width: width, height: Self.pitch)
        row.box.position = CGPoint(x: 0, y: spot.centre)
        row.box.transform = CATransform3DMakeScale(spot.scale, spot.scale, 1)
        row.box.opacity = spot.opacity
        row.text?.frame = CGRect(
            x: 0, y: (Self.pitch - Self.textHeight) * Self.half, width: width,
            height: Self.textHeight)
        row.dots?.position = CGPoint(x: LyricDots.width * Self.half, y: Self.pitch * Self.half)
        row.element.setAccessibilityFrameInParentSpace(
            CGRect(
                x: 0, y: spot.centre - Self.pitch * Self.half, width: bounds.width,
                height: Self.pitch))
    }
}
