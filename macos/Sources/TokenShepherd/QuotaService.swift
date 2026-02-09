import Foundation
import Combine

struct QuotaWindow {
    let utilization: Double
    let resetsAt: Date

    var resetsIn: String {
        let interval = resetsAt.timeIntervalSinceNow
        guard interval > 0 else { return "now" }
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
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
}

enum QuotaState {
    case loading
    case loaded(QuotaData)
    case error(String)
}

class QuotaService: ObservableObject {
    @Published var state: QuotaState = .loading

    private let nodePath: String
    private let projectRoot: URL
    private let libPath: String

    init() {
        self.nodePath = QuotaService.findNode()

        // #filePath → .../macos/Sources/TokenShepherd/QuotaService.swift
        // Go up: QuotaService.swift → TokenShepherd → Sources → macos → project root
        self.projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // → .../macos/Sources/TokenShepherd/
            .deletingLastPathComponent() // → .../macos/Sources/
            .deletingLastPathComponent() // → .../macos/
            .deletingLastPathComponent() // → .../tokenshepherd/
        self.libPath = projectRoot.appendingPathComponent("dist/lib.js").path
    }

    func refresh() {
        state = .loading

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            let result = self.runQuotaCommand()

            DispatchQueue.main.async {
                self.state = result
            }
        }
    }

    private func runQuotaCommand() -> QuotaState {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: nodePath)
        process.arguments = [libPath, "--quota"]
        process.currentDirectoryURL = projectRoot

        var env = ProcessInfo.processInfo.environment
        if let path = env["PATH"] {
            env["PATH"] = "/usr/local/bin:/opt/homebrew/bin:" + path
        }
        process.environment = env

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return .error("Failed to run node: \(error.localizedDescription)")
        }

        guard process.terminationStatus == 0 else {
            let errData = stderr.fileHandleForReading.readDataToEndOfFile()
            let errString = String(data: errData, encoding: .utf8) ?? "Unknown error"
            return .error(errString.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        return parseQuotaJSON(data)
    }

    private func parseQuotaJSON(_ data: Data) -> QuotaState {
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return .error("Invalid JSON response")
            }

            guard let fiveHour = parseWindow(json["five_hour"]),
                  let sevenDay = parseWindow(json["seven_day"]) else {
                return .error("Missing quota windows")
            }

            let sevenDaySonnet = parseWindow(json["seven_day_sonnet"])

            let extra = parseExtraUsage(json["extra_usage"])

            let quota = QuotaData(
                fiveHour: fiveHour,
                sevenDay: sevenDay,
                sevenDaySonnet: sevenDaySonnet,
                extraUsage: extra
            )

            return .loaded(quota)
        } catch {
            return .error("JSON parse error: \(error.localizedDescription)")
        }
    }

    private func parseWindow(_ value: Any?) -> QuotaWindow? {
        guard let dict = value as? [String: Any],
              let utilization = dict["utilization"] as? Double,
              let resetsAtStr = dict["resets_at"] as? String else {
            return nil
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: resetsAtStr) ?? Date()

        // API returns 0-100, normalize to 0-1
        return QuotaWindow(utilization: utilization / 100.0, resetsAt: date)
    }

    private func parseExtraUsage(_ value: Any?) -> ExtraUsage {
        guard let dict = value as? [String: Any] else {
            return ExtraUsage(isEnabled: false, monthlyLimit: nil, usedCredits: nil)
        }

        return ExtraUsage(
            isEnabled: dict["is_enabled"] as? Bool ?? false,
            monthlyLimit: dict["monthly_limit"] as? Double,
            usedCredits: dict["used_credits"] as? Double
        )
    }

    private static func findNode() -> String {
        // Check common locations
        let candidates = [
            "/opt/homebrew/bin/node",
            "/usr/local/bin/node",
            "/usr/bin/node"
        ]

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // Fallback: use `which`
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["node"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return path.isEmpty ? "/usr/local/bin/node" : path
    }
}
