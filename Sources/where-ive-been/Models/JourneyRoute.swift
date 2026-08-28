import Foundation
import CoreLocation

struct JourneyRoute: Hashable, Sendable {
    let event: JourneyEvent
    let points: [GeoPoint]
    let distanceMeters: Double
    let distanceIsEstimated: Bool

    var hasPath: Bool { points.count > 1 }
    var startPoint: GeoPoint? { points.first }
    var endPoint: GeoPoint? { points.last }

    init(event: JourneyEvent) {
        self.event = event

        var normalized = event.path
        if normalized.isEmpty {
            normalized = [event.point, event.endPoint].compactMap { $0 }
        } else {
            if let start = event.point, normalized.first != start { normalized.insert(start, at: 0) }
            if let end = event.endPoint, normalized.last != end { normalized.append(end) }
        }
        points = normalized

        if event.distanceMeters > 0 {
            distanceMeters = event.distanceMeters
            distanceIsEstimated = false
        } else if normalized.count > 1 {
            distanceMeters = zip(normalized, normalized.dropFirst()).reduce(0) {
                $0 + Self.distance(from: $1.0, to: $1.1)
            }
            distanceIsEstimated = true
        } else {
            distanceMeters = 0
            distanceIsEstimated = false
        }
    }

    private static func distance(from lhs: GeoPoint, to rhs: GeoPoint) -> Double {
        CLLocation(latitude: lhs.latitude, longitude: lhs.longitude)
            .distance(from: CLLocation(latitude: rhs.latitude, longitude: rhs.longitude))
    }
}
