import SwiftUI
import Charts

struct InsightsView: View {
    @Environment(JourneyStore.self) private var store
    @State private var seasonalMetric: PatternMetric = .activeDays
    @State private var seasonalAggregation: SeasonAggregation = .averagePerYear

    private enum SeasonAggregation: String, CaseIterable, Identifiable {
        case averagePerYear = "Average / year"
        case total = "All-time total"
        var id: String { rawValue }
    }

    private enum PatternMetric: String, CaseIterable, Identifiable {
        case activeDays = "Active days"
        case distance = "Distance"
        case journeys = "Journeys"
        case visits = "Visits"

        var id: String { rawValue }
        var axisLabel: String { self == .distance ? "km" : rawValue.lowercased() }
        var symbol: String {
            switch self {
            case .activeDays: return "calendar.badge.checkmark"
            case .distance: return "arrow.triangle.swap"
            case .journeys: return "point.topleft.down.to.point.bottomright.curvepath"
            case .visits: return "mappin.and.ellipse"
            }
        }
    }

    private var yearData: [YearSummary] {
        if let year = store.selectedYear { return store.analytics.yearSummaries.filter { $0.year == year } }
        return store.analytics.yearSummaries
    }

    private var peakSeason: SeasonalSummary? {
        store.analytics.seasonalSummaries.max { seasonalValue($0) < seasonalValue($1) }
    }

    private var busiestCalendarMonth: MonthSummary? {
        store.analytics.monthSummaries.max { $0.distanceMeters < $1.distanceMeters }
    }

    private var peakWeekday: WeekdaySummary? {
        store.analytics.weekdaySummaries.max { $0.activeDays < $1.activeDays }
    }

    private var peakHour: HourSummary? {
        store.analytics.hourSummaries.max { $0.events < $1.events }
    }

