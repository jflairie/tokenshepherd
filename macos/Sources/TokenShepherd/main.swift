import AppKit
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    let quotaService = QuotaService()
    let notificationService = NotificationService()
    private var cancellables = Set<AnyCancellable>()
    private var cachedTokenSummary: TokenSummary?
    private var statsCacheTimer: Timer?
    private var iconSheepTint: NSColor?

    private var contentItem: NSMenuItem!
    private var detailsToggleItem: NSMenuItem!
    private var detailsContentItem: NSMenuItem!
    private var footerItem: NSMenuItem!
    private var detailsVisible = false

    // Cache latest quota data for details updates
    private var latestQuota: QuotaData?
    private var latestFiveHourPace: PaceInfo?
    private var latestSevenDayPace: PaceInfo?
    private var latestTrend: TrendInfo?

    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem.button else {
            NSLog("[TokenShepherd] ERROR: no status item button")
            return
        }

        button.image = StatusBarIcon.icon(for: .loading).image

        let menu = NSMenu()
        menu.delegate = self

        // Hero content
        contentItem = NSMenuItem()
        menu.addItem(contentItem)

        // Details toggle (▶ Details)
        detailsToggleItem = NSMenuItem()
        menu.addItem(detailsToggleItem)

        // Details content (hidden by default)
        detailsContentItem = NSMenuItem()
        detailsContentItem.isHidden = true
        menu.addItem(detailsContentItem)

        menu.addItem(NSMenuItem.separator())

        // Actions footer
        footerItem = NSMenuItem()
        updateFooter(fetchedAt: nil)
        menu.addItem(footerItem)

        // Hidden items for keyboard shortcuts
        let copyItem = NSMenuItem(title: "Copy", action: #selector(copyStatus), keyEquivalent: "c")
        copyItem.target = self
        copyItem.isHidden = true
        copyItem.allowsKeyEquivalentWhenHidden = true
        menu.addItem(copyItem)

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
        updateDetailsToggle()

        notificationService.requestPermission()

        quotaService.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateUI(state)
                self?.updateIcon(state)
                self?.notificationService.evaluate(state: state)
            }
            .store(in: &cancellables)

        quotaService.startBackgroundRefresh()

        // Housekeeping
        HistoryStore.prune()

        // Load token summary from Claude Code stats
        cachedTokenSummary = StatsCache.tokenSummary()
        statsCacheTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            self?.cachedTokenSummary = StatsCache.tokenSummary()
        }

        NSLog("[TokenShepherd] Ready")
    }

    func menuWillOpen(_ menu: NSMenu) {
        quotaService.refresh()
    }

    @objc func refresh() {
        quotaService.refresh()
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }

    @objc func copyStatus() {
        guard case .loaded(let quota) = quotaService.state else { return }
        let binding = quota.bindingWindow
        let isFiveHour = quota.fiveHour.utilization >= quota.sevenDay.utilization
        let nonBinding = isFiveHour ? quota.sevenDay : quota.fiveHour

        let bindingPart: String
        if binding.isLocked {
            bindingPart = "Locked \u{00B7} back at \(formatTime(binding.resetsAt))"
        } else {
            bindingPart = "\(Int(binding.utilization * 100))% \u{00B7} resets \(formatTime(binding.resetsAt))"
        }

        let nonBindingPart = "\(Int(nonBinding.utilization * 100))% \u{00B7} resets \(formatTime(nonBinding.resetsAt))"

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("\(bindingPart) | \(nonBindingPart)", forType: .string)
    }

    @objc func openDashboard() {
        NSWorkspace.shared.open(URL(string: "https://claude.ai/settings")!)
    }

    // MARK: - Details Toggle

    private func toggleDetails() {
        detailsVisible.toggle()
        updateDetailsToggle()
        detailsContentItem.isHidden = !detailsVisible
        if detailsVisible {
            updateDetailsContent()
        }
    }

    private func updateDetailsToggle() {
        let toggleView = NSHostingView(rootView: DetailsToggleView(
            expanded: detailsVisible,
            onToggle: { [weak self] in self?.toggleDetails() }
        ))
        toggleView.frame.size = toggleView.fittingSize
        detailsToggleItem.view = toggleView
    }

    private func updateDetailsContent() {
        guard let quota = latestQuota else { return }
        let detailsView = NSHostingView(rootView: DetailsContentView(
            quota: quota,
            fiveHourPace: latestFiveHourPace,
            sevenDayPace: latestSevenDayPace,
            tokenSummary: cachedTokenSummary,
            trend: latestTrend
        ))
        detailsView.frame.size = detailsView.fittingSize
        detailsContentItem.view = detailsView
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
            .frame(width: 260)
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
            updateFooter(fetchedAt: nil)

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
                    Text("\u{2318}R to retry")
                        .font(.system(.caption2))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(width: 260, alignment: .leading)
            )
            errorView.frame.size = errorView.fittingSize
            contentItem.view = errorView
            updateFooter(fetchedAt: nil)

        case .loaded(let quota):
            let fiveHourPace = PaceCalculator.pace(for: quota.fiveHour, windowDuration: PaceCalculator.fiveHourDuration)
            let sevenDayPace = PaceCalculator.pace(for: quota.sevenDay, windowDuration: PaceCalculator.sevenDayDuration)

            // Determine binding window and read history
            let isFiveHour = quota.fiveHour.utilization >= quota.sevenDay.utilization
            let bindingWindow = isFiveHour ? quota.fiveHour : quota.sevenDay
            let windowEntries = HistoryStore.readForWindow(
                resetsAt: bindingWindow.resetsAt,
                isFiveHour: isFiveHour
            )

            let trend = TrendCalculator.trend(entries: windowEntries, isFiveHour: isFiveHour)

            let windowDuration = isFiveHour ? PaceCalculator.fiveHourDuration : PaceCalculator.sevenDayDuration
            let windowStart = bindingWindow.resetsAt.addingTimeInterval(-windowDuration)
            let sparklineData = TrendCalculator.sparklineBuckets(
                entries: windowEntries,
                isFiveHour: isFiveHour,
                windowStart: windowStart,
                windowEnd: Date()
            )

            // Projection-driven sheep tint — only when util < 0.7 (higher util uses suffix)
            let bindingPace = isFiveHour ? fiveHourPace : sevenDayPace
            let paceWarning = bindingPace?.showWarning ?? false
            var projectedUtil: Double? = nil
            let timeToReset = bindingWindow.resetsAt.timeIntervalSinceNow
            if timeToReset > 0, bindingWindow.utilization > 0.01,
               let t = trend, abs(t.velocityPerHour) > 0.001 {
                let hoursRemaining = timeToReset / 3600
                projectedUtil = max(min(bindingWindow.utilization + (t.velocityPerHour * hoursRemaining), 1.0), bindingWindow.utilization)
            }
            if bindingWindow.utilization < 0.7 {
                if paceWarning || (projectedUtil ?? 0) >= 0.7 {
                    iconSheepTint = .systemOrange
                } else {
                    iconSheepTint = nil
                }
            } else {
                iconSheepTint = nil  // suffix handles >= 0.7
            }

            // Cache for details
            latestQuota = quota
            latestFiveHourPace = fiveHourPace
            latestSevenDayPace = sevenDayPace
            latestTrend = trend

            let heroView = NSHostingView(rootView: BindingView(
                quota: quota,
                fiveHourPace: fiveHourPace,
                sevenDayPace: sevenDayPace,
                trend: trend,
                sparklineData: sparklineData,
                tokenSummary: cachedTokenSummary
            ))
            heroView.frame.size = heroView.fittingSize
            contentItem.view = heroView

            // Refresh details content if visible
            if detailsVisible {
                updateDetailsContent()
            }

            updateFooter(fetchedAt: quota.fetchedAt)
        }
    }

    private func updateFooter(fetchedAt: Date?) {
        let footerView = NSHostingView(rootView: ActionsFooterView(
            onRefresh: { [weak self] in
                self?.refresh()
            },
            onCopy: { [weak self] in
                self?.copyStatus()
                self?.statusItem.menu?.cancelTracking()
            },
            onDashboard: { [weak self] in
                self?.openDashboard()
                self?.statusItem.menu?.cancelTracking()
            },
            fetchedAt: fetchedAt
        ))
        footerView.frame.size = footerView.fittingSize
        footerItem.view = footerView
    }

    private func updateIcon(_ state: QuotaState) {
        guard let button = statusItem.button else { return }
        let icon = StatusBarIcon.icon(for: state, sheepTint: iconSheepTint)
        button.image = icon.image
        button.title = ""
    }
}

