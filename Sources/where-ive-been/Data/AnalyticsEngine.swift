import Foundation

struct AnalyticsEngine: Sendable {
    func analyze(_ dataset: JourneyDataset) -> JourneyAnalytics {
        let events = dataset.events
        guard let first = events.first?.start, let last = events.last?.end else { return .empty }
        let calendar = Calendar.autoupdatingCurrent
        let visits = events.filter { $0.kind == .visit }
        let activities = events.filter { $0.kind == .activity }

        var yearBuckets: [Int: (visits: Int, activities: Int, distance: Double, days: Set<Date>)] = [:]
        var modeBuckets: [String: (count: Int, distance: Double)] = [:]
        var monthBuckets: [Date: (distance: Double, visits: Int, journeys: Int, days: Set<Date>)] = [:]
        var hourBuckets: [Int: (events: Int, visits: Int, journeys: Int, distance: Double)] = [:]
        var dayBuckets: [Date: [JourneyEvent]] = [:]

        struct PlaceAccumulator {
            var name: String
            var point: GeoPoint
            var count: Int
            var duration: TimeInterval
            var mostRecent: Date
        }
        var placeBuckets: [String: PlaceAccumulator] = [:]

        for event in events {
            let year = calendar.component(.year, from: event.start)
            let day = calendar.startOfDay(for: event.start)
            let monthParts = calendar.dateComponents([.year, .month], from: event.start)
            let month = calendar.date(from: monthParts) ?? day

            var yearBucket = yearBuckets[year] ?? (0, 0, 0, [])
            if event.kind == .visit { yearBucket.visits += 1 }
            if event.kind == .activity { yearBucket.activities += 1 }
            yearBucket.distance += event.distanceMeters
            yearBucket.days.insert(day)
            yearBuckets[year] = yearBucket

            var monthBucket = monthBuckets[month] ?? (0, 0, 0, [])
            monthBucket.distance += event.distanceMeters
            if event.kind == .visit { monthBucket.visits += 1 }
            if event.kind == .activity { monthBucket.journeys += 1 }
            monthBucket.days.insert(day)
            monthBuckets[month] = monthBucket
            dayBuckets[day, default: []].append(event)

            let hour = calendar.component(.hour, from: event.start)
            var hourBucket = hourBuckets[hour] ?? (0, 0, 0, 0)
            hourBucket.events += 1
            hourBucket.distance += event.distanceMeters
            if event.kind == .visit { hourBucket.visits += 1 }
            if event.kind == .activity { hourBucket.journeys += 1 }
            hourBuckets[hour] = hourBucket

            if event.kind == .activity {
                var mode = modeBuckets[event.title] ?? (0, 0)
                mode.count += 1
                mode.distance += event.distanceMeters
                modeBuckets[event.title] = mode
            }

            if event.kind == .visit, let point = event.point {
                let key = event.placeID ?? String(format: "%.3f,%.3f", point.latitude, point.longitude)
                if var place = placeBuckets[key] {
                    place.count += 1
                    place.duration += event.duration
                    place.mostRecent = max(place.mostRecent, event.end)
                    if place.name == "Unknown" && event.title != "Unknown" { place.name = event.title }
                    placeBuckets[key] = place
                } else {
                    placeBuckets[key] = PlaceAccumulator(
                        name: event.title, point: point, count: 1,
                        duration: event.duration, mostRecent: event.end
                    )
                }
            }
        }

        let years = yearBuckets.keys.sorted()
        let yearSummaries = years.map { year in
            let bucket = yearBuckets[year]!
            return YearSummary(year: year, visits: bucket.visits, activities: bucket.activities,
                               distanceMeters: bucket.distance, activeDays: bucket.days.count)
        }
        let modeSummaries = modeBuckets.map {
            ModeSummary(name: $0.key, count: $0.value.count, distanceMeters: $0.value.distance)
        }.sorted { $0.distanceMeters > $1.distanceMeters }
        let monthSummaries = monthBuckets.map {
            MonthSummary(month: $0.key, distanceMeters: $0.value.distance,
                         visits: $0.value.visits, journeys: $0.value.journeys,
                         activeDays: $0.value.days.count)
        }.sorted { $0.month < $1.month }

        var seasonalBuckets: [Int: (distance: Double, visits: Int, journeys: Int, activeDays: Int, years: Set<Int>)] = [:]
        for summary in monthSummaries {
            let month = calendar.component(.month, from: summary.month)
            let year = calendar.component(.year, from: summary.month)
            var bucket = seasonalBuckets[month] ?? (0, 0, 0, 0, [])
            bucket.distance += summary.distanceMeters
            bucket.visits += summary.visits
            bucket.journeys += summary.journeys
            bucket.activeDays += summary.activeDays
            bucket.years.insert(year)
            seasonalBuckets[month] = bucket
        }
        let seasonalSummaries = (1...12).map { month in
            let bucket = seasonalBuckets[month] ?? (0, 0, 0, 0, [])
            return SeasonalSummary(month: month, distanceMeters: bucket.distance,
                                   visits: bucket.visits, journeys: bucket.journeys,
                                   activeDays: bucket.activeDays, activeYears: bucket.years.count)
        }

        var weekdayBuckets: [Int: (distance: Double, visits: Int, journeys: Int, activeDays: Int)] = [:]
        for (date, eventsOnDay) in dayBuckets {
            let weekday = calendar.component(.weekday, from: date)
            var bucket = weekdayBuckets[weekday] ?? (0, 0, 0, 0)
            bucket.distance += eventsOnDay.reduce(0) { $0 + $1.distanceMeters }
            bucket.visits += eventsOnDay.filter { $0.kind == .visit }.count
            bucket.journeys += eventsOnDay.filter { $0.kind == .activity }.count
            bucket.activeDays += 1
            weekdayBuckets[weekday] = bucket
        }
        let weekdaySummaries = (1...7).map { weekday in
            let bucket = weekdayBuckets[weekday] ?? (0, 0, 0, 0)
            return WeekdaySummary(weekday: weekday, distanceMeters: bucket.distance,
                                  visits: bucket.visits, journeys: bucket.journeys,
                                  activeDays: bucket.activeDays)
        }
        let hourSummaries = (0..<24).map { hour in
            let bucket = hourBuckets[hour] ?? (0, 0, 0, 0)
            return HourSummary(hour: hour, events: bucket.events, visits: bucket.visits,
                               journeys: bucket.journeys, distanceMeters: bucket.distance)
        }
        let topPlaces = placeBuckets.map {
            PlaceSummary(key: $0.key, name: $0.value.name, point: $0.value.point,
                         visits: $0.value.count, totalDuration: $0.value.duration,
                         mostRecent: $0.value.mostRecent)
        }.sorted { lhs, rhs in
            lhs.visits == rhs.visits ? lhs.totalDuration > rhs.totalDuration : lhs.visits > rhs.visits
        }
        let days = dayBuckets.map { key, value in
            DaySummary(date: key, eventCount: value.count,
                       distanceMeters: value.reduce(0) { $0 + $1.distanceMeters },
                       events: value.sorted { $0.start > $1.start })
        }.sorted { $0.date > $1.date }

        let positiveDistances = activities.map(\.distanceMeters).filter { $0 > 0 }.sorted()
        let averageJourneyDistance = positiveDistances.isEmpty ? 0 : positiveDistances.reduce(0, +) / Double(positiveDistances.count)
        let medianJourneyDistance: Double = {
            guard !positiveDistances.isEmpty else { return 0 }
            let middle = positiveDistances.count / 2
            if positiveDistances.count.isMultiple(of: 2) {
                return (positiveDistances[middle - 1] + positiveDistances[middle]) / 2
            }
            return positiveDistances[middle]
        }()
        var longestActiveStreak = 0
        var currentStreak = 0
        var previousDay: Date?
        for day in dayBuckets.keys.sorted() {
            if let previousDay,
               calendar.dateComponents([.day], from: previousDay, to: day).day == 1 {
                currentStreak += 1
            } else {
                currentStreak = 1
            }
            longestActiveStreak = max(longestActiveStreak, currentStreak)
            previousDay = day
        }

        return JourneyAnalytics(
            dateRange: first...last,
            totalDistanceMeters: activities.reduce(0) { $0 + $1.distanceMeters },
            totalVisitDuration: visits.reduce(0) { $0 + $1.duration },
            visitCount: visits.count,
            activityCount: activities.count,
            years: years,
            yearSummaries: yearSummaries,
            modeSummaries: modeSummaries,
            monthSummaries: monthSummaries,
            seasonalSummaries: seasonalSummaries,
            weekdaySummaries: weekdaySummaries,
            hourSummaries: hourSummaries,
            topPlaces: topPlaces,
            days: days,
            activeDayCount: dayBuckets.count,
            longestActivity: activities.max { $0.distanceMeters < $1.distanceMeters },
            longestVisit: visits.max { $0.duration < $1.duration },
            averageJourneyDistance: averageJourneyDistance,
            medianJourneyDistance: medianJourneyDistance,
            longestActiveStreak: longestActiveStreak
        )
    }
}
