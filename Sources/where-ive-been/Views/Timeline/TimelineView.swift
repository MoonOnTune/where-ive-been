import SwiftUI

struct TimelineView: View {
    @Environment(JourneyStore.self) private var store
    @State private var expandedDays: Set<Date> = []
    @State private var presentedEvent: JourneyEvent?

    private var days: [DaySummary] {
        store.analytics.days.compactMap { day in
            guard store.selectedYear == nil || Calendar.autoupdatingCurrent.component(.year, from: day.date) == store.selectedYear else { return nil }
            let events = day.events.filter { event in
                store.searchText.isEmpty || event.title.localizedStandardContains(store.searchText) || event.subtitle.localizedStandardContains(store.searchText)
            }
            guard !events.isEmpty else { return nil }
            return DaySummary(date: day.date, eventCount: events.count,
                              distanceMeters: events.reduce(0) { $0 + $1.distanceMeters }, events: events)
        }
    }

    var body: some View {
        @Bindable var store = store
        ScrollView {
            LazyVStack(spacing: 14) {
                timelineHeader
                ForEach(days) { day in
                    dayCard(day)
                }
            }
            .padding(28)
            .frame(maxWidth: 980)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Timeline")
        .searchable(text: $store.searchText, prompt: "Search places and activities")
        .overlay {
            if days.isEmpty {
                ContentUnavailableView.search(text: store.searchText)
            }
        }
        .sheet(item: $presentedEvent) { event in
            RouteDetailView(event: event)
        }
    }

    private var timelineHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(store.selectedYear.map { "Your \($0) timeline" } ?? "Every day has a story")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text("\(days.count.formatted()) days · newest first")
                    .font(.title3).foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                Button("Expand visible days") { expandedDays = Set(days.prefix(30).map(\.date)) }
                Button("Collapse all") { expandedDays.removeAll() }
            } label: {
                Label("View", systemImage: "slider.horizontal.3")
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.bottom, 8)
    }

    private func dayCard(_ day: DaySummary) -> some View {
        let expanded = expandedDays.contains(day.date)
        return VStack(spacing: 0) {
            Button {
                if expanded { expandedDays.remove(day.date) } else { expandedDays.insert(day.date) }
            } label: {
                HStack(spacing: 16) {
                    VStack(spacing: 0) {
                        Text(day.date.formatted(.dateTime.day()))
                            .font(.system(size: 25, weight: .bold, design: .rounded))
                        Text(day.date.formatted(.dateTime.month(.abbreviated)).uppercased())
                            .font(.caption2.weight(.black))
                            .foregroundStyle(JourneyTheme.indigo)
                    }
                    .frame(width: 54, height: 54)
                    .background(JourneyTheme.indigo.opacity(0.10), in: RoundedRectangle(cornerRadius: 13))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(day.date.formatted(.dateTime.weekday(.wide).year()))
                            .font(.headline)
                        HStack(spacing: 10) {
                            Label("\(day.eventCount) moments", systemImage: "sparkles")
                            if day.distanceMeters > 0 {
                                Label(JourneyTheme.distance(day.distanceMeters, precise: true), systemImage: "arrow.triangle.swap")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    activityDots(day.events)
                    Image(systemName: "chevron.down")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .contentShape(Rectangle())
                .padding(16)
            }
            .buttonStyle(.plain)

            if expanded {
                Divider().padding(.horizontal, 16)
                VStack(spacing: 0) {
                    ForEach(day.events) { event in
                        eventRow(event)
                        if event.id != day.events.last?.id { Divider().padding(.leading, 68) }
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(.primary.opacity(0.06)))
        .animation(.snappy(duration: 0.25), value: expanded)
    }

    private func activityDots(_ events: [JourneyEvent]) -> some View {
        HStack(spacing: -4) {
            ForEach(Array(events.prefix(4))) { event in
                Image(systemName: event.symbol)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(event.tint.gradient, in: Circle())
                    .overlay(Circle().stroke(.background, lineWidth: 2))
            }
        }
    }

    private func eventRow(_ event: JourneyEvent) -> some View {
        let hasRoute = event.path.count > 1 || (event.point != nil && event.endPoint != nil && event.point != event.endPoint)
        return Button { presentedEvent = event } label: {
            HStack(spacing: 14) {
                Text(event.start.formatted(.dateTime.hour().minute()))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 42, alignment: .trailing)
                Image(systemName: event.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(event.tint)
                    .frame(width: 30, height: 30)
                    .background(event.tint.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title).font(.subheadline.weight(.semibold))
                    Text(eventSubtitle(event))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(event.end.formatted(.dateTime.hour().minute()))
                    .font(.caption.monospacedDigit()).foregroundStyle(.tertiary)
                Image(systemName: hasRoute ? "point.topleft.down.to.point.bottomright.curvepath" : "map")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(event.tint)
                    .frame(width: 27, height: 27)
                    .background(event.tint.opacity(0.10), in: Circle())
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .help(hasRoute ? "View this route" : "View this location")
        .contextMenu {
            Button(hasRoute ? "View Route" : "View Location") { presentedEvent = event }
        }
    }

    private func eventSubtitle(_ event: JourneyEvent) -> String {
        if event.kind == .visit, let locality = store.locality(for: event) {
            return "\(locality.city), \(locality.state), \(locality.country) · \(JourneyTheme.duration(event.duration))"
        }
        return event.kind == .visit ? event.subtitle : "\(event.subtitle) · \(JourneyTheme.duration(event.duration))"
    }
}