// MARK: - Actions Footer View

struct ActionsFooterView: View {
    let onRefresh: () -> Void
    let onCopy: () -> Void
    let onDashboard: () -> Void
    let fetchedAt: Date?

    var body: some View {
        HStack(spacing: 6) {
            FooterIconButton(systemImage: "arrow.clockwise", action: onRefresh)
            FooterButton(title: "Copy status", action: onCopy)
            FooterButton(title: "Dashboard \u{2197}", action: onDashboard)
            Spacer()
            if let fetchedAt {
                Text(fetchedAt, style: .relative)
                    .font(.system(.caption2))
                    .foregroundStyle(.quaternary)
                    .monospacedDigit()
            }
        }
        .frame(width: 232)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }
}

struct FooterIconButton: View {
    let systemImage: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(.caption))
            .foregroundStyle(isHovered ? .primary : .tertiary)
            .frame(width: 22, height: 22)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovered ? Color.primary.opacity(0.06) : .clear)
            )
            .onHover { isHovered = $0 }
            .onTapGesture { action() }
    }
}

struct FooterButton: View {
    let title: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Text(title)
            .font(.system(.caption))
            .foregroundStyle(isHovered ? .primary : .tertiary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovered ? Color.primary.opacity(0.06) : .clear)
            )
            .onHover { isHovered = $0 }
            .onTapGesture { action() }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate

delegate.setupStatusItem()
delegate.quotaService.refresh()

app.run()
