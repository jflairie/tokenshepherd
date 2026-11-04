import Foundation
import CryptoKit

/// TokenShepherd's OWN OAuth login (PKCE), independent of the Claude Code CLI.
///
/// Why this exists: the shared `Claude Code-credentials` keychain token is only refreshed
/// while the Claude Code *CLI* is active. A user who works only in the Claude Desktop app
/// never refreshes it, so the app goes blind. An independent login lets us refresh ourselves
/// and never depend on terminal use — and never risk Claude Code's own rotating credential.
///
/// Flow (RFC 8252 loopback — no paste): open `authorizeURL(...)` in the browser; after the
/// user approves, Anthropic redirects to `http://localhost:54545/callback?code=…&state=…`,
/// which a short-lived local listener catches (`LoopbackServer`). We then `exchangeCode(...)`.
///
/// Constants are copied verbatim from Claude Code's real OAuth client (widely mirrored in
/// open-source implementations) — the client_id, loopback redirect, and port must match what
/// Anthropic registered for this client or the authorize page rejects the request.
enum AuthError: Error, LocalizedError {
    case stateMismatch
    case exchangeFailed(Int, String)
    case network(String)
    case noRefreshToken

    var errorDescription: String? {
        switch self {
        case .stateMismatch: return "Security check failed (state mismatch). Try signing in again."
        case .exchangeFailed(let code, let body): return "Sign-in failed (\(code)): \(body)"
        case .network(let msg): return "Network error: \(msg)"
        case .noRefreshToken: return "Sign-in didn't return a refresh token; can't stay connected."
        }
    }
}

struct PKCE {
    let verifier: String
    let challenge: String
}

enum AuthService {
    static let clientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    static let authorizeEndpoint = "https://claude.ai/oauth/authorize"
    static let tokenEndpoint = "https://platform.claude.com/v1/oauth/token"
    static let callbackPort: UInt16 = 54545
    static let redirectURI = "http://localhost:54545/callback"
    // Subset of the scopes Claude Code requests — enough to read usage. Deliberately excludes
    // `org:create_api_key` (rejected as "unknown scope" on some subscription accounts) since we
    // never mint API keys.
    static let scope = "user:inference user:profile"

    // MARK: - PKCE

    static func generatePKCE() -> PKCE {
        let verifier = base64URL(randomBytes(32))
        let challenge = base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
        return PKCE(verifier: verifier, challenge: challenge)
    }

    static func randomState() -> String { base64URL(randomBytes(32)) }

    // MARK: - Authorize

    static func authorizeURL(challenge: String, state: String) -> URL {
        var components = URLComponents(string: authorizeEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
        ]
        return components.url!
    }

    // MARK: - Token exchange

    /// Exchange the callback's `code` (with its `state` and our PKCE `verifier`) for credentials.
    static func exchangeCode(code: String, state: String, verifier: String) async throws -> OAuthCredentials {
        var request = URLRequest(url: URL(string: tokenEndpoint)!)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("tokenshepherd/0.1.0", forHTTPHeaderField: "User-Agent")
        let body: [String: String] = [
            "grant_type": "authorization_code",
            "code": code,
            "state": state,
            "redirect_uri": redirectURI,
            "client_id": clientID,
            "code_verifier": verifier,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AuthError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw AuthError.network("Invalid response")
        }
        guard http.statusCode == 200 else {
            throw AuthError.exchangeFailed(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }

        let token = try JSONDecoder().decode(TokenResponse.self, from: data)
        guard let refresh = token.refreshToken else { throw AuthError.noRefreshToken }
        return OAuthCredentials(
            accessToken: token.accessToken,
            refreshToken: refresh,
            expiresAt: Date().addingTimeInterval(Double(token.expiresIn))
        )
    }

    // MARK: - Helpers

    private static func randomBytes(_ count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes)
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
