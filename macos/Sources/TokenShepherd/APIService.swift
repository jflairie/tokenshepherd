import Foundation

enum APIError: Error, LocalizedError {
    case httpError(Int, String)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .httpError(let code, let body):
            return "API error (\(code)): \(body)"
        case .networkError(let msg):
            return "Network error: \(msg)"
        }
    }
}

struct APIService {
    static func fetchQuota(accessToken: String) async throws -> APIQuotaResponse {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("tokenshepherd/0.1.0", forHTTPHeaderField: "User-Agent")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.httpError(httpResponse.statusCode, body)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(APIQuotaResponse.self, from: data)
    }

    static func triggerTokenRefresh() async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/bash")
                process.arguments = ["-c", "echo \"\" | claude --print \"hi\" 2>/dev/null"]

                var env = ProcessInfo.processInfo.environment
                let home = FileManager.default.homeDirectoryForCurrentUser.path
                let base = env["PATH"] ?? "/usr/bin:/bin"
                env["PATH"] = "\(home)/.local/bin:/usr/local/bin:/opt/homebrew/bin:" + base
                process.environment = env

                let devNull = FileHandle.nullDevice
                process.standardOutput = devNull
                process.standardError = devNull

                var resumed = false
                let lock = NSLock()

                do {
                    try process.run()

                    // Kill after 10s if still running
                    DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
                        if process.isRunning { process.terminate() }
                    }

                    process.terminationHandler = { p in
                        lock.lock()
                        guard !resumed else { lock.unlock(); return }
                        resumed = true
                        lock.unlock()
                        continuation.resume(returning: p.terminationStatus == 0)
                    }
                } catch {
                    lock.lock()
                    guard !resumed else { lock.unlock(); return }
                    resumed = true
                    lock.unlock()
                    continuation.resume(returning: false)
                }
            }
        }
    }
}
