import SwiftUI
import Charts
import MapKit

struct TravelAtlasView: View {
    @Environment(JourneyStore.self) private var store
    @State private var level: GeographicLevel = .country
    @State private var metric: AtlasMetric = .visits
    @State private var selectedRegion: GeographicSummary?
    @State private var searchText = ""
    @State private var mapPosition: MapCameraPosition = .automatic

    private enum AtlasMetric: String, CaseIterable, Identifiable {
        case visits = "Visits"
        case distance = "Distance"
        case days = "Active days"
        var id: String { rawValue }
    }

    private var summaries: [GeographicSummary] {
        store.geography.summaries(for: level, year: store.selectedYear)
    }

    private var visibleSummaries: [GeographicSummary] {
        guard !searchText.isEmpty else { return summaries }
        return summaries.filter {
            $0.name.localizedStandardContains(searchText) || $0.parentName.localizedStandardContains(searchText)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 22) {
                atlasHeader
                summaryCards
                controls
                atlasMap
                rankings
            }
            .padding(28)
            .frame(maxWidth: 1450)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Travel Atlas")
        .searchable(text: $searchText, prompt: "Find a country, state, or city")
        .onChange(of: level) { _, _ in
            selectedRegion = nil
            mapPosition = .automatic
        }
        .onChange(of: store.selectedYear) { _, _ in
            selectedRegion = nil
            mapPosition = .automatic
        }
    }

