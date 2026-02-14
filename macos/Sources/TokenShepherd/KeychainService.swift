import Foundation

enum KeychainError: Error, LocalizedError {
    case notFound
    case parseError(String)
    case noCredentials
    case writeError(String)

    var errorDescription: String? {
        switch self {
        case .notFound: return "No Claude Code credentials in Keychain"
        case .parseError(let msg): return "Keychain parse error: \(msg)"
        case .noCredentials: return "No valid credentials found"
        case .writeError(let msg): return "Keychain write error: \(msg)"
        }
    }
}

struct KeychainService {
    static func readCredentials() throws -> OAuthCredentials {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw KeychainError.notFound
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        guard let jsonString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !jsonString.isEmpty else {
            throw KeychainError.notFound
        }

        guard let jsonData = jsonString.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw KeychainError.parseError("Invalid JSON")
        }

        // Nested format: { claudeAiOauth: { accessToken, ... } }
        if let nested = json["claudeAiOauth"] as? [String: Any] {
            return try parseCredentials(nested)
        }

        // Legacy format: { accessToken, ... } at root
        if json["accessToken"] != nil {
            return try parseCredentials(json)
        }

        throw KeychainError.noCredentials
    }

    private static func parseCredentials(_ dict: [String: Any]) throws -> OAuthCredentials {
        guard let accessToken = dict["accessToken"] as? String,
              let refreshToken = dict["refreshToken"] as? String else {
            throw KeychainError.parseError("Missing accessToken or refreshToken")
        }

        // expiresAt: ms timestamp (current Claude Code format) or ISO8601 string (legacy)
        let expiresAt: Date
        if let ms = dict["expiresAt"] as? Double {
            expiresAt = Date(timeIntervalSince1970: ms / 1000.0)
        } else if let ms = dict["expiresAt"] as? Int {
            expiresAt = Date(timeIntervalSince1970: Double(ms) / 1000.0)
        } else if let str = dict["expiresAt"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            expiresAt = formatter.date(from: str) ?? Date.distantPast
        } else {
            expiresAt = Date.distantPast
        }

        return OAuthCredentials(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt
        )
    }

    /// Write updated credentials back to the Keychain, preserving existing structure.
    static func writeCredentials(_ creds: OAuthCredentials) throws {
        // Read existing JSON to preserve fields we don't manage (scopes, etc.)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw KeychainError.writeError("Cannot read existing entry")
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        guard let jsonString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              let jsonData = jsonString.data(using: .utf8),
              var json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw KeychainError.writeError("Cannot parse existing entry")
        }

        // Update the oauth dict (nested or root)
        let expiresAtMs = creds.expiresAt.timeIntervalSince1970 * 1000.0
        if var nested = json["claudeAiOauth"] as? [String: Any] {
            nested["accessToken"] = creds.accessToken
            nested["refreshToken"] = creds.refreshToken
            nested["expiresAt"] = Int(expiresAtMs)
            json["claudeAiOauth"] = nested
        } else {
            json["accessToken"] = creds.accessToken
            json["refreshToken"] = creds.refreshToken
            json["expiresAt"] = Int(expiresAtMs)
        }

        let updatedData = try JSONSerialization.data(withJSONObject: json)
        let hex = updatedData.map { String(format: "%02x", $0) }.joined()

        // Get account name from keychain entry attributes
        let account = try readAccountName()

        // Write back via security CLI (-U updates if exists)
        let writeProc = Process()
        writeProc.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        writeProc.arguments = [
            "add-generic-password", "-U",
            "-a", account,
            "-s", "Claude Code-credentials",
            "-X", hex
        ]
        let writeErr = Pipe()
        writeProc.standardError = writeErr
        writeProc.standardOutput = Pipe()
        try writeProc.run()
        writeProc.waitUntilExit()

        guard writeProc.terminationStatus == 0 else {
            let errMsg = String(data: writeErr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "unknown"
            throw KeychainError.writeError(errMsg)
        }
    }

    /// Read the account name from the Keychain entry attributes.
    private static func readAccountName() throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Claude Code-credentials"]
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw KeychainError.notFound
        }

        let output = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        // Parse "acct"<blob>="<value>" from security output
        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("\"acct\"") || trimmed.contains("\"acct\"") {
                // Format: "acct"<blob>="username"
                if let eqRange = trimmed.range(of: "=\"") {
                    let afterEq = trimmed[eqRange.upperBound...]
                    if let closeQuote = afterEq.firstIndex(of: "\"") {
                        return String(afterEq[..<closeQuote])
                    }
                }
            }
        }
        throw KeychainError.writeError("Cannot determine account name")
    }
}
