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

struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

struct APIService {
    private struct QuotaEndpoint {
        let url: String
        let betaHeader: String?
    }

    // Primary first, fallback second. Anthropic has moved this endpoint before.
    private static let quotaEndpoints = [
        QuotaEndpoint(url: "https://api.anthropic.com/api/oauth/usage", betaHeader: "oauth-2025-04-20"),
        QuotaEndpoint(url: "https://platform.claude.com/api/oauth/usage", betaHeader: nil),
    ]

    static func refreshToken(using refreshToken: String) async throws -> TokenResponse {
        var request = URLRequest(url: URL(string: "https://platform.claude.com/v1/oauth/token")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("tokenshepherd/0.1.0", forHTTPHeaderField: "User-Agent")

        let body: [String: String] = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": "9d1c250a-e61b-44e4-8ea0-81d4c0e3a3e8",
            "scope": "user:inference"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

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
            let responseBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.httpError(httpResponse.statusCode, responseBody)
        }

        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    static func fetchQuota(accessToken: String) async throws -> APIQuotaResponse {
        var lastError: Error = APIError.networkError("No endpoints configured")

        for endpoint in quotaEndpoints {
            var request = URLRequest(url: URL(string: endpoint.url)!)
            request.httpMethod = "GET"
            request.timeoutInterval = 20
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            if let beta = endpoint.betaHeader {
                request.setValue(beta, forHTTPHeaderField: "anthropic-beta")
            }
            request.setValue("tokenshepherd/0.1.0", forHTTPHeaderField: "User-Agent")

            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await URLSession.shared.data(for: request)
            } catch {
                lastError = APIError.networkError(error.localizedDescription)
                continue
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                lastError = APIError.networkError("Invalid response")
                continue
            }

            // 401/429 = endpoint broken, try next
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 429 {
                let body = String(data: data, encoding: .utf8) ?? ""
                NSLog("[TokenShepherd] Endpoint %@ returned %d, trying fallback: %@", endpoint.url, httpResponse.statusCode, body)
                lastError = APIError.httpError(httpResponse.statusCode, body)
                continue
            }

            guard httpResponse.statusCode == 200 else {
                let body = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw APIError.httpError(httpResponse.statusCode, body)
            }

            return try JSONDecoder().decode(APIQuotaResponse.self, from: data)
        }

        throw lastError
    }
}
