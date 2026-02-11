import Foundation

enum APIError: Error, LocalizedError {
    case httpError(Int, String)
    case networkError(String)
    case tokenExpired

    var errorDescription: String? {
        switch self {
        case .httpError(let code, let body):
            return "API error (\(code)): \(body)"
        case .networkError(let msg):
            return "Network error: \(msg)"
        case .tokenExpired:
            return "Token expired — run any claude command to refresh"
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
}
