import XCTest
@testable import WhereIveBeen

final class ImporterTests: XCTestCase {
    func testNormalizesVisitsActivitiesAndPaths() throws {
        let json = """
        [
          {
            "startTime":"2025-01-02T08:00:00.000+03:00",
            "endTime":"2025-01-02T09:00:00.000+03:00",
            "visit":{"probability":"0.9","topCandidate":{"semanticType":"Inferred Home","placeID":"home","placeLocation":"geo:29.3000,48.0000"}}
          },
          {
            "startTime":"2025-01-02T09:00:00.000+03:00",
            "endTime":"2025-01-02T09:30:00.000+03:00",
            "activity":{"start":"geo:29.3000,48.0000","end":"geo:29.4000,48.1000","distanceMeters":"12500","topCandidate":{"type":"in passenger vehicle","probability":"0.8"}},
            "timelinePath":[{"point":"geo:29.3000,48.0000"},{"point":"geo:29.3500,48.0500"},{"point":"geo:29.4000,48.1000"}]
          }
        ]
        """
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("json")
        try Data(json.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let dataset = try GoogleLocationImporter().load(from: url)

        XCTAssertEqual(dataset.events.count, 2)
        XCTAssertEqual(dataset.events[0].kind, .visit)
        XCTAssertEqual(dataset.events[0].title, "Home")
        XCTAssertEqual(dataset.events[1].kind, .activity)
        XCTAssertEqual(dataset.events[1].title, "In Passenger Vehicle")
        XCTAssertEqual(dataset.events[1].distanceMeters, 12_500)
        XCTAssertEqual(dataset.events[1].path.count, 3)
    }

    func testAnalyticsAggregatesSyntheticEvents() {
        let start = Date(timeIntervalSince1970: 1_735_776_000)
        let events = [
            JourneyEvent(
                id: 1, kind: .visit, start: start, end: start.addingTimeInterval(3_600),
                point: GeoPoint(latitude: 10, longitude: 10), endPoint: nil, path: [],
                title: "Museum", subtitle: "", distanceMeters: 0,
                probability: 1, placeID: "synthetic-place"
            ),
            JourneyEvent(
                id: 2, kind: .activity, start: start.addingTimeInterval(3_600),
                end: start.addingTimeInterval(7_200),
                point: GeoPoint(latitude: 10, longitude: 10),
                endPoint: GeoPoint(latitude: 10.1, longitude: 10.1),
                path: [], title: "Walking", subtitle: "", distanceMeters: 2_000,
                probability: 1, placeID: nil
            )
        ]
        let dataset = JourneyDataset(
            events: events,
            sourceURL: URL(fileURLWithPath: "/synthetic.json"),
            importedAt: start,
            skippedRecords: 0
        )
        let analytics = AnalyticsEngine().analyze(dataset)

        XCTAssertEqual(dataset.events.count, 2)
        XCTAssertEqual(analytics.visitCount, 1)
        XCTAssertEqual(analytics.activityCount, 1)
        XCTAssertEqual(analytics.totalDistanceMeters, 2_000)
        XCTAssertEqual(analytics.topPlaces.count, 1)
        XCTAssertEqual(analytics.seasonalSummaries.count, 12)
        XCTAssertEqual(analytics.weekdaySummaries.count, 7)
        XCTAssertEqual(analytics.hourSummaries.count, 24)
        XCTAssertEqual(analytics.seasonalSummaries.reduce(0) { $0 + $1.activeDays }, analytics.activeDayCount)
        XCTAssertEqual(analytics.weekdaySummaries.reduce(0) { $0 + $1.activeDays }, analytics.activeDayCount)
        XCTAssertEqual(analytics.hourSummaries.reduce(0) { $0 + $1.events }, dataset.events.count)
        XCTAssertEqual(analytics.averageJourneyDistance, 2_000)
        XCTAssertEqual(analytics.medianJourneyDistance, 2_000)
        XCTAssertEqual(analytics.longestActiveStreak, 1)
    }

    func testOfflineGeographyFindsCountriesStatesAndCities() throws {
        let index = try GeographicIndex.bundled()
        let paris = try XCTUnwrap(index.nearest(to: GeoPoint(latitude: 48.8566, longitude: 2.3522)))
        let tokyo = try XCTUnwrap(index.nearest(to: GeoPoint(latitude: 35.6762, longitude: 139.6503)))

        XCTAssertEqual(paris.countryCode, "FR")
        XCTAssertEqual(paris.country, "France")
        XCTAssertFalse(paris.city.isEmpty)
        XCTAssertEqual(tokyo.countryCode, "JP")
        XCTAssertEqual(tokyo.country, "Japan")
        XCTAssertFalse(tokyo.state.isEmpty)
    }

    func testRouteSamplingIncludesStandalonePathsAcrossTheWholeTimeline() {
        let point = GeoPoint(latitude: 1, longitude: 1)
        let events = (0..<100).map { index in
            JourneyEvent(
                id: index,
                kind: index.isMultiple(of: 2) ? .path : .activity,
                start: Date(timeIntervalSince1970: Double(index)),
                end: Date(timeIntervalSince1970: Double(index + 1)),
                point: point,
                endPoint: GeoPoint(latitude: 2, longitude: 2),
                path: [point, GeoPoint(latitude: 2, longitude: 2)],
                title: "Route", subtitle: "", distanceMeters: 1,
                probability: nil, placeID: nil
            )
        }

        let selection = RouteSampler().select(from: events, limit: 10)
        XCTAssertEqual(selection.totalCount, 100)
        XCTAssertEqual(selection.visible.count, 10)
        XCTAssertEqual(selection.visible.first?.id, 0)
        XCTAssertEqual(selection.visible.last?.id, 99)
        XCTAssertTrue(selection.visible.contains { $0.kind == .path })
    }

    func testTimelineRoutePresentationUsesRecordedPathAndEstimatesMissingDistance() {
        let start = GeoPoint(latitude: 1, longitude: 1)
        let middle = GeoPoint(latitude: 1.01, longitude: 1.01)
        let end = GeoPoint(latitude: 1.02, longitude: 1.02)
        let event = JourneyEvent(
            id: 500, kind: .path,
            start: Date(timeIntervalSince1970: 1_000),
            end: Date(timeIntervalSince1970: 1_600),
            point: start, endPoint: end, path: [start, middle, end],
            title: "Recorded path", subtitle: "3 points", distanceMeters: 0,
            probability: nil, placeID: nil
        )

        let route = JourneyRoute(event: event)

        XCTAssertTrue(route.hasPath)
        XCTAssertEqual(route.points, [start, middle, end])
        XCTAssertEqual(route.startPoint, start)
        XCTAssertEqual(route.endPoint, end)
        XCTAssertTrue(route.distanceIsEstimated)
        XCTAssertGreaterThan(route.distanceMeters, 1_000)
    }
}
