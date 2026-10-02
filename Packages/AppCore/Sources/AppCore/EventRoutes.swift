import CoreGraphics

@MainActor
struct EventRoutes {
    private struct Route {
        let id: UInt
        let mask: CGEventMask
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
        let id = nextID
        nextID += 1
        routes.append(
            Route(
                id: id, mask: types.reduce(0) { $0 | CGEventMask(1) << $1.rawValue },
                swallow: swallow))
        return id
    }

    mutating func remove(_ id: UInt) {
        routes.removeAll { $0.id == id }
    }

    func dispatch(_ type: CGEventType, _ event: CGEvent) -> Bool {
        let bit = CGEventMask(1) << type.rawValue
        for route in routes where route.mask & bit != 0 && route.swallow(type, event) {
            return true
        }
        return false
    }
}
