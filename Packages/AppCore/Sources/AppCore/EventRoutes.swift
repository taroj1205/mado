import CoreGraphics

@MainActor
struct EventRoutes {
    private struct Route {
        let id: UInt
        let mask: CGEventMask
        let observes: Bool
        let swallow: @MainActor (CGEventType, CGEvent) -> Bool
    }

    private var routes: [Route] = []
    private var nextID: UInt = 0

    var mask: CGEventMask {
        routes.reduce(0) { $0 | $1.mask }
    }

    mutating func add(
        types: [CGEventType], swallow: @escaping @MainActor (CGEventType, CGEvent) -> Bool
    ) -> UInt {
        append(types, observes: false, swallow)
    }

    mutating func observe(
        types: [CGEventType], observe: @escaping @MainActor (CGEventType, CGEvent) -> Void
    ) -> UInt {
        append(types, observes: true) { type, event in
            observe(type, event)
            return false
        }
    }

    mutating func remove(_ id: UInt) {
        routes.removeAll { $0.id == id }
    }

    func dispatch(_ type: CGEventType, _ event: CGEvent) -> Bool {
        let bit = CGEventMask(1) << type.rawValue
        var swallowed = false
        for route in routes where route.mask & bit != 0 && (route.observes || !swallowed) {
            swallowed = route.swallow(type, event) || swallowed
        }
        return swallowed
    }

    private mutating func append(
        _ types: [CGEventType], observes: Bool,
        _ swallow: @escaping @MainActor (CGEventType, CGEvent) -> Bool
    ) -> UInt {
        let id = nextID
        nextID += 1
        routes.append(
            Route(
                id: id, mask: types.reduce(0) { $0 | CGEventMask(1) << $1.rawValue },
                observes: observes, swallow: swallow))
        return id
    }
}
