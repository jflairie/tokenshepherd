import Foundation

struct StatsCache {
    private static let fileURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/stats-cache.json")

    /// Read stats-cache.json and return token usage summary (today/yesterday/7d) + dominant model.
    static func tokenSummary() -> TokenSummary {
        guard let data = try? Data(contentsOf: fileURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dailyTokens = json["dailyModelTokens"] as? [[String: Any]] else {
            return TokenSummary(today: 0, yesterday: 0, last7Days: 0, dominantModel: nil)
        }

        let calendar = Calendar.current
        let now = Date()
        let todayStr = dateString(now)
        let yesterdayStr = dateString(calendar.date(byAdding: .day, value: -1, to: now)!)
        let cutoff = calendar.date(byAdding: .day, value: -7, to: now)!
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var todayTokens = 0
        var yesterdayTokens = 0
        var weekTokens = 0
        var opusTokens = 0
        var sonnetTokens = 0

        for entry in dailyTokens {
            guard let dateStr = entry["date"] as? String,
                  let date = dateFormatter.date(from: dateStr),
                  let tokensByModel = entry["tokensByModel"] as? [String: Any] else { continue }

            let dayTotal = tokensByModel.values.reduce(0) { $0 + ((($1 as? Int) ?? 0)) }

            if dateStr == todayStr {
                todayTokens = dayTotal
            }
            if dateStr == yesterdayStr {
                yesterdayTokens = dayTotal
            }
            if date >= cutoff {
                weekTokens += dayTotal
                for (model, count) in tokensByModel {
                    let tokens = (count as? Int) ?? 0
                    let modelLower = model.lowercased()
                    if modelLower.contains("opus") {
                        opusTokens += tokens
                    } else if modelLower.contains("sonnet") {
                        sonnetTokens += tokens
                    }
                }
            }
        }

        let dominant: String? = (opusTokens + sonnetTokens > 0)
            ? (opusTokens >= sonnetTokens ? "Opus" : "Sonnet")
            : nil

        return TokenSummary(
            today: todayTokens,
            yesterday: yesterdayTokens,
            last7Days: weekTokens,
            dominantModel: dominant
        )
    }

    private static func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
