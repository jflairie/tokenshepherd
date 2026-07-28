import AppKit
import SwiftUI
import Combine
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let quotaService = QuotaService()

    private var cancellables = Set<AnyCancellable>()
    private var cachedTokenSummary: TokenSummary?
    private var statsCacheTimer: Timer?
    private var activityToken: NSObjectProtocol?          // holds off App Nap for the app's lifetime
    private var latestState: ShepherdState = .calm

    private var contentItem: NSMenuItem!
    private var footerItem: NSMenuItem!

    func registerLoginItem() {
        let service = SMAppService.mainApp
        if service.status != .enabled {
            do {
                try service.register()
                NSLog("[TokenShepherd] Registered as login item")
            } catch {
                NSLog("[TokenShepherd] Failed to register as login item: \(error)")
            }
        }
    }

    func setupStatusItem() {
        // Prevent App Nap from suspending the 60s poll timer when the app is idle/hidden
        // (that left the sheep stuck on stale data until you opened the menu). The
        // "AllowingIdleSystemSleep" variant still lets the Mac sleep normally.
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: "Continuously monitor Claude Code quota"
        )

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem.button else {
            NSLog("[TokenShepherd] ERROR: no status item button")
            return
        }

        button.image = StatusBarIcon.icon(for: .calm, blind: true)   // unknown until first sync

        let menu = NSMenu()
        menu.delegate = self

        // Hero content
        contentItem = NSMenuItem()
        menu.addItem(contentItem)

        menu.addItem(NSMenuItem.separator())

        // Actions footer
        footerItem = NSMenuItem()
        updateFooter(dataAt: nil)
        menu.addItem(footerItem)

        // Hidden items for keyboard shortcuts
        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refresh), keyEquivalent: "r")
        refreshItem.target = self
        refreshItem.isHidden = true
        refreshItem.allowsKeyEquivalentWhenHidden = true
        menu.addItem(refreshItem)

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        quitItem.isHidden = true
        quitItem.allowsKeyEquivalentWhenHidden = true
        menu.addItem(quitItem)

        statusItem.menu = menu

        setLoadingState()

        quotaService.$state
            .combineLatest(quotaService.$health)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state, _ in
                self?.updateUI(state)
            }
            .store(in: &cancellables)

        quotaService.startBackgroundRefresh()

        // Re-sync immediately on wake — the 60s poll timer doesn't fire while asleep,
        // so without this the first post-wake reading can be minutes stale.
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        // Housekeeping
        HistoryStore.prune()

        // Load token summary from Claude Code stats
        cachedTokenSummary = StatsCache.tokenSummary()
        statsCacheTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            self?.cachedTokenSummary = StatsCache.tokenSummary()
        }

        quotaService.refresh()
        NSLog("[TokenShepherd] Ready")
    }

    func menuWillOpen(_ menu: NSMenu) {
        quotaService.refresh(force: true)
    }

    @objc private func refresh() {
        quotaService.refresh(force: true)
    }

    @objc private func handleWake() {
        // Sleep can leave the repeating timer desynced — reschedule it, then sync now.
        quotaService.startBackgroundRefresh()
        quotaService.refresh(force: true)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - UI Updates

    private func setLoadingState() {
        let loadingView = NSHostingView(rootView:
            HStack {
                ProgressView()
                    .controlSize(.small)
                Text("Loading...")
                    .font(.system(.caption))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 280)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        )
        loadingView.frame.size = loadingView.fittingSize
        contentItem.view = loadingView
    }

    private func updateUI(_ state: QuotaState) {
        switch state {
        case .loading:
            setLoadingState()

        case .idle:
            latestState = .idle
            let idleView = NSHostingView(rootView:
                VStack(alignment: .leading, spacing: 4) {
                    Text("Waiting for Claude")
                        .font(.system(.body, weight: .medium))
                        .foregroundStyle(.primary)
                    Text("Use Claude Code to connect")
                        .font(.system(.caption))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(width: 280, alignment: .leading)
            )
            idleView.frame.size = idleView.fittingSize
            contentItem.view = idleView

        case .error(let message):
            let errorView = NSHostingView(rootView:
                VStack(alignment: .leading, spacing: 4) {
                    Label("Error", systemImage: "exclamationmark.triangle")
                        .font(.system(.body, weight: .medium))
                        .foregroundStyle(.red)
                    Text(message)
                        .font(.system(.caption))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(width: 280, alignment: .leading)
            )
            errorView.frame.size = errorView.fittingSize
            contentItem.view = errorView

        case .loaded(let quota):
            let fiveHourPace = PaceCalculator.pace(for: quota.fiveHour, windowDuration: PaceCalculator.fiveHourDuration)
            let sevenDayPace = PaceCalculator.pace(for: quota.sevenDay, windowDuration: PaceCalculator.sevenDayDuration)

            // 5h: rate + trend (session-level, recent velocity matters)
            let fhEntries = HistoryStore.readForWindow(resetsAt: quota.fiveHour.resetsAt, isFiveHour: true)
            let fhTrend = TrendCalculator.trend(entries: fhEntries, isFiveHour: true)
            let fhProjection = projectAtReset(window: quota.fiveHour, windowDuration: PaceCalculator.fiveHourDuration, trend: fhTrend)

            // 7d: hourly usage profile (time-of-day aware), rate-based fallback
            let sdProjection = projectSevenDay(window: quota.sevenDay)

            // Per-window state (independent coloring)
            let fhState = ShepherdState.from(window: quota.fiveHour, pace: fiveHourPace, projectedAtReset: fhProjection)
            let sdState = ShepherdState.from(window: quota.sevenDay, pace: sevenDayPace, projectedAtReset: sdProjection)

            // Icon = worst window. sdState carries the *binding* weekly (worst of
            // weekly_all / weekly_scoped, chosen in QuotaService.bindingWeekly), so this
            // max already reflects the worst of all three limits — do NOT add a third here.
            latestState = fhState.severity >= sdState.severity ? fhState : sdState

            let heroView = NSHostingView(rootView: BindingView(
                quota: quota,
                fhState: fhState,
                sdState: sdState,
                fhProjection: fhProjection,
                sdProjection: sdProjection,
                tokenSummary: cachedTokenSummary
            ))
            heroView.frame.size = heroView.fittingSize
            contentItem.view = heroView
        }

        // Icon and footer always reflect the current data AND fetch health: when recent
        // fetches failed (or we've never synced) the sheep goes "blind" and the footer
        // states the real reason, instead of asserting the stale numbers are current.
        updateIcon()
        let dataAt: Date? = { if case .loaded(let quota) = state { return quota.fetchedAt } else { return nil } }()
        updateFooter(dataAt: dataAt)
    }

    private func updateFooter(dataAt: Date?) {
        let footerView = NSHostingView(rootView: FooterView(
            dataAt: dataAt,
            health: quotaService.health
        ))
        footerView.frame.size = footerView.fittingSize
        footerItem.view = footerView
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        button.image = StatusBarIcon.icon(for: latestState, blind: quotaService.health.isBlind)
        button.title = ""
    }

    // MARK: - Projection (5h)

    /// 5h window: rate-based + recent trend. Session-level, reactive.
    private func projectAtReset(
        window: QuotaWindow, windowDuration: TimeInterval,
        trend: TrendInfo?
    ) -> Double? {
        let timeToReset = window.resetsAt.timeIntervalSinceNow
        guard timeToReset > 0, window.utilization > 0.01 else { return nil }
        var projection: Double? = nil
        // Rate-based (whole window average)
        let elapsed = windowDuration - timeToReset
        if elapsed > 60 {
            projection = (window.utilization / elapsed) * windowDuration
        }
        // Trend-based: recent velocity, guardrailed
        if let t = trend, abs(t.velocityPerHour) > 0.001 {
            let hoursRemaining = timeToReset / 3600
            let spanHours = t.spanSeconds / 3600
            let effectiveHours = min(hoursRemaining, spanHours * 4.0)
            let trendProjected = max(
                window.utilization + (t.velocityPerHour * effectiveHours),
                window.utilization
            )
            if t.spanSeconds < 900 && trendProjected >= 0.9 {
                let capped = min(trendProjected, max(projection ?? 0, 0.89))
                projection = max(projection ?? 0, capped)
            } else {
                projection = max(projection ?? 0, trendProjected)
            }
        }
        return projection
    }

    // MARK: - Projection (7d)

    /// 7d window: hourly usage profile (time-of-day aware).
    /// Falls back to rate-based if insufficient history for a profile.
    private func projectSevenDay(window: QuotaWindow) -> Double? {
        let timeToReset = window.resetsAt.timeIntervalSinceNow
        guard timeToReset > 0, window.utilization > 0.01 else { return nil }

        // Profile-based: project using historical consumption by hour-of-day
        if let profileProjection = UsageProfiler.projectAtReset(
            currentUtil: window.utilization,
            resetsAt: window.resetsAt,
            isFiveHour: false
        ) {
            return profileProjection
        }

        // Fallback: rate-based (whole window average) when history is thin
        let elapsed = PaceCalculator.sevenDayDuration - timeToReset
        guard elapsed > 60 else { return nil }
        return (window.utilization / elapsed) * PaceCalculator.sevenDayDuration
    }
}

// MARK: - Footer

struct FooterView: View {
    let dataAt: Date?          // fetchedAt of the data currently on screen (nil if none)
    let health: FetchHealth

    var body: some View {
        HStack(spacing: 4) {
            #if DEBUG
            Text("dev ·")
                .font(.system(size: 10))
                .foregroundStyle(.quaternary)
            #endif
            if health.isBlind, health.lastFailureReason == .unreachable {
                // Stale because we can't reach the API — state the real cause, and break
                // the quaternary tone: a staleness alert can't be the faintest pixel.
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
                Text(unreachableStatus)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            } else if let dataAt {
                Text(syncedStatus(dataAt))
                    .font(.system(size: 10))
                    .foregroundStyle(.quaternary)
            }
            Spacer()
        }
        .frame(width: 252)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    private var unreachableStatus: String {
        guard let dataAt else { return "Can't reach Anthropic" }
        return "Can't reach Anthropic · last synced \(age(dataAt))"
    }

    private func syncedStatus(_ date: Date) -> String {
        Int(Date().timeIntervalSince(date)) < 90 ? "Synced" : "Synced \(age(date))"
    }

    private func age(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        return hours < 24 ? "\(hours)h ago" : "\(hours / 24)d ago"
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate

delegate.registerLoginItem()
delegate.setupStatusItem()

app.run()
