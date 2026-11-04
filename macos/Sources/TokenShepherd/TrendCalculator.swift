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

        guard let firstUtil = first.reading(fiveHour: isFiveHour)?.util,
              let lastUtil = last.reading(fiveHour: isFiveHour)?.util else { return nil }
        let delta = lastUtil - firstUtil
        let velocityPerHour = delta / (spanSeconds / 3600)

        return TrendInfo(
            velocityPerHour: velocityPerHour,
            recentDelta: delta,
            lookbackMinutes: lookbackMinutes,
            spanSeconds: spanSeconds
        )
    }

}
