import Foundation

struct GeographicIndex: Sendable {
    enum IndexError: LocalizedError {
        case missingResource(String)
        case unreadableResource(String)

        var errorDescription: String? {
            switch self {
            case .missingResource(let name): return "The offline geographic resource \(name) is missing."
            case .unreadableResource(let name): return "The offline geographic resource \(name) could not be read."
            }
        }
    }

    private struct City: Sendable {
        let id: Int
        let name: String
        let point: GeoPoint
        let countryCode: String
        let admin1Code: String
        let population: Int
    }

    private struct Cell: Hashable, Sendable {
        let latitude: Int
        let longitude: Int
    }

    private let cities: [City]
    private let buckets: [Cell: [Int]]
    private let countryNames: [String: String]
    private let adminNames: [String: String]

    static func bundled() throws -> GeographicIndex {
        func resource(_ name: String) throws -> URL {
            let resourceBundleName = "where-ive-been_WhereIveBeen.bundle"
            let bundleURLs = [
                Bundle.main.resourceURL?.appendingPathComponent(resourceBundleName),
                Bundle.main.bundleURL.appendingPathComponent(resourceBundleName),
                Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent(resourceBundleName)
            ].compactMap { $0 }

            for bundle in [Bundle.main] + bundleURLs.compactMap(Bundle.init(url:)) {
                if let url = bundle.url(forResource: name, withExtension: "txt", subdirectory: "GeoNames")
                    ?? bundle.url(forResource: name, withExtension: "txt") {
                    return url
                }
            }

            let developmentURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Sources/where-ive-been/Resources/GeoNames")
                .appendingPathComponent(name)
                .appendingPathExtension("txt")
            if FileManager.default.fileExists(atPath: developmentURL.path) {
                return developmentURL
            }

            throw IndexError.missingResource(name)
        }

        return try GeographicIndex(
            citiesURL: resource("cities5000"),
            adminURL: resource("admin1CodesASCII"),
            countriesURL: resource("countryInfo")
        )
    }

    init(citiesURL: URL, adminURL: URL, countriesURL: URL) throws {
        guard let countryText = try? String(contentsOf: countriesURL, encoding: .utf8) else {
            throw IndexError.unreadableResource("countryInfo")
        }
        guard let adminText = try? String(contentsOf: adminURL, encoding: .utf8) else {
            throw IndexError.unreadableResource("admin1CodesASCII")
        }
        guard let cityText = try? String(contentsOf: citiesURL, encoding: .utf8) else {
            throw IndexError.unreadableResource("cities5000")
        }

        var countries: [String: String] = [:]
        for line in countryText.split(whereSeparator: \.isNewline) where !line.hasPrefix("#") {
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            if fields.count > 4 { countries[String(fields[0])] = String(fields[4]) }
        }

        var admins: [String: String] = [:]
        for line in adminText.split(whereSeparator: \.isNewline) {
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            if fields.count > 1 { admins[String(fields[0])] = String(fields[1]) }
        }

        var parsedCities: [City] = []
        parsedCities.reserveCapacity(70_000)
        for line in cityText.split(whereSeparator: \.isNewline) {
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard fields.count > 14,
                  let id = Int(fields[0]),
                  let latitude = Double(fields[4]),
                  let longitude = Double(fields[5]) else { continue }
            parsedCities.append(City(
                id: id,
                name: String(fields[1]),
                point: GeoPoint(latitude: latitude, longitude: longitude),
                countryCode: String(fields[8]),
                admin1Code: String(fields[10]),
                population: Int(fields[14]) ?? 0
            ))
        }

        var cellBuckets: [Cell: [Int]] = [:]
        for (index, city) in parsedCities.enumerated() {
            cellBuckets[Self.cell(for: city.point), default: []].append(index)
        }

        cities = parsedCities
        buckets = cellBuckets
        countryNames = countries
        adminNames = admins
    }

    func nearest(to point: GeoPoint) -> GeoLocality? {
        let origin = Self.cell(for: point)
        var candidates: [Int] = []

        for radius in [1, 3, 6, 12] {
            candidates.removeAll(keepingCapacity: true)
            for latitude in (origin.latitude - radius)...(origin.latitude + radius) {
                for longitude in (origin.longitude - radius)...(origin.longitude + radius) {
                    candidates.append(contentsOf: buckets[Cell(latitude: latitude, longitude: longitude)] ?? [])
                }
            }
            if !candidates.isEmpty { break }
        }

        guard let match = candidates.map({ cities[$0] }).min(by: {
            let lhsDistance = Self.distance(from: point, to: $0.point)
            let rhsDistance = Self.distance(from: point, to: $1.point)
            if abs(lhsDistance - rhsDistance) < 2_000 { return $0.population > $1.population }
            return lhsDistance < rhsDistance
        }) else { return nil }

        let adminKey = "\(match.countryCode).\(match.admin1Code)"
        return GeoLocality(
            cityID: match.id,
            city: match.name,
            state: adminNames[adminKey] ?? match.admin1Code,
            stateCode: adminKey,
            country: countryNames[match.countryCode] ?? match.countryCode,
            countryCode: match.countryCode,
            point: match.point,
            distanceMeters: Self.distance(from: point, to: match.point)
        )
    }

