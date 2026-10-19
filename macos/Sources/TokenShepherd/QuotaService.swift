import Foundation
import Combine

class QuotaService: ObservableObject {
    @Published var state: QuotaState = .loading
    /// Fetch freshness, published alongside `state` so the UI can signal staleness
    /// without the data itself changing (a failed fetch keeps the stale `state`).
    @Published private(set) var health = FetchHealth.initial

    private static let minRefreshInterval: TimeInterval = 30
    private static let baseInterval: TimeInterval = 60      // matches the poll timer
    private static let maxBackoff: TimeInterval = 900       // 15 min cap
    private var isFetching = false
    private var fetchStartedAt: Date?                       // watchdog: when the in-flight fetch began
    private static let fetchWatchdog: TimeInterval = 120    // rearm isFetching if a fetch hangs this long
    private var nextAllowedFetch: Date = .distantPast       // backoff gate for auto-polls
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

    /// `force` (menu open, ⌘R, wake) bypasses the freshness + backoff gates so an
    /// explicit user/system request always attempts a fetch. Auto-polls do not, so a
    /// rate-limited endpoint isn't hammered every 60s during an outage.
    func refresh(force: Bool = false) {
        // Skip if a fetch is already in flight — but rearm if it has wedged. A hung
        // subprocess with no timeout used to freeze this loop permanently (nothing ever
        // reset isFetching), leaving the sheep blind/stale until a manual restart.
        if isFetching {
            if let started = fetchStartedAt, Date().timeIntervalSince(started) > Self.fetchWatchdog {
                NSLog("[TokenShepherd] fetch wedged > %.0fs — rearming", Self.fetchWatchdog)
                isFetching = false
            } else {
                return
            }
        }

        if !force {
            // Respect backoff after repeated failures
            if Date() < nextAllowedFetch { return }

            // Skip if data is fresh enough
            if case .loaded(let data) = state,
               Date().timeIntervalSince(data.fetchedAt) < Self.minRefreshInterval {
                return
            }
        }

        // Only show loading spinner on first fetch (no data yet)
        if case .loaded = state {
            // Keep showing stale data while refreshing
        } else {
            state = .loading
        }

        isFetching = true
        fetchStartedAt = Date()

        Task.detached { [weak self] in
            guard let self else { return }
            let result = await self.fetchData()
            await MainActor.run {
                switch result {
                case .loaded(let data):
                    self.state = .loaded(data)
                    self.health = FetchHealth(lastSuccessAt: data.fetchedAt,
                                              consecutiveFailures: 0,
                                              lastFailureReason: nil)
                    self.nextAllowedFetch = .distantPast   // recovered — resume normal cadence
                case .idle:
                    self.recordFailure(reason: .waitingForClaude, fallback: result)
                case .error:
                    self.recordFailure(reason: .unreachable, fallback: result)
                case .loading:
                    break   // fetchData never returns .loading
                }
                self.isFetching = false
                self.fetchStartedAt = nil
            }
        }
    }

    /// A fetch attempt failed. Keep the last-known data on screen (don't blank the UI),
    /// but record the failure so the icon/footer can be honest, and back off the next
    /// auto-poll. `state` is intentionally left unchanged when stale data exists — the
    /// `health` change alone drives the UI, so backing off the poll can't freeze the signal.
    private func recordFailure(reason: FetchFailureReason, fallback: QuotaState) {
        health.consecutiveFailures += 1
        health.lastFailureReason = reason
        // Back off only when the endpoint is unreachable (don't hammer a down server). When
        // we're merely waiting for Claude Code to refresh the shared keychain token
        // (.waitingForClaude), keep polling at the normal 60s cadence — backing off here would
        // leave the app stale for minutes after Claude Code finally refreshes the token.
        if reason == .unreachable {
            scheduleBackoff()
        } else {
            nextAllowedFetch = .distantPast
        }

        if case .loaded = state {
            // Keep showing stale data (state unchanged).
        } else if let bootstrap = QuotaService.bootstrapFromHistory() {
            // Cold start with prior history: show it, but health stays cold (no
            // lastSuccessAt) so the icon renders blind — bootstrapped data is not live.
            state = .loaded(bootstrap)
        } else {
            state = fallback
        }
    }

    private func scheduleBackoff() {
        let step = Double(max(health.consecutiveFailures - 1, 0))   // 1st fail → base
        let delay = min(Self.baseInterval * pow(2, step), Self.maxBackoff)
        nextAllowedFetch = Date().addingTimeInterval(delay)
    }

