import Foundation
import CoreLocation
import SwiftUI

struct GeoPoint: Hashable, Sendable, Codable {
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var compactLabel: String {
        String(format: "%.4f, %.4f", latitude, longitude)
    }

    static func parse(_ value: String?) -> GeoPoint? {
        guard let value else { return nil }
        let clean = value.hasPrefix("geo:") ? String(value.dropFirst(4)) : value
        let pieces = clean.split(separator: ",", maxSplits: 1).map(String.init)
        guard pieces.count == 2,
              let latitude = Double(pieces[0]),
              let longitude = Double(pieces[1]),
              (-90...90).contains(latitude),
              (-180...180).contains(longitude) else { return nil }
        return GeoPoint(latitude: latitude, longitude: longitude)
    }
}

enum JourneyEventKind: String, Hashable, Sendable {
    case visit
    case activity
    case path
}

struct JourneyEvent: Identifiable, Hashable, Sendable {
    let id: Int
    let kind: JourneyEventKind
    let start: Date
    let end: Date
    let point: GeoPoint?
    let endPoint: GeoPoint?
    let path: [GeoPoint]
    let title: String
    let subtitle: String
    let distanceMeters: Double
    let probability: Double?
    let placeID: String?

    var duration: TimeInterval { max(0, end.timeIntervalSince(start)) }
    var year: Int { Calendar.autoupdatingCurrent.component(.year, from: start) }

    var symbol: String {
        switch kind {
        case .visit: return "mappin.and.ellipse"
        case .path: return "point.topleft.down.to.point.bottomright.curvepath"
        case .activity:
            switch title.lowercased() {
            case let value where value.contains("walking"): return "figure.walk"
            case let value where value.contains("cycling"): return "bicycle"
            case let value where value.contains("flying"): return "airplane"
            case let value where value.contains("train") || value.contains("subway") || value.contains("tram"): return "tram.fill"
            case let value where value.contains("bus"): return "bus.fill"
            case let value where value.contains("ferry"): return "ferry.fill"
            case let value where value.contains("motorcycling"): return "motorcycle.fill"
            default: return "car.fill"
            }
        }
    }

    var tint: Color {
        switch kind {
        case .visit: return .orange
        case .path: return .cyan
        case .activity:
            switch title.lowercased() {
            case let value where value.contains("walking"): return .mint
            case let value where value.contains("cycling"): return .green
            case let value where value.contains("flying"): return .purple
            case let value where value.contains("train") || value.contains("subway") || value.contains("tram"): return .pink
            default: return .blue
            }
        }
    }
}

struct JourneyDataset: Sendable {
    let events: [JourneyEvent]
    let sourceURL: URL
    let importedAt: Date
    let skippedRecords: Int

    static let empty = JourneyDataset(events: [], sourceURL: URL(fileURLWithPath: "/"), importedAt: .now, skippedRecords: 0)
}

struct YearSummary: Identifiable, Hashable, Sendable {
    let year: Int
    let visits: Int
    let activities: Int
    let distanceMeters: Double
    let activeDays: Int
    var id: Int { year }
}

struct ModeSummary: Identifiable, Hashable, Sendable {
    let name: String
    let count: Int
    let distanceMeters: Double
    var id: String { name }

    var symbol: String {
        let value = name.lowercased()
        if value.contains("walking") { return "figure.walk" }
        if value.contains("cycling") { return "bicycle" }
        if value.contains("flying") { return "airplane" }
        if value.contains("train") || value.contains("subway") || value.contains("tram") { return "tram.fill" }
        if value.contains("bus") { return "bus.fill" }
        if value.contains("ferry") { return "ferry.fill" }
        if value.contains("motorcycling") { return "motorcycle.fill" }
        return "car.fill"
    }
}

struct MonthSummary: Identifiable, Hashable, Sendable {
    let month: Date
    let distanceMeters: Double
    let visits: Int
    let journeys: Int
    let activeDays: Int
    var id: Date { month }
}

struct SeasonalSummary: Identifiable, Hashable, Sendable {
    let month: Int
    let distanceMeters: Double
    let visits: Int
    let journeys: Int
    let activeDays: Int
    let activeYears: Int
    var id: Int { month }

    var name: String { Calendar.autoupdatingCurrent.monthSymbols[month - 1] }
    var shortName: String { Calendar.autoupdatingCurrent.shortMonthSymbols[month - 1] }
}

struct WeekdaySummary: Identifiable, Hashable, Sendable {
    let weekday: Int
    let distanceMeters: Double
    let visits: Int
    let journeys: Int
    let activeDays: Int
    var id: Int { weekday }

    var name: String { Calendar.autoupdatingCurrent.weekdaySymbols[weekday - 1] }
    var shortName: String { Calendar.autoupdatingCurrent.shortWeekdaySymbols[weekday - 1] }
}

struct HourSummary: Identifiable, Hashable, Sendable {
    let hour: Int
    let events: Int
    let visits: Int
    let journeys: Int
    let distanceMeters: Double
    var id: Int { hour }

    var label: String {
        let date = Calendar.autoupdatingCurrent.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now
        return date.formatted(.dateTime.hour())
    }
}

struct PlaceSummary: Identifiable, Hashable, Sendable {
    let key: String
    let name: String
    let point: GeoPoint
    let visits: Int
    let totalDuration: TimeInterval
    let mostRecent: Date
    var id: String { key }
}

struct DaySummary: Identifiable, Hashable, Sendable {
    let date: Date
    let eventCount: Int
    let distanceMeters: Double
    let events: [JourneyEvent]
    var id: Date { date }
}

struct JourneyAnalytics: Sendable {
    let dateRange: ClosedRange<Date>?
    let totalDistanceMeters: Double
    let totalVisitDuration: TimeInterval
    let visitCount: Int
    let activityCount: Int
    let years: [Int]
    let yearSummaries: [YearSummary]
    let modeSummaries: [ModeSummary]
    let monthSummaries: [MonthSummary]
    let seasonalSummaries: [SeasonalSummary]
    let weekdaySummaries: [WeekdaySummary]
    let hourSummaries: [HourSummary]
    let topPlaces: [PlaceSummary]
    let days: [DaySummary]
    let activeDayCount: Int
    let longestActivity: JourneyEvent?
    let longestVisit: JourneyEvent?
    let averageJourneyDistance: Double
    let medianJourneyDistance: Double
    let longestActiveStreak: Int

    static let empty = JourneyAnalytics(
        dateRange: nil, totalDistanceMeters: 0, totalVisitDuration: 0,
        visitCount: 0, activityCount: 0, years: [], yearSummaries: [],
        modeSummaries: [], monthSummaries: [], seasonalSummaries: [],
        weekdaySummaries: [], hourSummaries: [], topPlaces: [], days: [],
        activeDayCount: 0, longestActivity: nil, longestVisit: nil,
        averageJourneyDistance: 0, medianJourneyDistance: 0, longestActiveStreak: 0
    )
}
