import Foundation

struct GoogleLocationImporter: Sendable {
    enum ImportError: LocalizedError {
        case unreadable
        case invalidFormat
        case noUsableRecords

        var errorDescription: String? {
            switch self {
            case .unreadable: return "The selected file could not be read."
            case .invalidFormat: return "This does not look like a Google Timeline location-history export."
            case .noUsableRecords: return "No visits or movement records with valid dates were found."
            }
        }
    }

    func load(from url: URL) throws -> JourneyDataset {
        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) else {
            throw ImportError.unreadable
        }

        let decoder = JSONDecoder()
        guard let rawRecords = try? decoder.decode([RawRecord].self, from: data) else {
            throw ImportError.invalidFormat
        }

        var events: [JourneyEvent] = []
        events.reserveCapacity(rawRecords.count)
        var skipped = 0

        for (index, raw) in rawRecords.enumerated() {
            guard let start = Self.parseDate(raw.startTime),
                  let end = Self.parseDate(raw.endTime) else {
                skipped += 1
                continue
            }

            if let visit = raw.visit, let point = GeoPoint.parse(visit.topCandidate?.placeLocation) {
                let semantic = Self.friendly(visit.topCandidate?.semanticType ?? "Place")
                events.append(JourneyEvent(
                    id: index, kind: .visit, start: start, end: end,
                    point: point, endPoint: nil, path: [],
                    title: semantic,
                    subtitle: point.compactLabel,
                    distanceMeters: 0,
                    probability: Self.double(visit.probability) ?? Self.double(visit.topCandidate?.probability),
                    placeID: visit.topCandidate?.placeID
                ))
            } else if let activity = raw.activity {
                let startPoint = GeoPoint.parse(activity.start)
                let endPoint = GeoPoint.parse(activity.end)
                let mode = Self.friendly(activity.topCandidate?.type ?? "Movement")
                events.append(JourneyEvent(
                    id: index, kind: .activity, start: start, end: end,
                    point: startPoint, endPoint: endPoint,
                    path: raw.timelinePath?.compactMap { GeoPoint.parse($0.point) } ?? [],
                    title: mode,
                    subtitle: Self.distanceLabel(Self.double(activity.distanceMeters) ?? 0),
                    distanceMeters: Self.double(activity.distanceMeters) ?? 0,
                    probability: Self.double(activity.probability) ?? Self.double(activity.topCandidate?.probability),
                    placeID: nil
                ))
            } else if let path = raw.timelinePath?.compactMap({ GeoPoint.parse($0.point) }), !path.isEmpty {
                events.append(JourneyEvent(
                    id: index, kind: .path, start: start, end: end,
                    point: path.first, endPoint: path.last, path: path,
                    title: "Recorded path", subtitle: "\(path.count) points",
                    distanceMeters: 0, probability: nil, placeID: nil
                ))
            } else {
                skipped += 1
            }
        }

        guard !events.isEmpty else { throw ImportError.noUsableRecords }
        events.sort { $0.start < $1.start }
        return JourneyDataset(events: events, sourceURL: url, importedAt: .now, skippedRecords: skipped)
    }

    private static func parseDate(_ value: String) -> Date? {
        if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(value) {
            return date
        }
        return try? Date.ISO8601FormatStyle().parse(value)
    }

    private static func double(_ value: String?) -> Double? {
        value.flatMap(Double.init)
    }

    private static func friendly(_ value: String) -> String {
        value
            .replacingOccurrences(of: "Inferred ", with: "")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }

    private static func distanceLabel(_ meters: Double) -> String {
        if meters >= 1_000 { return String(format: "%.1f km", meters / 1_000) }
        return String(format: "%.0f m", meters)
    }
}

private struct RawRecord: Decodable {
    let startTime: String
    let endTime: String
    let visit: RawVisit?
    let activity: RawActivity?
    let timelinePath: [RawPathPoint]?
}

private struct RawVisit: Decodable {
    let probability: String?
    let topCandidate: RawVisitCandidate?
}

private struct RawVisitCandidate: Decodable {
    let probability: String?
    let semanticType: String?
    let placeID: String?
    let placeLocation: String?
}

private struct RawActivity: Decodable {
    let start: String?
    let end: String?
    let distanceMeters: String?
    let probability: String?
    let topCandidate: RawActivityCandidate?
}

private struct RawActivityCandidate: Decodable {
    let type: String?
    let probability: String?
}

private struct RawPathPoint: Decodable {
    let point: String?
}
