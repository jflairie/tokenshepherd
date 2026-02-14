import Foundation

struct HistoryStore {
    private static let directoryURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".tokenshepherd")
    private static let fileURL = directoryURL.appendingPathComponent("history.jsonl")

    static func append(from quota: QuotaData) {
        let entry = HistoryEntry(
            ts: quota.fetchedAt,
            fiveHourUtil: quota.fiveHour.utilization,
            sevenDayUtil: quota.sevenDay.utilization,
            fiveHourResetsAt: quota.fiveHour.resetsAt,
            sevenDayResetsAt: quota.sevenDay.resetsAt
        )

        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(entry)
            guard var line = String(data: data, encoding: .utf8) else { return }
            line += "\n"

            if FileManager.default.fileExists(atPath: fileURL.path) {
                let handle = try FileHandle(forWritingTo: fileURL)
                handle.seekToEndOfFile()
                handle.write(line.data(using: .utf8)!)
                handle.closeFile()
            } else {
                try line.write(to: fileURL, atomically: true, encoding: .utf8)
            }
        } catch {
            NSLog("[TokenShepherd] History write error: \(error.localizedDescription)")
        }
    }

    static func read(since: Date) -> [HistoryEntry] {
        guard let data = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return data.split(separator: "\n").compactMap { line in
            guard let lineData = line.data(using: .utf8),
                  let entry = try? decoder.decode(HistoryEntry.self, from: lineData),
                  entry.ts >= since else {
                return nil
            }
            return entry
        }
    }

    /// Last recorded entry (for bootstrapping on restart).
    static func lastEntry() -> HistoryEntry? {
        guard let data = try? String(contentsOf: fileURL, encoding: .utf8),
              let lastLine = data.split(separator: "\n").last,
              let lineData = lastLine.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(HistoryEntry.self, from: lineData)
    }

    /// Prune entries older than 7 days. Call on startup.
    static func prune() {
        let cutoff = Date().addingTimeInterval(-7 * 86400)
        let entries = read(since: cutoff)
        guard !entries.isEmpty else { return }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let lines = entries.compactMap { entry -> String? in
                guard let data = try? encoder.encode(entry) else { return nil }
                return String(data: data, encoding: .utf8)
            }
            try lines.joined(separator: "\n").appending("\n")
                .write(to: fileURL, atomically: true, encoding: .utf8)
            NSLog("[TokenShepherd] Pruned history to \(entries.count) entries")
        } catch {
            NSLog("[TokenShepherd] History prune error: \(error.localizedDescription)")
        }
    }

    /// Read history entries belonging to a specific window cycle (matched by resetsAt within tolerance).
    static func readForWindow(
        resetsAt: Date,
        isFiveHour: Bool,
        since: Date = Date.distantPast
    ) -> [HistoryEntry] {
        read(since: since).filter { entry in
            let entryResetsAt = isFiveHour ? entry.fiveHourResetsAt : entry.sevenDayResetsAt
            return datesMatchWithinTolerance(entryResetsAt, resetsAt)
        }
    }
}

// MARK: - Window Summary Store

struct WindowSummaryStore {
    private static let directoryURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".tokenshepherd")
    private static let fileURL = directoryURL.appendingPathComponent("windows.jsonl")

    static func read() -> [WindowSummary] {
        guard let data = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return data.split(separator: "\n").compactMap { line in
            guard let lineData = line.data(using: .utf8) else { return nil }
            return try? decoder.decode(WindowSummary.self, from: lineData)
        }
    }

    /// Most recent summary for a given window type.
    static func lastSummary(windowType: String) -> WindowSummary? {
        read().filter { $0.windowType == windowType }.last
    }

    static func append(_ summary: WindowSummary) {
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(summary)
            guard var line = String(data: data, encoding: .utf8) else { return }
            line += "\n"

            if FileManager.default.fileExists(atPath: fileURL.path) {
                let handle = try FileHandle(forWritingTo: fileURL)
                handle.seekToEndOfFile()
                handle.write(line.data(using: .utf8)!)
                handle.closeFile()
            } else {
                try line.write(to: fileURL, atomically: true, encoding: .utf8)
            }
        } catch {
            NSLog("[TokenShepherd] Window summary write error: \(error.localizedDescription)")
        }
    }
}
