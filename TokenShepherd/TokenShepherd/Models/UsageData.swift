import Foundation

// MARK: - Usage Data Model

struct UsageData {
    var tokensUsedToday: Int = 0
    var inputTokensTotal: Int = 0
    var outputTokensTotal: Int = 0
    var cacheReadTokens: Int = 0
    var cacheCreationTokens: Int = 0
    var messagesCountToday: Int = 0
    var totalMessages: Int = 0
    var totalSessions: Int = 0
    var lastUpdated: Date = Date()

    var cacheHitRatio: Double {
        let totalCacheTokens = cacheReadTokens + cacheCreationTokens
        guard totalCacheTokens > 0 else { return 0 }
        return Double(cacheReadTokens) / Double(totalCacheTokens)
    }

    var totalCost: Double {
        // Approximate cost calculation (Opus pricing)
        // Input: $15/1M tokens, Output: $75/1M tokens
        // Cache read: $1.5/1M, Cache creation: $18.75/1M
        let inputCost = Double(inputTokensTotal) * 0.000015
        let outputCost = Double(outputTokensTotal) * 0.000075
        let cacheReadCost = Double(cacheReadTokens) * 0.0000015
        let cacheCreationCost = Double(cacheCreationTokens) * 0.00001875
        return inputCost + outputCost + cacheReadCost + cacheCreationCost
    }
}

// MARK: - Quota Data Model

struct QuotaData {
    var usagePercent5hr: Double = 0.0
    var usagePercent7day: Double = 0.0
    var resetTime5hr: Date?
    var resetTime7day: Date?
    var isLimited: Bool = false
    var lastFetched: Date = Date()

    var status: UsageStatus {
        let maxPercent = max(usagePercent5hr, usagePercent7day)
        if maxPercent >= 90 {
            return .critical
        } else if maxPercent >= 70 {
            return .warning
        } else {
            return .normal
        }
    }

    var timeUntilReset: TimeInterval? {
        guard let resetTime = resetTime5hr else { return nil }
        let interval = resetTime.timeIntervalSinceNow
        return interval > 0 ? interval : nil
    }

    var formattedTimeUntilReset: String {
        guard let interval = timeUntilReset else { return "N/A" }
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

enum UsageStatus {
    case normal
    case warning
    case critical

    var color: String {
        switch self {
        case .normal: return "StatusGreen"
        case .warning: return "StatusYellow"
        case .critical: return "StatusRed"
        }
    }
}

// MARK: - Stats Cache JSON Model (Real Format)

struct StatsCache: Codable {
    let version: Int?
    let lastComputedDate: String?
    let dailyActivity: [DailyActivity]?
    let dailyModelTokens: [DailyModelTokens]?
    let modelUsage: [String: ModelUsage]?
    let totalSessions: Int?
    let totalMessages: Int?
    let firstSessionDate: String?
}

struct DailyActivity: Codable {
    let date: String
    let messageCount: Int?
    let sessionCount: Int?
    let toolCallCount: Int?
}

struct DailyModelTokens: Codable {
    let date: String
    let tokensByModel: [String: Int]?
}

struct ModelUsage: Codable {
    let inputTokens: Int?
    let outputTokens: Int?
    let cacheReadInputTokens: Int?
    let cacheCreationInputTokens: Int?
    let webSearchRequests: Int?
    let costUSD: Double?
}

// MARK: - History JSONL Model (user prompts only, not tokens)

struct HistoryEntry: Codable {
    let display: String?
    let timestamp: Int?
    let project: String?
    let sessionId: String?
}
