import Foundation

enum GeographicLevel: String, CaseIterable, Identifiable, Sendable {
    case country = "Countries"
    case state = "States & Regions"
    case city = "Cities"

    var id: String { rawValue }
    var singular: String {
        switch self {
        case .country: return "country"
        case .state: return "state or region"
        case .city: return "city"
        }
    }
}

struct GeoLocality: Hashable, Sendable {
    let cityID: Int
    let city: String
    let state: String
    let stateCode: String
    let country: String
    let countryCode: String
    let point: GeoPoint
    let distanceMeters: Double
}

struct GeographicSummary: Identifiable, Hashable, Sendable {
    let id: String
    let level: GeographicLevel
    let name: String
    let parentName: String
    let countryCode: String
    let point: GeoPoint
    let visits: Int
    let journeys: Int
    let distanceMeters: Double
    let activeDays: Int
    let firstSeen: Date
    let lastSeen: Date

    var flag: String {
        countryCode.uppercased().unicodeScalars.compactMap {
            UnicodeScalar(127397 + Int($0.value)).map(String.init)
        }.joined()
    }
}

struct GeographicSnapshot: Sendable {
    let countries: [GeographicSummary]
    let states: [GeographicSummary]
    let cities: [GeographicSummary]

    static let empty = GeographicSnapshot(countries: [], states: [], cities: [])

    func summaries(for level: GeographicLevel) -> [GeographicSummary] {
        switch level {
        case .country: return countries
        case .state: return states
        case .city: return cities
        }
    }
}

struct GeographicAnalytics: Sendable {
    let all: GeographicSnapshot
    let byYear: [Int: GeographicSnapshot]
    let localitiesByPlaceKey: [String: GeoLocality]
    let matchedEvents: Int

    static let empty = GeographicAnalytics(all: .empty, byYear: [:], localitiesByPlaceKey: [:], matchedEvents: 0)

    var countries: [GeographicSummary] { all.countries }
    var states: [GeographicSummary] { all.states }
    var cities: [GeographicSummary] { all.cities }

    func summaries(for level: GeographicLevel, year: Int? = nil) -> [GeographicSummary] {
        (year.flatMap { byYear[$0] } ?? all).summaries(for: level)
    }
}
