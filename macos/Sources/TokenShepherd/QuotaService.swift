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
    private var bindingWeeklyKind: String?                  // hysteresis: which weekly limit is currently binding
    private static let bindingHysteresis: Double = 5.0      // pts the challenger must lead by to switch

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
        scheduleBackoff()

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
        // 1. Read credentials from Keychain
        let credentials: OAuthCredentials
        do {
            credentials = try KeychainService.readCredentials()
        } catch {
            return .error(error.localizedDescription)
        }

        // 2. Refresh token silently if expired
        var activeToken = credentials.accessToken
        if credentials.isExpired {
            do {
                let response = try await APIService.refreshToken(using: credentials.refreshToken)
                let newCreds = OAuthCredentials(
                    accessToken: response.accessToken,
                    refreshToken: response.refreshToken ?? credentials.refreshToken,
                    expiresAt: Date().addingTimeInterval(Double(response.expiresIn))
                )
                try KeychainService.writeCredentials(newCreds)
                activeToken = newCreds.accessToken
            } catch {
                // Token expired and refresh failed — Claude hasn't been used recently.
                // This is expected idle state, not an error. Claude Code will refresh
                // its own token when used, and we'll pick it up next cycle.
                return .idle
            }
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

        // 6. Detect window cycle changes and write summaries
        detectWindowCycle(quotaData: quotaData)

        return .loaded(quotaData)
    }

    private static func bootstrapFromHistory() -> QuotaData? {
        guard let entry = HistoryStore.lastEntry() else { return nil }
        return QuotaData(
            fiveHour: QuotaWindow(utilization: entry.fiveHourUtil, resetsAt: entry.fiveHourResetsAt),
            sevenDay: QuotaWindow(utilization: entry.sevenDayUtil, resetsAt: entry.sevenDayResetsAt),
            fetchedAt: entry.ts
        )
    }

    private func mapResponse(_ api: APIQuotaResponse) -> QuotaData {
        // Prefer the new limits[] array: session -> 5h, the *binding* weekly -> 7d.
        if let limits = api.limits, !limits.isEmpty {
            let session = limits.first { $0.group == "session" }
            let weekly = bindingWeekly(from: limits.filter { $0.group == "weekly" })
            return QuotaData(
                fiveHour: session.map(mapLimit) ?? mapWindow(api.fiveHour),
                sevenDay: weekly.map(mapLimit) ?? mapWindow(api.sevenDay),
                fetchedAt: Date()
            )
        }
        // Fallback: legacy two-field response (also the path if limits[] is dropped/malformed).
        return QuotaData(
            fiveHour: mapWindow(api.fiveHour),
            sevenDay: mapWindow(api.sevenDay),
            fetchedAt: Date()
        )
    }

    /// The weekly limit that bites first = worst by utilization, with hysteresis so the shown
    /// number/label doesn't flicker between weekly_all and weekly_scoped as they converge.
    private func bindingWeekly(from weekly: [APILimit]) -> APILimit? {
        guard let challenger = weekly.max(by: { $0.percent < $1.percent }) else { return nil }
        if let incumbentKind = bindingWeeklyKind,
           let incumbent = weekly.first(where: { $0.kind == incumbentKind }),
           incumbent.kind != challenger.kind,
           challenger.percent <= incumbent.percent + Self.bindingHysteresis {
            return incumbent   // challenger hasn't cleared the margin — hold steady
        }
        bindingWeeklyKind = challenger.kind
        return challenger
    }

    private func mapLimit(_ limit: APILimit) -> QuotaWindow {
        let date = limit.resetsAt.flatMap { Self.isoFormatter.date(from: $0) } ?? Date()
        // Annotate only the per-model (scoped) weekly, so the 7d header can read "7d · Fable".
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