    private func fetchData() async -> QuotaState {
        // 1. Obtain a valid access token (own login preferred; shared token as fallback)
        guard let activeToken = await obtainAccessToken() else {
            // No usable token — either not signed in and the shared token is expired, or our
            // own login was revoked. Expected idle state (offer sign-in in the UI), not an error.
            return .idle
        }

        // 2. Fetch quota from API
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

    /// Return a valid access token, preferring TokenShepherd's OWN credential (self-refreshing,
    /// independent of Claude Code) and falling back to the shared Claude Code token before the
    /// user has signed in. Returns nil when no live token can be produced.
    private func obtainAccessToken() async -> String? {
        // 1. Own login (present once the user has signed in). Self-refresh; never touch the
        //    shared Claude Code credential.
        if let own = AuthStore.read() {
            if !own.isExpired { return own.accessToken }
            if let refreshed = await refresh(own, into: .own) { return refreshed }
            // Own refresh failed → the independent login was revoked/expired (needs re-sign-in).
            // Don't reintroduce the risky shared-token refresh; only reuse the shared token if
            // it happens to be valid right now (read-only, zero risk to Claude Code's login).
            if let shared = try? KeychainService.readCredentials(), !shared.isExpired {
                return shared.accessToken
            }
            return nil
        }

        // 2. No own login yet — shared Claude Code token (legacy behavior). This is the ONLY
        //    path that still refreshes the shared credential, and only when we own no login.
        guard let shared = try? KeychainService.readCredentials() else { return nil }
        if !shared.isExpired { return shared.accessToken }
        return await refresh(shared, into: .shared)
    }

    private enum CredentialStore { case own, shared }

    /// Refresh `creds` and persist the rotated credential to the matching store. Returns the new
    /// access token, or nil on failure.
    private func refresh(_ creds: OAuthCredentials, into store: CredentialStore) async -> String? {
        do {
            let response = try await APIService.refreshToken(using: creds.refreshToken)
            let newCreds = OAuthCredentials(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken ?? creds.refreshToken,
                expiresAt: Date().addingTimeInterval(Double(response.expiresIn))
            )
            switch store {
            case .own:    try AuthStore.write(newCreds)
            case .shared: try KeychainService.writeCredentials(newCreds)
            }
            return newCreds.accessToken
        } catch {
            return nil
        }
    }

    private static func bootstrapFromHistory() -> QuotaData? {
        guard let entry = HistoryStore.lastEntry() else { return nil }
        return QuotaData(
            fiveHour: QuotaWindow(utilization: entry.fiveHourUtil, resetsAt: entry.fiveHourResetsAt),
            sevenDay: QuotaWindow(utilization: entry.sevenDayUtil, resetsAt: entry.sevenDayResetsAt),
            weeklyScoped: nil,   // history doesn't store the per-model weekly
            fetchedAt: entry.ts
        )
    }

    private func mapResponse(_ api: APIQuotaResponse) -> QuotaData {
        // Prefer the new limits[] array: session -> 5h, weekly_all -> 7d ("all credits"),
        // weekly_scoped -> the per-model detail row. The sheep is driven by 5h + weekly_all
        // only; the scoped (Fable) limit is a popup detail, deliberately not in the icon.
        if let limits = api.limits, !limits.isEmpty {
            let session = limits.first { $0.group == "session" }
            let weeklyAll = limits.first { $0.kind == "weekly_all" }
            let scoped = limits.first { $0.kind == "weekly_scoped" }
            return QuotaData(
                fiveHour: session.map(mapLimit) ?? mapWindow(api.fiveHour),
                sevenDay: weeklyAll.map(mapLimit) ?? mapWindow(api.sevenDay),
                weeklyScoped: scoped.map(mapLimit),
                fetchedAt: Date()
            )
        }
        // Fallback: legacy two-field response (also the path if limits[] is dropped/malformed).
        return QuotaData(
            fiveHour: mapWindow(api.fiveHour),
            sevenDay: mapWindow(api.sevenDay),
            weeklyScoped: nil,
            fetchedAt: Date()
        )
    }

    private func mapLimit(_ limit: APILimit) -> QuotaWindow {
        let date = limit.resetsAt.flatMap { Self.isoFormatter.date(from: $0) } ?? Date()
        // Carry the per-model name on the scoped weekly, for the "Fable · 68%" detail row.
        let label = limit.kind == "weekly_scoped" ? limit.scope?.model?.displayName : nil
        return QuotaWindow(utilization: limit.percent / 100.0, resetsAt: date, label: label)
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
