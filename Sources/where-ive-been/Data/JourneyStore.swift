import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
@Observable
final class JourneyStore {
    enum LoadState: Equatable {
        case idle
        case loading(String)
        case loaded
        case failed(String)
    }

    var dataset: JourneyDataset = .empty
    var analytics: JourneyAnalytics = .empty
    var geography: GeographicAnalytics = .empty
    var loadState: LoadState = .idle
    var selectedYear: Int?
    var searchText = ""
    var selectedEvent: JourneyEvent?
    var showingImporter = false

    var filteredEvents: [JourneyEvent] {
        dataset.events.filter { event in
            (selectedYear == nil || event.year == selectedYear) &&
            (searchText.isEmpty || event.title.localizedStandardContains(searchText) || event.subtitle.localizedStandardContains(searchText))
        }
    }

    var selectedYearSummary: YearSummary? {
        guard let selectedYear else { return nil }
        return analytics.yearSummaries.first { $0.year == selectedYear }
    }

    func load(_ url: URL) async {
        let hasSecurityScopedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        loadState = .loading(url.lastPathComponent)
        do {
            let result = try await Task.detached(priority: .userInitiated) {
                let dataset = try GoogleLocationImporter().load(from: url)
                let analytics = AnalyticsEngine().analyze(dataset)
                let geography = try GeographicIndex.bundled().analyze(dataset, places: analytics.topPlaces)
                return (dataset, analytics, geography)
            }.value
            dataset = result.0
            analytics = result.1
            geography = result.2
            loadState = .loaded
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    func clearYearFilter() { selectedYear = nil }

    func locality(for event: JourneyEvent) -> GeoLocality? {
        guard let point = event.point else { return nil }
        let key = event.placeID ?? String(format: "%.3f,%.3f", point.latitude, point.longitude)
        return geography.localitiesByPlaceKey[key]
    }
}