    private var activeDayCoverage: Double {
        guard let range = store.analytics.dateRange else { return 0 }
        let calendar = Calendar.autoupdatingCurrent
        let days = (calendar.dateComponents([.day], from: calendar.startOfDay(for: range.lowerBound), to: calendar.startOfDay(for: range.upperBound)).day ?? 0) + 1
        return Double(store.analytics.activeDayCount) / Double(max(1, days))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 22) {
                insightsHeader
                narrativeHighlights
                statisticalHighlights
                seasonalityPanel
                monthlyHeatmap
                routineGrid
                longRangeGrid
                records
            }
            .padding(28)
            .frame(maxWidth: 1450)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Insights")
    }

    private var insightsHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Your patterns, revealed")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("Seasonality, routines, records, and the shape of your movement over time.")
                    .font(.title3).foregroundStyle(.secondary)
            }
            Spacer()
            Label("\(store.analytics.years.count) years analyzed", systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(JourneyTheme.indigo)
                .padding(.horizontal, 13).padding(.vertical, 9)
                .background(JourneyTheme.indigo.opacity(0.10), in: Capsule())
        }
    }

    private var narrativeHighlights: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 16)], spacing: 16) {
            if let peak = peakSeason {
                narrativeCard(
                    eyebrow: "YOUR PEAK SEASON", title: peak.name,
                    detail: peakSeasonDetail(peak), symbol: seasonalMetric.symbol,
                    color: JourneyTheme.indigo
                )
            }
            if let month = busiestCalendarMonth {
                narrativeCard(
                    eyebrow: "BIGGEST TRAVEL MONTH",
                    title: month.month.formatted(.dateTime.month(.wide).year()),
                    detail: "\(JourneyTheme.distance(month.distanceMeters)) across \(month.journeys.formatted()) recorded journeys.",
                    symbol: "trophy.fill", color: JourneyTheme.gold
                )
            }
            if let weekday = peakWeekday {
                narrativeCard(
                    eyebrow: "MOST ACTIVE WEEKDAY", title: weekday.name,
                    detail: "Present in your history on \(weekday.activeDays.formatted()) active days, with \(weekday.journeys.formatted()) journeys.",
                    symbol: "calendar.day.timeline.left", color: JourneyTheme.coral
                )
            }
            if let hour = peakHour {
                narrativeCard(
                    eyebrow: "COMMON START TIME", title: hour.label,
                    detail: "More timeline moments begin around this hour than any other—\(hour.events.formatted()) in total.",
                    symbol: "clock.badge.fill", color: JourneyTheme.aqua
                )
            }
        }
    }

    private var statisticalHighlights: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 16)], spacing: 16) {
            insightPill("Average journey", JourneyTheme.distance(store.analytics.averageJourneyDistance, precise: true), "divide.circle.fill", JourneyTheme.indigo)
            insightPill("Typical journey (median)", JourneyTheme.distance(store.analytics.medianJourneyDistance, precise: true), "equal.circle.fill", JourneyTheme.aqua)
            insightPill("Longest active streak", "\(store.analytics.longestActiveStreak) days", "flame.fill", JourneyTheme.coral)
            insightPill("Days with history", activeDayCoverage.formatted(.percent.precision(.fractionLength(0))), "calendar.badge.checkmark", JourneyTheme.gold)
        }
    }

    private var seasonalityPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                SectionHeading(title: "Your seasonal rhythm", subtitle: "Which months are most active when every year is combined")
                Spacer()
                HStack(spacing: 10) {
                    Picker("Comparison", selection: $seasonalAggregation) {
                        ForEach(SeasonAggregation.allCases) { aggregation in
                            Text(aggregation.rawValue).tag(aggregation)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 190)
                    Picker("Measure", selection: $seasonalMetric) {
                        ForEach(PatternMetric.allCases) { metric in
                            Label(metric.rawValue, systemImage: metric.symbol).tag(metric)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 205)
                }
            }

            HStack(alignment: .top, spacing: 26) {
                Chart(store.analytics.seasonalSummaries) { month in
                    BarMark(
                        x: .value("Month", month.shortName),
                        y: .value(seasonalMetric.rawValue, seasonalValue(month))
                    )
                    .foregroundStyle(month.id == peakSeason?.id ? JourneyTheme.coral.gradient : JourneyTheme.indigo.gradient)
                    .cornerRadius(6)
                    .annotation(position: .top) {
                        if month.id == peakSeason?.id {
                            Text(seasonalLabel(month)).font(.caption2.bold()).foregroundStyle(JourneyTheme.coral)
                        }
                    }
                }
                .chartYAxisLabel(seasonalAxisLabel)
                .chartYAxis { AxisMarks(position: .leading) }
                .frame(minHeight: 300)

                VStack(alignment: .leading, spacing: 12) {
                    Text("TOP MONTHS").font(.caption2.weight(.black)).tracking(1.2).foregroundStyle(.secondary)
                    ForEach(Array(rankedSeasons.prefix(5).enumerated()), id: \.element.id) { index, month in
                        HStack(spacing: 10) {
                            Text("\(index + 1)")
                                .font(.caption.bold()).foregroundStyle(index == 0 ? .white : .secondary)
                                .frame(width: 24, height: 24)
                                .background(index == 0 ? JourneyTheme.coral : Color.secondary.opacity(0.12), in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(month.name).font(.subheadline.weight(.semibold))
                                Text("Recorded across \(month.activeYears) years").font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(seasonalLabel(month)).font(.caption.bold()).monospacedDigit()
                        }
                        if index < 4 { Divider() }
                    }
                }
                .frame(width: 300)
                .padding(16)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
            }

            if let peak = peakSeason {
                Label(peakSeasonDetail(peak), systemImage: "lightbulb.fill")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .journeyCard()
    }

    private var monthlyHeatmap: some View {
        let monthNames = Calendar.autoupdatingCurrent.shortMonthSymbols
        let yearNames = store.analytics.years.reversed().map(String.init)
        return VStack(alignment: .leading, spacing: 18) {
            SectionHeading(
                title: "Every month at a glance",
                subtitle: "Darker cells represent more distance—use this to spot intense periods, quiet seasons, and gaps"
            )
            Chart(store.analytics.monthSummaries) { month in
                RectangleMark(
                    x: .value("Month", month.month.formatted(.dateTime.month(.abbreviated))),
                    y: .value("Year", String(Calendar.autoupdatingCurrent.component(.year, from: month.month)))
                )
                .foregroundStyle(by: .value("Distance (km)", month.distanceMeters / 1_000))
                .cornerRadius(3)
            }
            .chartXScale(domain: monthNames)
            .chartYScale(domain: yearNames)
            .chartForegroundStyleScale(range: Gradient(colors: [JourneyTheme.indigo.opacity(0.12), JourneyTheme.indigo, JourneyTheme.coral]))
            .chartLegend(position: .bottom, alignment: .trailing)
            .chartXAxis { AxisMarks(position: .top) }
            .chartYAxis { AxisMarks(position: .leading) }
            .frame(height: max(300, CGFloat(store.analytics.years.count) * 29))
        }
        .journeyCard()
    }

    private var routineGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(minimum: 430)), GridItem(.flexible(minimum: 430))], spacing: 18) {
            weekdayChart
            hourlyChart
        }
    }

    private var weekdayChart: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeading(title: "Your week", subtitle: "Active days grouped by weekday across all years")
            Chart(store.analytics.weekdaySummaries) { day in
                BarMark(x: .value("Weekday", day.shortName), y: .value("Active days", day.activeDays))
                    .foregroundStyle(day.id == peakWeekday?.id ? JourneyTheme.gold.gradient : JourneyTheme.aqua.gradient)
                    .cornerRadius(5)
            }
            .chartYAxis { AxisMarks(position: .leading) }
            .frame(height: 250)
            if let day = peakWeekday {
                Text("\(day.name) leads, with \(day.activeDays.formatted()) active days and \(JourneyTheme.distance(day.distanceMeters)) traveled.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .journeyCard()
    }

    private var hourlyChart: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeading(title: "Your daily pulse", subtitle: "When timeline moments most often begin")
            Chart(store.analytics.hourSummaries) { hour in
                AreaMark(x: .value("Hour", hour.hour), y: .value("Moments", hour.events))
                    .foregroundStyle(JourneyTheme.indigo.opacity(0.12)).interpolationMethod(.catmullRom)
                LineMark(x: .value("Hour", hour.hour), y: .value("Moments", hour.events))
                    .foregroundStyle(JourneyTheme.heroGradient)
                    .lineStyle(.init(lineWidth: 3, lineCap: .round)).interpolationMethod(.catmullRom)
                if hour.id == peakHour?.id {
                    PointMark(x: .value("Hour", hour.hour), y: .value("Moments", hour.events))
                        .foregroundStyle(JourneyTheme.coral).symbolSize(70)
                }
            }
            .chartXAxis {
                AxisMarks(values: [0, 3, 6, 9, 12, 15, 18, 21]) { value in
                    AxisGridLine().foregroundStyle(.quaternary)
                    AxisValueLabel {
                        if let hour = value.as(Int.self) { Text(String(format: "%02d:00", hour)) }
                    }
                }
            }
            .chartYAxis { AxisMarks(position: .leading) }
            .frame(height: 250)
            if let hour = peakHour {
                Text("Your strongest concentration is around \(hour.label), when \(hour.events.formatted()) recorded moments begin.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .journeyCard()
    }

    private var longRangeGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(minimum: 430)), GridItem(.flexible(minimum: 380))], spacing: 18) {
            yearlyChart
            modeChart
        }
    }

    private var yearlyChart: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeading(title: "Distance through the years", subtitle: store.selectedYear == nil ? "Recorded kilometers by calendar year" : "The selected year in context")
            Chart(yearData) { item in
                BarMark(x: .value("Year", String(item.year)), y: .value("Kilometers", item.distanceMeters / 1_000))
                    .foregroundStyle(JourneyTheme.heroGradient).cornerRadius(5)
                    .annotation(position: .top) {
                        if yearData.count < 8 {
                            Text((item.distanceMeters / 1_000).formatted(.number.precision(.fractionLength(0))))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
            }
            .chartYAxisLabel("km")
            .chartYAxis { AxisMarks(position: .leading) }
            .frame(height: 280)
        }
        .journeyCard()
    }

    private var modeChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(title: "How you moved", subtitle: "Share of recorded distance")
            HStack(spacing: 20) {
                Chart(Array(store.analytics.modeSummaries.prefix(7))) { mode in
                    SectorMark(angle: .value("Distance", mode.distanceMeters), innerRadius: .ratio(0.62), angularInset: 1.5)
                        .foregroundStyle(by: .value("Mode", mode.name)).cornerRadius(3)
                }
                .chartLegend(.hidden)
                .frame(width: 180, height: 180)
                .overlay {
                    VStack(spacing: 2) {
                        Text(JourneyTheme.distance(store.analytics.totalDistanceMeters)).font(.headline.bold())
                        Text("total").font(.caption2).foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 9) {
                    ForEach(Array(store.analytics.modeSummaries.prefix(6))) { mode in
                        HStack {
                            Image(systemName: mode.symbol).frame(width: 18)
                            Text(mode.name).lineLimit(1)
                            Spacer()
                            Text(JourneyTheme.distance(mode.distanceMeters))
                                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
        }
        .journeyCard()
    }

    private var records: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeading(title: "Personal records", subtitle: "The outliers worth remembering")
            HStack(spacing: 16) {
                if let event = store.analytics.longestActivity {
                    recordCard("Longest journey", JourneyTheme.distance(event.distanceMeters, precise: true), event.start.formatted(.dateTime.day().month(.wide).year()), event.symbol, JourneyTheme.indigo)
                }
                if let event = store.analytics.longestVisit {
                    recordCard("Longest stay", JourneyTheme.duration(event.duration), event.start.formatted(.dateTime.day().month(.wide).year()), "hourglass", JourneyTheme.coral)
                }
                if let year = store.analytics.yearSummaries.max(by: { $0.distanceMeters < $1.distanceMeters }) {
                    recordCard("Biggest year", String(year.year), JourneyTheme.distance(year.distanceMeters), "trophy.fill", JourneyTheme.gold)
                }
                recordCard("Longest streak", "\(store.analytics.longestActiveStreak) days", "Consecutive days with timeline history", "flame.fill", JourneyTheme.aqua)
            }
        }
        .journeyCard()
    }

    private var rankedSeasons: [SeasonalSummary] {
        store.analytics.seasonalSummaries.sorted { seasonalValue($0) > seasonalValue($1) }
    }

    private func seasonalValue(_ month: SeasonalSummary) -> Double {
        let total: Double = switch seasonalMetric {
        case .activeDays: Double(month.activeDays)
        case .distance: month.distanceMeters / 1_000
        case .journeys: Double(month.journeys)
        case .visits: Double(month.visits)
        }
        guard seasonalAggregation == .averagePerYear else { return total }
        return total / Double(max(1, month.activeYears))
    }

    private func seasonalLabel(_ month: SeasonalSummary) -> String {
        let value = seasonalValue(month)
        if seasonalAggregation == .averagePerYear {
            switch seasonalMetric {
            case .activeDays: return value.formatted(.number.precision(.fractionLength(1))) + " days/yr"
            case .distance: return JourneyTheme.distance(value * 1_000) + "/yr"
            case .journeys: return value.formatted(.number.precision(.fractionLength(1))) + " trips/yr"
            case .visits: return value.formatted(.number.precision(.fractionLength(1))) + " visits/yr"
            }
        }
        switch seasonalMetric {
        case .activeDays: return "\(month.activeDays) days"
        case .distance: return JourneyTheme.distance(month.distanceMeters)
        case .journeys: return "\(month.journeys) trips"
        case .visits: return "\(month.visits) visits"
        }
    }

    private func peakSeasonDetail(_ peak: SeasonalSummary) -> String {
        let average = store.analytics.seasonalSummaries.map(seasonalValue).reduce(0, +) / 12
        let percent = average > 0 ? max(0, (seasonalValue(peak) / average) - 1) : 0
        let scope = seasonalAggregation == .averagePerYear ? "for each recorded year" : "across your complete history"
        return "\(seasonalLabel(peak)) \(scope)—\(percent.formatted(.percent.precision(.fractionLength(0)))) above your monthly average."
    }

    private var seasonalAxisLabel: String {
        seasonalMetric.axisLabel + (seasonalAggregation == .averagePerYear ? " / year" : "")
    }

    private func narrativeCard(eyebrow: String, title: String, detail: String, symbol: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(eyebrow).font(.caption2.weight(.black)).tracking(1.1).foregroundStyle(color)
                Spacer()
                Image(systemName: symbol).foregroundStyle(color)
                    .frame(width: 32, height: 32).background(color.opacity(0.12), in: Circle())
            }
            Text(title).font(.system(size: 26, weight: .bold, design: .rounded))
            Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
        .journeyCard()
    }

    private func insightPill(_ title: String, _ value: String, _ symbol: String, _ color: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.title2).foregroundStyle(color)
                .frame(width: 46, height: 46).background(color.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(value).font(.title3.bold()).lineLimit(1).minimumScaleFactor(0.7)
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .journeyCard(padding: 14)
    }

    private func recordCard(_ title: String, _ value: String, _ detail: String, _ symbol: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol).font(.title2).foregroundStyle(color)
            Text(value).font(.system(size: 24, weight: .bold, design: .rounded))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }
}
