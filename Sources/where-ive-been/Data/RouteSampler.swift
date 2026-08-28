import Foundation

struct RouteSelection: Sendable {
    let visible: [JourneyEvent]
    let totalCount: Int
}

struct RouteSampler: Sendable {
    func select(from events: [JourneyEvent], limit: Int) -> RouteSelection {
        let routes = events.filter {
            ($0.kind == .activity || $0.kind == .path) &&
            ($0.path.count > 1 || ($0.point != nil && $0.endPoint != nil))
        }
        guard routes.count > limit, limit > 1 else {
            return RouteSelection(visible: routes, totalCount: routes.count)
        }

        let step = Double(routes.count - 1) / Double(limit - 1)
        let visible = (0..<limit).map { routes[Int((Double($0) * step).rounded())] }
        return RouteSelection(visible: visible, totalCount: routes.count)
    }
}
