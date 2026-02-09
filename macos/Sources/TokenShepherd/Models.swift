import Foundation

// MARK: - API Response Types (match JSON shape)

struct APIQuotaWindow: Codable {
    let utilization: Double  // 0-100
    let resetsAt: String

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }
}

struct APIExtraUsage: Codable {
    let isEnabled: Bool
    let monthlyLimit: Double?
    let usedCredits: Double?

    enum CodingKeys: String, CodingKey {
        case isEnabled = "is_enabled"
        case monthlyLimit = "monthly_limit"
        case usedCredits = "used_credits"
    }
}

struct APIQuotaResponse: Codable {
    let fiveHour: APIQuotaWindow
    let sevenDay: APIQuotaWindow
    let sevenDaySonnet: APIQuotaWindow?
    let extraUsage: APIExtraUsage

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDaySonnet = "seven_day_sonnet"
        case extraUsage = "extra_usage"
    }
}

// MARK: - Domain Models

struct QuotaWindow {
    let utilization: Double  // 0.0-1.0
    let resetsAt: Date

    var resetsInFormatted: String {
        let interval = resetsAt.timeIntervalSinceNow
        guard interval > 0 else { return "now" }
        let totalMinutes = Int(interval) / 60
        let days = totalMinutes / 1440
        let hours = (totalMinutes % 1440) / 60
        let minutes = totalMinutes % 60
        if days > 0 {
            return hours > 0 ? "\(days)d \(hours)h" : "\(days)d"
        }
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var isLocked: Bool {
        utilization >= 1.0
    }
}

struct ExtraUsage {
    let isEnabled: Bool
    let monthlyLimit: Double?
    let usedCredits: Double?
}

struct QuotaData {
    let fiveHour: QuotaWindow
    let sevenDay: QuotaWindow
    let sevenDaySonnet: QuotaWindow?
    let extraUsage: ExtraUsage
    let fetchedAt: Date

    var bindingWindow: QuotaWindow {
        fiveHour.utilization >= sevenDay.utilization ? fiveHour : sevenDay
    }

    var bindingWindowDuration: TimeInterval {
        fiveHour.utilization >= sevenDay.utilization ? 18_000 : 604_800
    }
}

enum QuotaState {
    case loading
    case loaded(QuotaData)
    case error(String)
}

// MARK: - Auth

struct OAuthCredentials {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let subscriptionType: String?
    let rateLimitTier: String?

    var isExpired: Bool {
        // 5-minute buffer
        Date().timeIntervalSince(expiresAt) > -300
    }
}

// MARK: - Date Utilities

func datesMatchWithinTolerance(_ a: Date, _ b: Date, tolerance: TimeInterval = 60) -> Bool {
    abs(a.timeIntervalSince(b)) <= tolerance
}

// MARK: - History

struct HistoryEntry: Codable {
    let ts: Date
    let fiveHourUtil: Double
    let sevenDayUtil: Double
    let fiveHourResetsAt: Date
    let sevenDayResetsAt: Date
}

// MARK: - Trend

struct TrendInfo {
    let velocityPerHour: Double  // utilization delta per hour
    let recentDelta: Double      // absolute delta over lookback period
    let lookbackMinutes: Int
}

// MARK: - Window Summary

struct WindowSummary: Codable {
    let closedAt: Date
    let windowType: String       // "5-hour" or "7-day"
    let peakUtilization: Double
    let avgRate: Double          // utilization per hour
    let entryCount: Int
    let wasLocked: Bool
}

// MARK: - Token Summary

struct TokenSummary {
    let today: Int
    let yesterday: Int
    let last7Days: Int
    let dominantModel: String?
}

// MARK: - Formatting

func formatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale.current
    let calendar = Calendar.current
    if calendar.isDate(date, inSameDayAs: Date()) {
        formatter.dateFormat = "h:mm a"
    } else if calendar.isDate(date, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: Date())!) {
        formatter.dateFormat = "'tomorrow' h:mm a"
    } else {
        formatter.dateFormat = "EEE h:mm a"
    }
    return formatter.string(from: date)
}
