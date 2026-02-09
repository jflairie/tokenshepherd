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
}
