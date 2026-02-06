import Foundation

// MARK: - Anthropic Quota API Response Models

struct QuotaAPIResponse: Codable {
    let quota: QuotaInfo?
    let usage: UsageInfo?
    let limits: LimitsInfo?
}

struct QuotaInfo: Codable {
    let allowed: Int?
    let used: Int?
    let remaining: Int?
    let resetsAt: String?

    enum CodingKeys: String, CodingKey {
        case allowed
        case used
        case remaining
        case resetsAt = "resets_at"
    }
}

struct UsageInfo: Codable {
    let fiveHourWindow: WindowUsage?
    let sevenDayWindow: WindowUsage?

    enum CodingKeys: String, CodingKey {
        case fiveHourWindow = "five_hour_window"
        case sevenDayWindow = "seven_day_window"
    }
}

struct WindowUsage: Codable {
    let usedPercent: Double?
    let resetsAt: String?
    let isLimited: Bool?

    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case resetsAt = "resets_at"
        case isLimited = "is_limited"
    }
}

struct LimitsInfo: Codable {
    let tier: String?
    let plan: String?
}

// MARK: - Rate Limit Headers Response

struct RateLimitInfo {
    let requestsLimit: Int?
    let requestsRemaining: Int?
    let requestsReset: Date?
    let tokensLimit: Int?
    let tokensRemaining: Int?
    let tokensReset: Date?

    init(from headers: [AnyHashable: Any]) {
        requestsLimit = (headers["anthropic-ratelimit-requests-limit"] as? String).flatMap(Int.init)
        requestsRemaining = (headers["anthropic-ratelimit-requests-remaining"] as? String).flatMap(Int.init)
        requestsReset = Self.parseDate(headers["anthropic-ratelimit-requests-reset"] as? String)
        tokensLimit = (headers["anthropic-ratelimit-tokens-limit"] as? String).flatMap(Int.init)
        tokensRemaining = (headers["anthropic-ratelimit-tokens-remaining"] as? String).flatMap(Int.init)
        tokensReset = Self.parseDate(headers["anthropic-ratelimit-tokens-reset"] as? String)
    }

    private static func parseDate(_ string: String?) -> Date? {
        guard let string = string else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string)
    }

    var usagePercent: Double? {
        guard let limit = tokensLimit, let remaining = tokensRemaining, limit > 0 else { return nil }
        return Double(limit - remaining) / Double(limit) * 100
    }
}
