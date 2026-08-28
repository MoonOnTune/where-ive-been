import SwiftUI
import MapKit

struct RouteDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let route: JourneyRoute

    @State private var position: MapCameraPosition
    @State private var imagery = false

    init(event: JourneyEvent) {
        let route = JourneyRoute(event: event)
        self.route = route
        _position = State(initialValue: .region(Self.region(for: route.points)))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            map
            Divider()
            details
        }
        .frame(minWidth: 820, idealWidth: 920, minHeight: 610, idealHeight: 700)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: route.event.symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(route.event.tint)
                .frame(width: 42, height: 42)
                .background(route.event.tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(route.hasPath ? "Route details" : "Location details")
                    .font(.caption.weight(.bold)).foregroundStyle(.secondary)
                Text(route.event.title).font(.title2.bold())
            }
            Spacer()
            Text(route.event.start.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                .font(.subheadline).foregroundStyle(.secondary)
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent).tint(JourneyTheme.indigo)
                .keyboardShortcut(.cancelAction)
        }
        .padding(18)
    }

    private var map: some View {
        ZStack(alignment: .topTrailing) {
            if route.points.isEmpty {
                ContentUnavailableView("No coordinates available", systemImage: "location.slash", description: Text("This timeline entry does not contain a mappable point."))
            } else {
                Map(position: $position) {
                    if route.hasPath {
                        MapPolyline(coordinates: route.points.map(\.coordinate))
                            .stroke(route.event.tint, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))

                        if let start = route.startPoint {
                            Annotation("Start", coordinate: start.coordinate, anchor: .center) {
                                routeMarker(symbol: "play.fill", color: .green)
                            }
                        }
                        if let end = route.endPoint {
                            Annotation("End", coordinate: end.coordinate, anchor: .center) {
                                routeMarker(symbol: "flag.checkered", color: JourneyTheme.coral)
                            }
                        }
                    } else if let point = route.startPoint {
                        Annotation(route.event.title, coordinate: point.coordinate, anchor: .bottom) {
                            routeMarker(symbol: "mappin", color: JourneyTheme.coral, size: 38)
                        }
                    }
                }
                .mapStyle(imagery ? .imagery(elevation: .realistic) : .standard(elevation: .realistic))
                .mapControls {
                    MapCompass()
                    MapScaleView()
                    MapPitchToggle()
                }

                Toggle(isOn: $imagery) {
                    Label("Satellite", systemImage: "globe.americas.fill")
                }
                .toggleStyle(.button)
                .padding(12)
                .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(16)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var details: some View {
        HStack(spacing: 28) {
            detailMetric(
                route.event.start.formatted(.dateTime.hour().minute()),
                "Started",
                "clock.fill"
            )
            detailMetric(JourneyTheme.duration(route.event.duration), "Duration", "hourglass")
            if route.distanceMeters > 0 {
                detailMetric(
                    (route.distanceIsEstimated ? "≈ " : "") + JourneyTheme.distance(route.distanceMeters, precise: true),
                    route.distanceIsEstimated ? "Path estimate" : "Distance",
                    "arrow.triangle.swap"
                )
            }
            detailMetric(route.points.count.formatted(), route.points.count == 1 ? "Location point" : "Recorded points", "point.3.connected.trianglepath.dotted")
            Spacer()
            if let start = route.startPoint {
                VStack(alignment: .trailing, spacing: 3) {
                    Text(start.compactLabel).font(.caption.monospacedDigit())
                    Text("Start coordinate").font(.caption2).foregroundStyle(.secondary)
                }
                .textSelection(.enabled)
            }
        }
        .padding(18)
        .background(.regularMaterial)
    }

    private func detailMetric(_ value: String, _ label: String, _ symbol: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: symbol).foregroundStyle(JourneyTheme.indigo)
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.subheadline.bold()).monospacedDigit()
                Text(label).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func routeMarker(symbol: String, color: Color, size: CGFloat = 30) -> some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.34, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: Circle())
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .shadow(color: .black.opacity(0.30), radius: 5, y: 2)
    }

    private static func region(for points: [GeoPoint]) -> MKCoordinateRegion {
        guard let first = points.first else {
            return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 29.3759, longitude: 47.9774), latitudinalMeters: 20_000, longitudinalMeters: 20_000)
        }
        guard points.count > 1 else {
            return MKCoordinateRegion(center: first.coordinate, latitudinalMeters: 8_000, longitudinalMeters: 8_000)
        }

        var rect = MKMapRect(origin: MKMapPoint(first.coordinate), size: MKMapSize(width: 1, height: 1))
        for point in points.dropFirst() {
            let mapPoint = MKMapPoint(point.coordinate)
            rect = rect.union(MKMapRect(origin: mapPoint, size: MKMapSize(width: 1, height: 1)))
        }
        var region = MKCoordinateRegion(rect)
        region.span.latitudeDelta = max(0.01, min(160, region.span.latitudeDelta * 1.35))
        region.span.longitudeDelta = max(0.01, min(340, region.span.longitudeDelta * 1.35))
        return region
    }
}
