import Foundation
import Combine

class QuotaService: ObservableObject {
    @Published var state: QuotaState = .loading
    @Published var lastCredentials: OAuthCredentials?

    private static let minRefreshInterval: TimeInterval = 30
    private var isFetching = false
    private var backgroundTimer: Timer?
    private var previousFiveHourResetsAt: Date?
    private var previousSevenDayResetsAt: Date?

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    func startBackgroundRefresh() {
        backgroundTimer?.invalidate()
        backgroundTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

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

        // 2. Refresh token silently if expired
        var activeToken = credentials.accessToken
        var activeCredentials = credentials
        if credentials.isExpired {
            do {
                let response = try await APIService.refreshToken(using: credentials.refreshToken)
                let newCreds = OAuthCredentials(
                    accessToken: response.accessToken,
                    refreshToken: response.refreshToken ?? credentials.refreshToken,
                    expiresAt: Date().addingTimeInterval(Double(response.expiresIn)),
                    subscriptionType: credentials.subscriptionType,
                    rateLimitTier: credentials.rateLimitTier
                )
                try KeychainService.writeCredentials(newCreds)
                activeToken = newCreds.accessToken
                activeCredentials = newCreds
            } catch {
                return .error("Can't reach Anthropic — will retry")
            }
        }
        let resolvedCredentials = activeCredentials
        await MainActor.run { self.lastCredentials = resolvedCredentials }

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

        // 6. Detect window cycle changes and write summaries
        detectWindowCycle(quotaData: quotaData)

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
        let date = api.resetsAt.flatMap { Self.isoFormatter.date(from: $0) } ?? Date()
        return QuotaWindow(
            utilization: api.utilization / 100.0,
            resetsAt: date
        )
    }

    private func detectWindowCycle(quotaData: QuotaData) {
        // 5-hour window cycle
        if let prev = previousFiveHourResetsAt,
           !datesMatchWithinTolerance(prev, quotaData.fiveHour.resetsAt) {
            writeWindowSummary(resetsAt: prev, isFiveHour: true, windowType: "5-hour")
        }
        previousFiveHourResetsAt = quotaData.fiveHour.resetsAt

        // 7-day window cycle
        if let prev = previousSevenDayResetsAt,
           !datesMatchWithinTolerance(prev, quotaData.sevenDay.resetsAt) {
            writeWindowSummary(resetsAt: prev, isFiveHour: false, windowType: "7-day")
        }
        previousSevenDayResetsAt = quotaData.sevenDay.resetsAt
    }

    private func writeWindowSummary(resetsAt: Date, isFiveHour: Bool, windowType: String) {
        let entries = HistoryStore.readForWindow(resetsAt: resetsAt, isFiveHour: isFiveHour)
        guard !entries.isEmpty else { return }

        let utils = entries.map { isFiveHour ? $0.fiveHourUtil : $0.sevenDayUtil }
        let peak = utils.max() ?? 0
        let wasLocked = peak >= 1.0

        let first = entries.first!
        let last = entries.last!
        let spanHours = max(last.ts.timeIntervalSince(first.ts) / 3600, 0.001)
        let lastUtil = isFiveHour ? last.fiveHourUtil : last.sevenDayUtil
        let firstUtil = isFiveHour ? first.fiveHourUtil : first.sevenDayUtil
        let avgRate = (lastUtil - firstUtil) / spanHours

        let summary = WindowSummary(
            closedAt: Date(),
            windowType: windowType,
            peakUtilization: peak,
            avgRate: avgRate,
            entryCount: entries.count,
            wasLocked: wasLocked
        )
        WindowSummaryStore.append(summary)
        NSLog("[TokenShepherd] Window cycle closed: \(windowType), peak=\(Int(peak * 100))%, entries=\(entries.count)")
    }
}