    private var atlasHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Your travel atlas")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text(store.selectedYear.map { "The places you reached in \($0)" } ?? "Countries, regions, and cities across your complete history")
                    .font(.title3).foregroundStyle(.secondary)
            }
            Spacer()
            Label("Offline place index", systemImage: "checkmark.shield.fill")
                .font(.caption.weight(.semibold)).foregroundStyle(.green)
        }
    }

    private var summaryCards: some View {
        let snapshot = store.selectedYear.flatMap { store.geography.byYear[$0] } ?? store.geography.all
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 16)], spacing: 16) {
            StatCard(title: "Countries reached", value: snapshot.countries.count.formatted(), detail: "Across your recorded history", symbol: "globe.americas.fill", color: JourneyTheme.indigo)
            StatCard(title: "States & regions", value: snapshot.states.count.formatted(), detail: "Administrative regions", symbol: "map.fill", color: JourneyTheme.aqua)
            StatCard(title: "Cities discovered", value: snapshot.cities.count.formatted(), detail: "Nearest recorded localities", symbol: "building.2.fill", color: JourneyTheme.coral)
            StatCard(title: "Locations matched", value: store.geography.matchedEvents.formatted(), detail: "Using local geographic data", symbol: "mappin.and.ellipse", color: JourneyTheme.gold)
        }
    }

    private var controls: some View {
        HStack {
            Picker("Geographic level", selection: $level) {
                ForEach(GeographicLevel.allCases) { item in Text(item.rawValue).tag(item) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 520)
            Spacer()
            Picker("Rank by", selection: $metric) {
                ForEach(AtlasMetric.allCases) { item in Text(item.rawValue).tag(item) }
            }
            .pickerStyle(.menu)
            .frame(width: 150)
        }
    }

    private var atlasMap: some View {
        ZStack(alignment: .bottomLeading) {
            Map(position: $mapPosition) {
                ForEach(Array(visibleSummaries.prefix(level == .city ? 180 : 100))) { region in
                    Annotation(region.name, coordinate: region.point.coordinate, anchor: .center) {
                        Button { select(region) } label: {
                            ZStack {
                                Circle()
                                    .fill(selectedRegion?.id == region.id ? JourneyTheme.gold.gradient : JourneyTheme.indigo.gradient)
                                    .frame(width: markerSize(region), height: markerSize(region))
                                    .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 2))
                                    .shadow(color: .black.opacity(0.25), radius: 5, y: 2)
                                if level == .country {
                                    Text(region.flag).font(.system(size: max(12, markerSize(region) * 0.42)))
                                } else {
                                    Image(systemName: level == .state ? "map.fill" : "building.2.fill")
                                        .font(.system(size: max(8, markerSize(region) * 0.30), weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .help("\(region.name) · \(region.visits) visits")
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
            .mapControls {
                MapCompass()
                MapScaleView()
            }

            if let region = selectedRegion {
                regionDetail(region)
                    .frame(width: 390)
                    .padding(18)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            } else {
                Label("Select a marker to inspect your history there", systemImage: "cursorarrow.click.2")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(.ultraThickMaterial, in: Capsule())
                    .padding(16)
            }
        }
        .frame(height: 440)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.primary.opacity(0.08)))
        .shadow(color: .black.opacity(0.10), radius: 18, y: 8)
        .animation(.snappy, value: selectedRegion)
    }

    private var rankings: some View {
        LazyVGrid(columns: [GridItem(.flexible(minimum: 430)), GridItem(.flexible(minimum: 390))], spacing: 18) {
            rankingChart
            regionList
        }
    }

    private var rankingChart: some View {
        let items = Array(visibleSummaries.prefix(12).reversed())
        return VStack(alignment: .leading, spacing: 18) {
            SectionHeading(title: "Top \(level.rawValue.lowercased())", subtitle: "Ranked by \(metric.rawValue.lowercased())")
            Chart(items) { region in
                BarMark(
                    x: .value(metric.rawValue, metricValue(region)),
                    y: .value(level.singular.capitalized, region.name)
                )
                .foregroundStyle(JourneyTheme.heroGradient)
                .cornerRadius(4)
            }
            .chartXAxisLabel(metric == .distance ? "km" : metric.rawValue.lowercased())
            .chartYAxis { AxisMarks(position: .leading) }
            .frame(height: max(280, CGFloat(items.count) * 29))
        }
        .journeyCard()
    }

    private var regionList: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(title: "Travel ledger", subtitle: "First visit, latest visit, and activity")
            ForEach(Array(visibleSummaries.prefix(12).enumerated()), id: \.element.id) { index, region in
                Button { select(region) } label: {
                    HStack(spacing: 12) {
                        Text(level == .country ? region.flag : "\(index + 1)")
                            .font(level == .country ? .title3 : .caption.bold())
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(region.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                            Text(region.parentName.isEmpty ? dateRange(region) : "\(region.parentName) · \(dateRange(region))")
                                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(region.visits) visits").font(.caption.weight(.semibold))
                            Text("\(region.activeDays) days").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if index < min(11, visibleSummaries.count - 1) { Divider() }
            }
            Spacer(minLength: 0)
        }
        .journeyCard()
    }

    private func regionDetail(_ region: GeographicSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Text(level == .country ? region.flag : (level == .state ? "🗺️" : "🏙️"))
                    .font(.system(size: 34))
                VStack(alignment: .leading, spacing: 3) {
                    Text(region.name).font(.title2.bold())
                    if !region.parentName.isEmpty { Text(region.parentName).font(.caption).foregroundStyle(.secondary) }
                }
                Spacer()
                Button { selectedRegion = nil } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            }
            Divider()
            HStack {
                miniMetric(region.visits.formatted(), "visits")
                Spacer()
                miniMetric(region.activeDays.formatted(), "active days")
                Spacer()
                miniMetric(JourneyTheme.distance(region.distanceMeters), "travel")
            }
            Text("Recorded from \(region.firstSeen.formatted(.dateTime.month(.wide).year())) to \(region.lastSeen.formatted(.dateTime.month(.wide).year())).")
                .font(.caption).foregroundStyle(.secondary)
        }
        .journeyCard()
    }

    private func miniMetric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.headline)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func select(_ region: GeographicSummary) {
        selectedRegion = region
        let span: CLLocationDistance = level == .country ? 1_600_000 : (level == .state ? 500_000 : 60_000)
        mapPosition = .region(MKCoordinateRegion(center: region.point.coordinate, latitudinalMeters: span, longitudinalMeters: span))
    }

    private func markerSize(_ region: GeographicSummary) -> CGFloat {
        min(54, max(24, 20 + sqrt(CGFloat(max(1, region.visits))) * 0.7))
    }

    private func metricValue(_ region: GeographicSummary) -> Double {
        switch metric {
        case .visits: return Double(region.visits)
        case .distance: return region.distanceMeters / 1_000
        case .days: return Double(region.activeDays)
        }
    }

    private func dateRange(_ region: GeographicSummary) -> String {
        let first = region.firstSeen.formatted(.dateTime.year())
        let last = region.lastSeen.formatted(.dateTime.year())
        return first == last ? first : "\(first)–\(last)"
    }
}
