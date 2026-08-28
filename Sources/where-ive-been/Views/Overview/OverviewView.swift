import SwiftUI
import Charts
import MapKit

struct OverviewView: View {
    @Environment(JourneyStore.self) private var store
    @State private var mapPosition: MapCameraPosition = .automatic

    private var selectedSummary: YearSummary? { store.selectedYearSummary }
    private var distance: Double { selectedSummary?.distanceMeters ?? store.analytics.totalDistanceMeters }
    private var visits: Int { selectedSummary?.visits ?? store.analytics.visitCount }
    private var activities: Int { selectedSummary?.activities ?? store.analytics.activityCount }
    private var activeDays: Int { selectedSummary?.activeDays ?? store.analytics.activeDayCount }

    private var visibleMonths: [MonthSummary] {
        guard let year = store.selectedYear else { return Array(store.analytics.monthSummaries.suffix(36)) }
        return store.analytics.monthSummaries.filter {
            Calendar.autoupdatingCurrent.component(.year, from: $0.month) == year
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                welcomeHeader
                statsGrid
                journeyMap
                lowerGrid
            }
            .padding(28)
            .frame(maxWidth: 1500)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Overview")
    }

    private var welcomeHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 7) {
                Text(store.selectedYear.map(String.init) ?? "Your complete journey")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                if let range = store.analytics.dateRange {
                    Text("A living map of \(range.lowerBound.formatted(.dateTime.month(.wide).year())) — \(range.upperBound.formatted(.dateTime.month(.wide).year()))")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Label("Updated \(store.dataset.importedAt.formatted(.relative(presentation: .named)))", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 16)], spacing: 16) {
            StatCard(title: "Distance traveled", value: JourneyTheme.distance(distance), detail: "Across recorded movement", symbol: "point.topleft.down.to.point.bottomright.curvepath", color: JourneyTheme.indigo)
            StatCard(title: "Places visited", value: visits.formatted(), detail: "Recorded stops", symbol: "mappin.and.ellipse", color: JourneyTheme.coral)
            StatCard(title: "Journeys", value: activities.formatted(), detail: "Movement segments", symbol: "car.side.fill", color: JourneyTheme.aqua)
            StatCard(title: "Active days", value: activeDays.formatted(), detail: "Days with memories", symbol: "calendar.badge.checkmark", color: JourneyTheme.gold)
        }
    }

    private var journeyMap: some View {
        ZStack(alignment: .topLeading) {
            Map(position: $mapPosition) {
                ForEach(Array(store.analytics.topPlaces.prefix(35))) { place in
                    Annotation(place.name, coordinate: place.point.coordinate, anchor: .center) {
                        ZStack {
                            Circle().fill(.white).frame(width: 16, height: 16)
                            Circle().fill(JourneyTheme.coral).frame(width: 9, height: 9)
                        }
                        .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                        .help("\(place.name) · \(place.visits) visits")
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
            .mapControls {
                MapCompass()
                MapScaleView()
            }

            LinearGradient(colors: [.black.opacity(0.58), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 150)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 6) {
                Label("YOUR WORLD", systemImage: "globe.americas.fill")
                    .font(.caption.weight(.black))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.8))
                Text("The places that shaped your story")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text("Your most-visited locations, sized by memory")
                    .foregroundStyle(.white.opacity(0.78))
            }
            .padding(22)
        }
        .frame(height: 390)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.12))
        }
        .shadow(color: .black.opacity(0.12), radius: 22, y: 10)
    }

    private var lowerGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(minimum: 400)), GridItem(.flexible(minimum: 300))], spacing: 18) {
            distanceChart
            favoritePlaces
        }
    }

    private var distanceChart: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeading(title: "Rhythm of travel", subtitle: store.selectedYear == nil ? "Your last three years, month by month" : "Monthly distance in \(store.selectedYear!)")
            Chart(visibleMonths) { month in
                AreaMark(
                    x: .value("Month", month.month),
                    y: .value("Distance", month.distanceMeters / 1_000)
                )
                .foregroundStyle(JourneyTheme.indigo.opacity(0.13))
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Month", month.month),
                    y: .value("Distance", month.distanceMeters / 1_000)
                )
                .foregroundStyle(JourneyTheme.heroGradient)
                .lineStyle(.init(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
            }
            .chartYAxisLabel("km")
            .chartXAxis {
                AxisMarks(values: .stride(by: .month, count: store.selectedYear == nil ? 6 : 2)) { _ in
                    AxisGridLine().foregroundStyle(.quaternary)
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
            .frame(height: 240)
        }
        .journeyCard()
    }

    private var favoritePlaces: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeading(title: "Familiar places", subtitle: "Where your days gather")
            ForEach(Array(store.analytics.topPlaces.prefix(5).enumerated()), id: \.element.id) { index, place in
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                        .background(.quaternary, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(place.name).font(.subheadline.weight(.semibold))
                        if let locality = store.geography.localitiesByPlaceKey[place.key] {
                            Text("\(locality.city), \(locality.state), \(locality.country)")
                                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        } else {
                            Text(place.point.compactLabel).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text("\(place.visits)")
                        .font(.system(.body, design: .rounded, weight: .bold))
                    Text("visits").font(.caption2).foregroundStyle(.tertiary)
                }
                if index < min(4, store.analytics.topPlaces.count - 1) { Divider() }
            }
            Spacer(minLength: 0)
        }
        .journeyCard()
    }
}