    func analyze(_ dataset: JourneyDataset, places: [PlaceSummary]) -> GeographicAnalytics {
        struct Accumulator {
            var name: String
            var parentName: String
            var countryCode: String
            var latitudeTotal: Double = 0
            var longitudeTotal: Double = 0
            var coordinateCount: Int = 0
            var visits: Int = 0
            var journeys: Int = 0
            var distanceMeters: Double = 0
            var days: Set<Date> = []
            var firstSeen: Date
            var lastSeen: Date
        }

        let calendar = Calendar.autoupdatingCurrent
        var countries: [String: Accumulator] = [:]
        var states: [String: Accumulator] = [:]
        var cities: [String: Accumulator] = [:]
        var yearlyCountries: [String: Accumulator] = [:]
        var yearlyStates: [String: Accumulator] = [:]
        var yearlyCities: [String: Accumulator] = [:]
        var localityCache: [String: GeoLocality] = [:]
        var matched = 0

        func cacheKey(_ point: GeoPoint) -> String {
            String(format: "%.3f,%.3f", point.latitude, point.longitude)
        }

        for place in places {
            if let locality = nearest(to: place.point) {
                localityCache[place.key] = locality
            }
        }

        for event in dataset.events {
            guard let point = event.point else { continue }
            let pointKey = cacheKey(point)
            let locality: GeoLocality
            if let cached = localityCache[pointKey] {
                locality = cached
            } else if let found = nearest(to: point) {
                locality = found
                localityCache[pointKey] = found
            } else {
                continue
            }
            matched += 1
            let day = calendar.startOfDay(for: event.start)
            let year = calendar.component(.year, from: event.start)

            func updated(_ existing: Accumulator?, name: String, parent: String) -> Accumulator {
                var value = existing ?? Accumulator(
                    name: name, parentName: parent, countryCode: locality.countryCode,
                    firstSeen: event.start, lastSeen: event.end
                )
                value.latitudeTotal += point.latitude
                value.longitudeTotal += point.longitude
                value.coordinateCount += 1
                if event.kind == .visit { value.visits += 1 } else { value.journeys += 1 }
                value.distanceMeters += event.distanceMeters
                value.days.insert(day)
                value.firstSeen = min(value.firstSeen, event.start)
                value.lastSeen = max(value.lastSeen, event.end)
                return value
            }

            let countryKey = locality.countryCode
            countries[countryKey] = updated(countries[countryKey], name: locality.country, parent: "")
            states[locality.stateCode] = updated(states[locality.stateCode], name: locality.state, parent: locality.country)
            let cityKey = String(locality.cityID)
            cities[cityKey] = updated(cities[cityKey], name: locality.city, parent: [locality.state, locality.country].filter { !$0.isEmpty }.joined(separator: ", "))
            let yearPrefix = "\(year)|"
            let yearCountryKey = yearPrefix + countryKey
            let yearStateKey = yearPrefix + locality.stateCode
            let yearCityKey = yearPrefix + cityKey
            yearlyCountries[yearCountryKey] = updated(yearlyCountries[yearCountryKey], name: locality.country, parent: "")
            yearlyStates[yearStateKey] = updated(yearlyStates[yearStateKey], name: locality.state, parent: locality.country)
            yearlyCities[yearCityKey] = updated(yearlyCities[yearCityKey], name: locality.city, parent: [locality.state, locality.country].filter { !$0.isEmpty }.joined(separator: ", "))
        }

        func summaries(_ values: [String: Accumulator], level: GeographicLevel) -> [GeographicSummary] {
            values.map { key, value in
                let count = max(1, value.coordinateCount)
                return GeographicSummary(
                    id: key, level: level, name: value.name, parentName: value.parentName,
                    countryCode: value.countryCode,
                    point: GeoPoint(latitude: value.latitudeTotal / Double(count), longitude: value.longitudeTotal / Double(count)),
                    visits: value.visits, journeys: value.journeys,
                    distanceMeters: value.distanceMeters, activeDays: value.days.count,
                    firstSeen: value.firstSeen, lastSeen: value.lastSeen
                )
            }.sorted { lhs, rhs in
                if lhs.visits == rhs.visits { return lhs.activeDays > rhs.activeDays }
                return lhs.visits > rhs.visits
            }
        }

        var placeLocalities: [String: GeoLocality] = [:]
        for place in places {
            if let locality = localityCache[place.key] ?? nearest(to: place.point) {
                placeLocalities[place.key] = locality
            }
        }

        let years = Set(dataset.events.map(\.year))
        var byYear: [Int: GeographicSnapshot] = [:]
        for year in years {
            let prefix = "\(year)|"
            func stripped(_ values: [String: Accumulator]) -> [String: Accumulator] {
                Dictionary(uniqueKeysWithValues: values.compactMap { key, value in
                    guard key.hasPrefix(prefix) else { return nil }
                    return (String(key.dropFirst(prefix.count)), value)
                })
            }
            byYear[year] = GeographicSnapshot(
                countries: summaries(stripped(yearlyCountries), level: .country),
                states: summaries(stripped(yearlyStates), level: .state),
                cities: summaries(stripped(yearlyCities), level: .city)
            )
        }

        return GeographicAnalytics(
            all: GeographicSnapshot(
                countries: summaries(countries, level: .country),
                states: summaries(states, level: .state),
                cities: summaries(cities, level: .city)
            ),
            byYear: byYear,
            localitiesByPlaceKey: placeLocalities,
            matchedEvents: matched
        )
    }

    private static func cell(for point: GeoPoint) -> Cell {
        Cell(latitude: Int(floor(point.latitude)), longitude: Int(floor(point.longitude)))
    }

    private static func distance(from lhs: GeoPoint, to rhs: GeoPoint) -> Double {
        let radius = 6_371_000.0
        let lat1 = lhs.latitude * .pi / 180
        let lat2 = rhs.latitude * .pi / 180
        let deltaLat = (rhs.latitude - lhs.latitude) * .pi / 180
        let deltaLon = (rhs.longitude - lhs.longitude) * .pi / 180
        let a = sin(deltaLat / 2) * sin(deltaLat / 2)
            + cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2)
        return radius * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}
