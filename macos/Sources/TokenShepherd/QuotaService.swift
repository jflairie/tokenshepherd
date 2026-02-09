import Foundation
import Combine

class QuotaService: ObservableObject {
    @Published var state: QuotaState = .loading
    @Published var lastCredentials: OAuthCredentials?

    private static let minRefreshInterval: TimeInterval = 30
    private var isFetching = false

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    func refresh() {
        // Skip if already fetching
        guard !isFetching else { return }

        // Skip if data is fresh enough
        if case .loaded(let data) = state,
           Date().timeIntervalSince(data.fetchedAt) < Self.minRefreshInterval {
            return
        }

        // Only show loading spinner on first fetch (no data yet)
        if case .loaded = state {
            // Keep showing stale data while refreshing
        } else {
            state = .loading
        }

        isFetching = true

        Task.detached { [weak self] in
            guard let self else { return }
            let result = await self.fetchData()
            await MainActor.run {
                self.state = result
                self.isFetching = false
            }
        }
    }

    private func fetchData() async -> QuotaState {
        // 1. Read credentials from Keychain
        let credentials: OAuthCredentials
        do {
            credentials = try KeychainService.readCredentials()
        } catch {
            return .error(error.localizedDescription)
        }

        // 2. Refresh token if expired
        var activeToken = credentials.accessToken
        if credentials.isExpired {
            NSLog("[TokenShepherd] Token expired, triggering refresh...")
            let refreshed = await APIService.triggerTokenRefresh()
            if refreshed {
                // Re-read credentials after refresh
                do {
                    let newCreds = try KeychainService.readCredentials()
                    activeToken = newCreds.accessToken
                    await MainActor.run { self.lastCredentials = newCreds }
                } catch {
                    return .error("Token refresh succeeded but re-read failed: \(error.localizedDescription)")
                }
            } else {
                return .error("Token expired and refresh failed")
            }
        } else {
            await MainActor.run { self.lastCredentials = credentials }
        }

        // 3. Fetch quota from API
        let apiResponse: APIQuotaResponse
        do {
            apiResponse = try await APIService.fetchQuota(accessToken: activeToken)
        } catch {
            return .error(error.localizedDescription)
        }

        // 4. Map to domain models
        let quotaData = mapResponse(apiResponse)

        // 5. Append to history
        HistoryStore.append(from: quotaData)

        return .loaded(quotaData)
    }

    private func mapResponse(_ api: APIQuotaResponse) -> QuotaData {
        QuotaData(
            fiveHour: mapWindow(api.fiveHour),
            sevenDay: mapWindow(api.sevenDay),
            sevenDaySonnet: api.sevenDaySonnet.map { mapWindow($0) },
            extraUsage: ExtraUsage(
                isEnabled: api.extraUsage.isEnabled,
                monthlyLimit: api.extraUsage.monthlyLimit,
                usedCredits: api.extraUsage.usedCredits
            ),
            fetchedAt: Date()
        )
    }

    private func mapWindow(_ api: APIQuotaWindow) -> QuotaWindow {
        let date = Self.isoFormatter.date(from: api.resetsAt) ?? Date()
        return QuotaWindow(
            utilization: api.utilization / 100.0,
            resetsAt: date
        )
    }
}
