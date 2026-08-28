import SwiftUI
import MapKit

struct ExploreMapView: View {
    @Environment(JourneyStore.self) private var store
    @State private var position: MapCameraPosition = .automatic
    @State private var imagery = false
    @State private var showRoutes = true
    @State private var selectedPlace: PlaceSummary?
    @State private var routeDetail: RouteDetail = .balanced

    private enum RouteDetail: String, CaseIterable, Identifiable {
        case light = "Light"
        case balanced = "Balanced"
        case detailed = "Detailed"
        var id: String { rawValue }
        var limit: Int {
            switch self {
            case .light: return 500
            case .balanced: return 1_800
            case .detailed: return 4_000
            }
        }
    }

    private var routeSelection: RouteSelection {
        RouteSampler().select(from: store.filteredEvents, limit: routeDetail.limit)
    }

    private var pins: [PlaceSummary] {
        if store.selectedYear == nil { return Array(store.analytics.topPlaces.prefix(250)) }
        let yearVisits = store.filteredEvents.filter { $0.kind == .visit }
        let keys = Set(yearVisits.compactMap { $0.placeID })
        return Array(store.analytics.topPlaces.filter { keys.contains($0.key) }.prefix(250))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Map(position: $position) {
                if showRoutes {
                    ForEach(routeSelection.visible) { event in
                        let points = event.path.count > 1 ? event.path : [event.point, event.endPoint].compactMap { $0 }
                        if points.count > 1 {
                            MapPolyline(coordinates: points.map(\.coordinate))
                                .stroke(event.tint.opacity(0.60), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                        }
                    }
                }

                ForEach(pins) { place in
                    Annotation(place.name, coordinate: place.point.coordinate, anchor: .bottom) {
                        Button { selectedPlace = place } label: {
                            Image(systemName: place.name.lowercased().contains("home") ? "house.fill" : "circle.fill")
                                .font(.system(size: place.name.lowercased().contains("home") ? 12 : 8, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(JourneyTheme.coral.gradient, in: Circle())
                                .overlay(Circle().stroke(.white.opacity(0.85), lineWidth: 2))
                                .shadow(color: .black.opacity(0.28), radius: 4, y: 2)
                        }
                        .buttonStyle(.plain)
                        .help("\(place.name) · \(place.visits) visits")
                    }
                }
            }
            .mapStyle(imagery ? .imagery(elevation: .realistic) : .standard(elevation: .realistic))
            .mapControls {
                MapCompass()
                MapScaleView()
                MapPitchToggle()
            }

            mapToolbar

            if let selectedPlace {
                placeCard(selectedPlace)
                    .frame(width: 320)
                    .padding(.top, 78)
                    .padding(.leading, 18)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .navigationTitle("Explore")
        .animation(.snappy, value: selectedPlace)
    }

    private var mapToolbar: some View {
        HStack(spacing: 8) {
            Label(store.selectedYear.map(String.init) ?? "All years", systemImage: "calendar")
                .font(.subheadline.weight(.semibold))
            Divider().frame(height: 20)
            Toggle(isOn: $showRoutes) {
                Label("Routes", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
            }
            .toggleStyle(.button)
            Picker("Route detail", selection: $routeDetail) {
                ForEach(RouteDetail.allCases) { detail in Text(detail.rawValue).tag(detail) }
            }
            .pickerStyle(.menu)
            .frame(width: 112)
            Toggle(isOn: $imagery) {
                Label("Satellite", systemImage: "globe.americas.fill")
            }
            .toggleStyle(.button)
            Spacer()
            Text("\(pins.count) places · \(routeSelection.visible.count) of \(routeSelection.totalCount) routes")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(10)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 5)
        .padding(16)
    }

    private func placeCard(_ place: PlaceSummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(JourneyTheme.coral)
                VStack(alignment: .leading, spacing: 3) {
                    Text(place.name).font(.title3.bold())
                    if let locality = store.geography.localitiesByPlaceKey[place.key] {
                        Text("\(locality.city), \(locality.state), \(locality.country)")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text(place.point.compactLabel).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button { selectedPlace = nil } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            }
            Divider()
            HStack {
                placeMetric("Visits", place.visits.formatted())
                Spacer()
                placeMetric("Time spent", JourneyTheme.duration(place.totalDuration))
                Spacer()
                placeMetric("Last seen", place.mostRecent.formatted(.dateTime.month(.abbreviated).year()))
            }
            Button {
                position = .region(MKCoordinateRegion(center: place.point.coordinate, latitudinalMeters: 8_000, longitudinalMeters: 8_000))
            } label: {
                Label("Focus on this place", systemImage: "scope")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(JourneyTheme.indigo)
        }
        .journeyCard()
    }

    private func placeMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(.subheadline.bold())
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
    }
}
