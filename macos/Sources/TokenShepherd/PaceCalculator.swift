import Foundation

struct PaceInfo {
    let timeToLimit: TimeInterval
    let timeToReset: TimeInterval
    let showWarning: Bool
    let limitAtTime: Date

    var timeToLimitFormatted: String {
        formatInterval(timeToLimit)
    }

    var timeToResetFormatted: String {
        formatInterval(timeToReset)
    }

    var limitAtFormatted: String {
        let calendar = Calendar.current
        let now = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale.current

        if calendar.isDate(limitAtTime, inSameDayAs: now) {
            formatter.dateFormat = "h:mm a"
        } else if calendar.isDate(limitAtTime, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: now)!) {
            formatter.dateFormat = "'tomorrow' h:mm a"
        } else {
            formatter.dateFormat = "EEE h:mm a"
        }
        return formatter.string(from: limitAtTime)
    }

    private func formatInterval(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(interval) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

struct PaceCalculator {
    static let fiveHourDuration: TimeInterval = 18_000   // 5h
    static let sevenDayDuration: TimeInterval = 604_800   // 7d

    static func pace(for window: QuotaWindow, windowDuration: TimeInterval) -> PaceInfo? {
        let timeToReset = window.resetsAt.timeIntervalSinceNow
        guard timeToReset > 0 else { return nil }

        let elapsed = windowDuration - timeToReset
        guard elapsed > 60 else { return nil }  // Need at least 1 min of data
        guard window.utilization > 0, !window.isLocked else { return nil }

        let rate = window.utilization / elapsed  // utilization per second
        let remaining = 1.0 - window.utilization
        let timeToLimit = remaining / rate

        let showWarning = timeToLimit < timeToReset

        return PaceInfo(
            timeToLimit: timeToLimit,
            timeToReset: timeToReset,
            showWarning: showWarning,
            limitAtTime: Date().addingTimeInterval(timeToLimit)
        )
    }
}
