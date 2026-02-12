import Foundation

struct TrendCalculator {
    /// Compute velocity (utilization delta per hour) from recent history entries.
    /// Returns nil if fewer than 2 entries or less than 5 minutes of data.
    static func trend(
        entries: [HistoryEntry],
        isFiveHour: Bool,
        lookbackMinutes: Int = 60
    ) -> TrendInfo? {
        let cutoff = Date().addingTimeInterval(-Double(lookbackMinutes * 60))
        let recent = entries.filter { $0.ts >= cutoff }.sorted { $0.ts < $1.ts }
        guard recent.count >= 2 else { return nil }

        let first = recent.first!
        let last = recent.last!
        let spanSeconds = last.ts.timeIntervalSince(first.ts)
        guard spanSeconds >= 300 else { return nil }  // 5 min minimum

        let firstUtil = isFiveHour ? first.fiveHourUtil : first.sevenDayUtil
        let lastUtil = isFiveHour ? last.fiveHourUtil : last.sevenDayUtil
        let delta = lastUtil - firstUtil
        let velocityPerHour = delta / (spanSeconds / 3600)

        return TrendInfo(
            velocityPerHour: velocityPerHour,
            recentDelta: delta,
            lookbackMinutes: lookbackMinutes,
            spanSeconds: spanSeconds
        )
    }

    /// Bin entries into equal time buckets for sparkline rendering.
    /// Forward-fills gaps so every bucket has a value.
    static func sparklineBuckets(
        entries: [HistoryEntry],
        isFiveHour: Bool,
        windowStart: Date,
        windowEnd: Date,
        bucketCount: Int = 30
    ) -> [Double] {
        let sorted = entries.sorted { $0.ts < $1.ts }
        guard !sorted.isEmpty else { return [] }

        let totalDuration = windowEnd.timeIntervalSince(windowStart)
        guard totalDuration > 0 else { return [] }
        let bucketSize = totalDuration / Double(bucketCount)

        var buckets = [Double](repeating: -1, count: bucketCount)

        for entry in sorted {
            let offset = entry.ts.timeIntervalSince(windowStart)
            let index = min(Int(offset / bucketSize), bucketCount - 1)
            guard index >= 0 else { continue }
            buckets[index] = isFiveHour ? entry.fiveHourUtil : entry.sevenDayUtil
        }

        // Forward-fill gaps
        var lastValue = buckets.first(where: { $0 >= 0 }) ?? 0
        for i in 0..<buckets.count {
            if buckets[i] < 0 {
                buckets[i] = lastValue
            } else {
                lastValue = buckets[i]
            }
        }

        return buckets
    }
}
