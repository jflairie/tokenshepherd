import Foundation

enum KeychainError: Error, LocalizedError {
    case notFound
    case parseError(String)
    case noCredentials

    var errorDescription: String? {
        switch self {
        case .notFound: return "No Claude Code credentials in Keychain"
        case .parseError(let msg): return "Keychain parse error: \(msg)"
        case .noCredentials: return "No valid credentials found"
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

        let expiresAt: Date
        if let expiresAtStr = dict["expiresAt"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            expiresAt = formatter.date(from: expiresAtStr) ?? Date.distantPast
        } else {
            expiresAt = Date.distantPast
        }

        return OAuthCredentials(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt,
            subscriptionType: dict["subscriptionType"] as? String,
            rateLimitTier: dict["rateLimitTier"] as? String
        )
    }
}
