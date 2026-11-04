import Foundation

/// TokenShepherd's OWN OAuth credential, stored in the login keychain under a service name
/// we control (`TokenShepherd-credentials`) — deliberately SEPARATE from `Claude Code-credentials`.
///
/// Once the user signs in, this is the authoritative token and the app stops touching Claude
/// Code's rotating credential entirely (see `QuotaService.obtainAccessToken`). Reads/writes go
/// through the `security` CLI (never `SecItemCopyMatching`, which pops a password dialog).
enum AuthStore {
    static let service = "TokenShepherd-credentials"
    static let account = "tokenshepherd"

    static var isSignedIn: Bool { read() != nil }

    static func read() -> OAuthCredentials? {
        guard let json = runSecurity(["find-generic-password", "-s", service, "-w"]),
              let data = json.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = dict["accessToken"] as? String,
              let refresh = dict["refreshToken"] as? String
        else { return nil }

        let expiresAt: Date
        if let ms = dict["expiresAt"] as? Double {
            expiresAt = Date(timeIntervalSince1970: ms / 1000.0)
        } else if let ms = dict["expiresAt"] as? Int {
            expiresAt = Date(timeIntervalSince1970: Double(ms) / 1000.0)
        } else {
            expiresAt = .distantPast
        }
        return OAuthCredentials(accessToken: access, refreshToken: refresh, expiresAt: expiresAt)
    }

    static func write(_ creds: OAuthCredentials) throws {
        let dict: [String: Any] = [
            "accessToken": creds.accessToken,
            "refreshToken": creds.refreshToken,
            "expiresAt": Int(creds.expiresAt.timeIntervalSince1970 * 1000.0),
        ]
        let data = try JSONSerialization.data(withJSONObject: dict)
        let hex = data.map { String(format: "%02x", $0) }.joined()
        // -U updates the item if it already exists.
        guard runSecurity(["add-generic-password", "-U", "-a", account, "-s", service, "-X", hex]) != nil else {
            throw KeychainError.writeError("Failed to write own credential")
        }
    }

    static func clear() {
        _ = runSecurity(["delete-generic-password", "-s", service])
    }

    /// Run `/usr/bin/security` with a hard timeout, returning stdout on success (exit 0), else nil.
    /// A hung/locked keychain must never wedge the fetch loop.
    private static func runSecurity(_ arguments: [String], timeout: TimeInterval = 10) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = arguments
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()

        let sema = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in sema.signal() }
        do { try process.run() } catch { return nil }
        if sema.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            return nil
        }
        guard process.terminationStatus == 0 else { return nil }
        return String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
    }
}
