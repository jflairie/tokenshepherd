import Foundation
import Combine
import os

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

    // Anthropic sends both "…T16:59:59.659753+00:00" and "…T17:00:00+00:00", and one formatter
    // reads only one of them. An unread date fell back to "resets now", so the window showed "reset".
    private static let isoFormatters: [ISO8601DateFormatter] = {
        let variants: [ISO8601DateFormatter.Options] = [
            [.withInternetDateTime, .withFractionalSeconds],
            [.withInternetDateTime],
        ]
        return variants.map { options in
            let f = ISO8601DateFormatter()
            f.formatOptions = options
            return f
        }
    }()

    private static func parseDate(_ string: String) -> Date? {
        isoFormatters.lazy.compactMap { $0.date(from: string) }.first
    }

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
                Logger.shepherd.error("fetch wedged > \(Int(Self.fetchWatchdog), privacy: .public)s — rearming")
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
                case .success(let data):
                    self.state = .loaded(data)
                    self.health = FetchHealth(lastSuccessAt: data.fetchedAt,
                                              consecutiveFailures: 0,
                                              lastFailureReason: nil)
                    self.nextAllowedFetch = .distantPast   // recovered — resume normal cadence
                case .failure(let failure):
                    self.recordFailure(failure)
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
    private func recordFailure(_ failure: FetchFailure) {
        // Log the first failure of a streak and every change of reason — enough to explain
        // an outage after the fact without a line per 60s poll for days.
        if health.consecutiveFailures == 0 || health.lastFailureReason != failure.reason {
            Logger.shepherd.error("fetch failed (\(String(describing: failure.reason), privacy: .public)): \(failure.detail, privacy: .public)")
        }
        health.consecutiveFailures += 1
        health.lastFailureReason = failure.reason
        // Back off unless we're merely waiting for Claude Code to refresh the shared keychain
        // token (.waitingForClaude): backing off there would leave the app stale for minutes
        // after Claude Code finally refreshes it. A down server or a dead refresh token gains
        // nothing from a retry every 60s.
        if failure.reason == .waitingForClaude {
            nextAllowedFetch = .distantPast
        } else {
            scheduleBackoff()
        }

        if case .loaded = state {
            // Keep showing stale data (state unchanged).
        } else if let bootstrap = QuotaService.bootstrapFromHistory() {
            // Cold start with prior history: show it, but health stays cold (no
            // lastSuccessAt) so the icon renders blind — bootstrapped data is not live.
            state = .loaded(bootstrap)
        } else {
            // No data at all. A missing/dead login gets the idle view, which offers Connect;
            // an unreachable or unreadable Anthropic is an error — reconnecting wouldn't fix it.
            switch failure.reason {
            case .unreachable: state = .error(failure.detail)
            case .unreadable: state = .error("Anthropic's reply changed shape. TokenShepherd needs an update to read it.")
            case .waitingForClaude, .loginRejected: state = .idle
            }
        }
    }

    private func scheduleBackoff() {
        let step = Double(max(health.consecutiveFailures - 1, 0))   // 1st fail → base
        let delay = min(Self.baseInterval * pow(2, step), Self.maxBackoff)
        nextAllowedFetch = Date().addingTimeInterval(delay)
    }

    /// Why a fetch produced no live data. `reason` drives the UI; `detail` is for the log.
    private struct FetchFailure: Error {
        let reason: FetchFailureReason
        let detail: String
    }

    private func fetchData() async -> Result<QuotaData, FetchFailure> {
        // 1. Obtain a valid access token (own login preferred; shared token as fallback)
        let activeToken: String
        switch await obtainAccessToken() {
        case .success(let token): activeToken = token
        case .failure(let failure): return .failure(failure)
        }

        // 2. Fetch quota from API and map it to domain models
        let quotaData: QuotaData
        do {
            quotaData = try Self.mapResponse(try await APIService.fetchQuota(accessToken: activeToken))
        } catch let error as DecodingError {
            // Anthropic answered (HTTP 200) with a reply we can't use: not a network problem.
            // `\(error)` names the field; localizedDescription ("…is missing.") doesn't.
            return .failure(FetchFailure(reason: .unreadable, detail: "\(error)"))
        } catch {
            return .failure(FetchFailure(reason: .unreachable, detail: error.localizedDescription))
        }

        // 3. Append to history
        HistoryStore.append(from: quotaData)

        // 4. Detect window cycle changes and write summaries
        detectWindowCycle(quotaData: quotaData)

        return .success(quotaData)
    }

    /// Return a valid access token, preferring TokenShepherd's OWN credential (self-refreshing,
    /// independent of Claude Code) and falling back to the shared Claude Code token before the
    /// user has signed in.
    private func obtainAccessToken() async -> Result<String, FetchFailure> {
        // 1. Own login (present once the user has signed in). Self-refresh; never touch the
        //    shared Claude Code credential.
        if let own = AuthStore.read() {
            if !own.isExpired { return .success(own.accessToken) }
            let refreshed = await refresh(own, into: .own)
            if case .success = refreshed { return refreshed }
            // Own refresh failed. Don't reintroduce the risky shared-token refresh; only reuse
            // the shared token if it happens to be valid right now (read-only, zero risk to
            // Claude Code's login). Otherwise surface why ours failed: rejected vs unreachable.
            if let shared = try? KeychainService.readCredentials(), !shared.isExpired {
                return .success(shared.accessToken)
            }
            return refreshed
        }

        // 2. No own login yet — shared Claude Code token (legacy behavior). This is the ONLY
        //    path that still refreshes the shared credential, and only when we own no login.
        //    Any failure here means "wait for Claude Code to refresh it", whatever the cause.
        guard let shared = try? KeychainService.readCredentials() else {
            return .failure(FetchFailure(reason: .waitingForClaude, detail: "no own login and no Claude Code credential"))
        }
        if !shared.isExpired { return .success(shared.accessToken) }
        return await refresh(shared, into: .shared).mapError {
            FetchFailure(reason: .waitingForClaude, detail: $0.detail)
        }
    }

    private enum CredentialStore { case own, shared }

    /// Refresh `creds` and persist the rotated credential to the matching store. Returns the new
    /// access token. A 4xx from the token endpoint (except 429) means Anthropic rejected the
    /// refresh token — retrying can't fix it; anything else (network, 5xx, 429) can recover.
    private func refresh(_ creds: OAuthCredentials, into store: CredentialStore) async -> Result<String, FetchFailure> {
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
            return .success(newCreds.accessToken)
        } catch APIError.httpError(let code, let body) where (400..<500).contains(code) && code != 429 {
            return .failure(FetchFailure(reason: .loginRejected, detail: "refresh rejected (\(code)): \(body)"))
        } catch {
            return .failure(FetchFailure(reason: .unreachable, detail: "refresh failed: \(error.localizedDescription)"))
        }
    }

    private static func bootstrapFromHistory() -> QuotaData? {
        guard let entry = HistoryStore.lastEntry() else { return nil }
        return QuotaData(
            fiveHour: entry.reading(fiveHour: true).map { QuotaWindow(utilization: $0.util, resetsAt: $0.resetsAt) },
            sevenDay: QuotaWindow(utilization: entry.sevenDayUtil, resetsAt: entry.sevenDayResetsAt),
            weeklyScoped: nil,   // history doesn't store the per-model weekly
            fetchedAt: entry.ts
        )
    }

    /// A reply is usable when it gives the weekly from some source; otherwise this throws, and
    /// the footer says "Can't read Anthropic's reply" — loud, never a quiet "Standing by".
    /// Which keys exist proves nothing: Anthropic drops and nulls fields (five_hour, 2026-10-31).
    static func mapResponse(_ api: APIQuotaResponse) throws -> QuotaData {
        // Prefer limits[]: session -> 5h, weekly_all -> 7d ("all credits"), weekly_scoped -> the
        // per-model column. Legacy five_hour/seven_day fill in when limits[] lacks an entry.
        // The sheep follows 5h + weekly_all only; Fable is deliberately not in the icon.
        let limits = api.limits ?? []
        let session = limits.first { $0.group == "session" }
        let weeklyAll = limits.first { $0.kind == "weekly_all" }
        let scoped = limits.first { $0.kind == "weekly_scoped" }
        guard let sevenDay = weeklyAll.map(mapLimit) ?? api.sevenDay.map(mapWindow) else {
            throw DecodingError.valueNotFound(QuotaWindow.self, .init(
                codingPath: [],
                debugDescription: "no weekly window: no weekly_all in limits[], seven_day null or absent"))
        }
        return QuotaData(
            fiveHour: session.map(mapLimit) ?? api.fiveHour.map(mapWindow),   // nil = no 5h limit reported
            sevenDay: sevenDay,
            weeklyScoped: scoped.map(mapLimit),
            fetchedAt: Date()
        )
    }

    private static func mapLimit(_ limit: APILimit) -> QuotaWindow {
        let date = limit.resetsAt.flatMap(parseDate) ?? Date()
        // Carry the per-model name on the scoped weekly, for the "Fable · 68%" detail row.
        let label = limit.kind == "weekly_scoped" ? limit.scope?.model?.displayName : nil
        return QuotaWindow(utilization: limit.percent / 100.0, resetsAt: date, label: label)
    }

    /// A reported window with a null `resets_at` (idle, nothing used yet) resets now: the UI's
    /// expired treatment ("—" / "reset"). Unlike an unreported window, which has no column.
    private static func mapWindow(_ api: APIQuotaWindow) -> QuotaWindow {
        let date = api.resetsAt.flatMap(parseDate) ?? Date()
        return QuotaWindow(
            utilization: api.utilization / 100.0,
            resetsAt: date
        )
    }

    private func detectWindowCycle(quotaData: QuotaData) {
        // 5-hour window cycle (only while Anthropic reports one)
        if let fiveHour = quotaData.fiveHour {
            if let prev = previousFiveHourResetsAt,
               !datesMatchWithinTolerance(prev, fiveHour.resetsAt) {
                writeWindowSummary(resetsAt: prev, isFiveHour: true, windowType: "5-hour")
            }
            previousFiveHourResetsAt = fiveHour.resetsAt
        }

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

        // Every entry has this window's reading: readForWindow matched on it.
        let utils = entries.compactMap { $0.reading(fiveHour: isFiveHour)?.util }
        let peak = utils.max() ?? 0
        let wasLocked = peak >= 1.0

        let first = entries.first!
        let last = entries.last!
        let spanHours = max(last.ts.timeIntervalSince(first.ts) / 3600, 0.001)
        let avgRate = ((utils.last ?? 0) - (utils.first ?? 0)) / spanHours

        let summary = WindowSummary(
            closedAt: Date(),
            windowType: windowType,
            peakUtilization: peak,
            avgRate: avgRate,
            entryCount: entries.count,
            wasLocked: wasLocked
        )
        WindowSummaryStore.append(summary)
        Logger.shepherd.debug("window cycle closed: \(windowType, privacy: .public), peak=\(Int(peak * 100), privacy: .public)%, entries=\(entries.count, privacy: .public)")
    }
}
