import Foundation
import Security

// MARK: - Keychain Service

class KeychainService {
    static let shared = KeychainService()

    private let claudeServiceName = "claude.ai"
    private let anthropicServiceName = "api.anthropic.com"

    private init() {}

    // MARK: - Public API

    /// Retrieves the Claude Code OAuth token from Keychain
    func getClaudeToken() -> String? {
        // Try multiple possible keychain entries
        let possibleServices = [
            "claude.ai",
            "api.anthropic.com",
            "anthropic-api",
            "claude-code"
        ]

        for service in possibleServices {
            if let token = getPassword(service: service, account: "") {
                return token
            }
            // Also try with common account names
            for account in ["", "default", "oauth", "api_key"] {
                if let token = getPassword(service: service, account: account) {
                    return token
                }
            }
        }

        // Try generic password search
        return searchGenericPassword(containing: "anthropic")
    }

    /// Retrieves the Anthropic API key if stored separately
    func getAnthropicAPIKey() -> String? {
        // Check environment variable first
        if let envKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] {
            return envKey
        }

        // Check common keychain locations
        let possibleServices = [
            "anthropic-api-key",
            "ANTHROPIC_API_KEY",
            "api.anthropic.com"
        ]

        for service in possibleServices {
            if let key = getPassword(service: service, account: "") {
                return key
            }
        }

        return nil
    }

    // MARK: - Private Helpers

    private func getPassword(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let password = String(data: data, encoding: .utf8) else {
            return nil
        }

        return password
    }

    private func searchGenericPassword(containing searchTerm: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let items = result as? [[String: Any]] else {
            return nil
        }

        for item in items {
            let service = item[kSecAttrService as String] as? String ?? ""
            let account = item[kSecAttrAccount as String] as? String ?? ""

            if service.lowercased().contains(searchTerm.lowercased()) ||
               account.lowercased().contains(searchTerm.lowercased()) {
                if let data = item[kSecValueData as String] as? Data,
                   let password = String(data: data, encoding: .utf8) {
                    return password
                }
            }
        }

        return nil
    }

    /// Saves a token to keychain (for testing or manual configuration)
    func saveToken(_ token: String, service: String = "tokenshepherd") -> Bool {
        // Delete existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new item
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "",
            kSecValueData as String: token.data(using: .utf8)!
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }
}
