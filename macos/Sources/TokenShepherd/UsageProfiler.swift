import Foundation

struct UsageProfiler {
    /// Minimum samples per hour bucket to fully trust the rate.
    /// Below this, the rate is attenuated proportionally (confidence weight).
    private static let confidenceThreshold: Double = 30

    /// Build hourly consumption profile from all available history (up to 7 days).
    /// Returns 24 confidence-weighted rates (utilization per hour) indexed by hour-of-day.
    /// Buckets with few samples are attenuated toward 0 to prevent outlier spikes
    /// from dominating the projection.
    static func hourlyProfile(isFiveHour: Bool) -> [Double] {
        let entries = HistoryStore.read(since: Date().addingTimeInterval(-7 * 86400))
            .sorted { $0.ts < $1.ts }

        guard entries.count >= 2 else { return Array(repeating: 0, count: 24) }

        var hourlySum = Array(repeating: 0.0, count: 24)
        var hourlyCounts = Array(repeating: 0, count: 24)
        let calendar = Calendar.current

        for i in 1..<entries.count {
            let prev = entries[i - 1]
            let curr = entries[i]

            let prevReset = isFiveHour ? prev.fiveHourResetsAt : prev.sevenDayResetsAt
            let currReset = isFiveHour ? curr.fiveHourResetsAt : curr.sevenDayResetsAt
            guard datesMatchWithinTolerance(prevReset, currReset) else { continue }

            let prevUtil = isFiveHour ? prev.fiveHourUtil : prev.sevenDayUtil
            let currUtil = isFiveHour ? curr.fiveHourUtil : curr.sevenDayUtil
            let delta = currUtil - prevUtil
            guard delta >= 0 else { continue }

            let interval = curr.ts.timeIntervalSince(prev.ts)
            guard interval > 0, interval < 300 else { continue }

            let ratePerHour = delta / (interval / 3600)
            let hour = calendar.component(.hour, from: prev.ts)

            hourlySum[hour] += ratePerHour
            hourlyCounts[hour] += 1
        }

        return (0..<24).map { hour in
            guard hourlyCounts[hour] > 0 else { return 0.0 }
            let avgRate = hourlySum[hour] / Double(hourlyCounts[hour])
            let confidence = min(Double(hourlyCounts[hour]) / confidenceThreshold, 1.0)
            return avgRate * confidence
        }
    }

    /// Project utilization at reset using hourly usage profile.
    /// Walks forward hour-by-hour from now to resetsAt, summing expected
    /// consumption per time-of-day slot. Returns nil if insufficient history.
    static func projectAtReset(
        currentUtil: Double,
        resetsAt: Date,
        isFiveHour: Bool
    ) -> Double? {
        let profile = hourlyProfile(isFiveHour: isFiveHour)

        let activeHours = profile.filter { $0 > 0 }.count
        guard activeHours >= 3 else { return nil }

        let now = Date()
        let timeToReset = resetsAt.timeIntervalSince(now)
        guard timeToReset > 0 else { return nil }

        let calendar = Calendar.current
        var projected = currentUtil
        var cursor = now

        while cursor < resetsAt {
            let hour = calendar.component(.hour, from: cursor)
            let minute = calendar.component(.minute, from: cursor)
            let second = calendar.component(.second, from: cursor)

            let secondsIntoHour = Double(minute * 60 + second)
            let secondsLeftInHour = 3600.0 - secondsIntoHour
            let slotSeconds = min(secondsLeftInHour, resetsAt.timeIntervalSince(cursor))

            projected += profile[hour] * (slotSeconds / 3600.0)
            cursor = cursor.addingTimeInterval(slotSeconds)
        }

        return projected
    }
}
