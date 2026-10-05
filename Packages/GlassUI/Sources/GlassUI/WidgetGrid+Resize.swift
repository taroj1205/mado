import AppKit

extension WidgetGrid {
    func stretch(_ id: String, by distance: CGFloat) {
        guard let window = unsafe window else { return }
        let step = Self.cellWidth(of: window.frame) + Self.floatingGap
        trial = fitted(id, adding: Int((distance / step).rounded())).map { [id: $0] } ?? [:]
    }

    func finishStretch(_ id: String) -> Int? {
        defer { trial = [:] }
        return trial[id]
    }

    func fitted(_ id: String, adding change: Int) -> Int? {
        guard let widget = supplied.first(where: { $0.id == id }) else { return nil }
        let start = min(max(sizes[id] ?? widget.narrowest, widget.narrowest), Self.widest)
        let wanted = min(max(start + change, widget.narrowest), Self.widest)
        return stride(from: wanted, to: start, by: wanted > start ? -1 : 1).first { span in
            let all = widgets.map { other in
                var sized = other
                sized.columns = other.id == id ? span : sized.columns
                return sized
            }
            return fits(all, checking: [home(of: id)]) { self.home(of: $0.id) }
        }
    }
}
