import AppKit

extension WidgetTile {
    func trackConstraints() -> [NSLayoutConstraint] {
        [
            track.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.horizontal),
            track.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.horizontal),
            track.topAnchor.constraint(equalTo: topAnchor, constant: Self.vertical),
            track.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.vertical),
        ]
    }

    func showFace() {
        let rich = !form.isPlain && widget?.usesFace(form) == true
        face.isHidden = !rich
        lines.isHidden = rich
        icon.isHidden = rich
        meters.isHidden = rich
        track.form = form
        if rich, let widget {
            face.show(widget, form: form, compact: compact)
        }
    }
}
