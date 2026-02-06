import Foundation

// MARK: - Quota API Client

class QuotaAPI {
    static let shared = QuotaAPI()

    private let baseURL = "https://api.anthropic.com"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        session = URLSession(configuration: config)
    }

    // MARK: - Public API

    /// Fetches current quota/rate limit information
    /// Note: This uses a lightweight messages request to get rate limit headers
    func fetchQuotaInfo() async throws -> QuotaData {
        guard let apiKey = KeychainService.shared.getAnthropicAPIKey() ??
                          KeychainService.shared.getClaudeToken() else {
            throw QuotaAPIError.noCredentials
        }

        // Make a minimal API call to get rate limit headers
        let url = URL(string: "\(baseURL)/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        // Minimal request body - will fail but we get headers
        let body: [String: Any] = [
            "model": "claude-3-haiku-20240307",
            "max_tokens": 1,
            "messages": [["role": "user", "content": "."]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw QuotaAPIError.invalidResponse
        }

        // Parse rate limit headers
        let headers = httpResponse.allHeaderFields
        let rateLimitInfo = RateLimitInfo(from: headers)

        // Build QuotaData from headers
        var quotaData = QuotaData()
        quotaData.lastFetched = Date()

        if let usagePercent = rateLimitInfo.usagePercent {
            quotaData.usagePercent5hr = usagePercent
        }

        if let resetTime = rateLimitInfo.tokensReset {
            quotaData.resetTime5hr = resetTime
        }

        // Check if we're rate limited
        if httpResponse.statusCode == 429 {
            quotaData.isLimited = true
            quotaData.usagePercent5hr = 100
        }

        return quotaData
    }

    /// Performs a health check to verify API connectivity
    func healthCheck() async -> Bool {
        guard let apiKey = KeychainService.shared.getAnthropicAPIKey() ??
                          KeychainService.shared.getClaudeToken() else {
            return false
        }

        // Simple GET request to verify connectivity
        guard let url = URL(string: "\(baseURL)/v1/models") else { return false }
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        do {
            let (_, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
        } catch {
            return false
        }

        return false
    }
}

// MARK: - Errors

enum QuotaAPIError: Error, LocalizedError {
    case noCredentials
    case invalidResponse
    case networkError(Error)
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .noCredentials:
            return "No API credentials found in Keychain or environment"
        case .invalidResponse:
            return "Invalid response from API"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .rateLimited:
            return "Rate limited by API"
        }
    }
}
