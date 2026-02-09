import Foundation

struct StatsCache {
    private static let fileURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/stats-cache.json")

    /// Read stats-cache.json and determine the dominant model over the last 7 days.
    /// Returns "Opus" or "Sonnet" (or nil if unreadable/empty).
    static func dominantModel() -> String? {
        guard let data = try? Data(contentsOf: fileURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dailyTokens = json["dailyModelTokens"] as? [[String: Any]] else {
            return nil
        }

        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -7, to: Date())!
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var opusTokens: Int = 0
        var sonnetTokens: Int = 0

        for entry in dailyTokens {
            guard let dateStr = entry["date"] as? String,
                  let date = dateFormatter.date(from: dateStr),
                  date >= cutoff,
                  let tokensByModel = entry["tokensByModel"] as? [String: Any] else { continue }

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

        guard opusTokens + sonnetTokens > 0 else { return nil }
        return opusTokens >= sonnetTokens ? "Opus" : "Sonnet"
    }
}
