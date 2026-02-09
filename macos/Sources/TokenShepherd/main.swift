import AppKit
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    let quotaService = QuotaService()
    let notificationService = NotificationService()
    private var cancellables = Set<AnyCancellable>()
    private var cachedDominantModel: String?
    private var statsCacheTimer: Timer?
    private var iconProjectedUtilization: Double?

    private var contentItem: NSMenuItem!
    private var footerItem: NSMenuItem!

    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem.button else {
            NSLog("[TokenShepherd] ERROR: no status item button")
            return
        }

        button.image = StatusBarIcon.icon(for: .loading).image

        let menu = NSMenu()
        menu.delegate = self

        // Content (hero + everything)
        contentItem = NSMenuItem()
        menu.addItem(contentItem)

        menu.addItem(NSMenuItem.separator())

        // Actions footer (unified custom view)
        footerItem = NSMenuItem()
        let footerView = NSHostingView(rootView: ActionsFooterView(
            onCopy: { [weak self] in
                self?.copyStatus()
                self?.statusItem.menu?.cancelTracking()
            },
            onDashboard: { [weak self] in
                self?.openDashboard()
                self?.statusItem.menu?.cancelTracking()
            }
        ))
        footerView.frame.size = footerView.fittingSize
        footerItem.view = footerView
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

        // Load dominant model from Claude Code stats
        cachedDominantModel = StatsCache.dominantModel()
        statsCacheTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            self?.cachedDominantModel = StatsCache.dominantModel()
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
        let isFiveHour = quota.fiveHour.utilization >= quota.sevenDay.utilization
        let bindingLabel = isFiveHour ? "5-hour" : "7-day"
        let binding = quota.bindingWindow
        let nonBindingLabel = isFiveHour ? "7-day" : "5-hour"
        let nonBinding = isFiveHour ? quota.sevenDay : quota.fiveHour

        var parts = ["\(bindingLabel): \(Int(binding.utilization * 100))%"]
        if !binding.isLocked {
            parts.append("resets in \(binding.resetsInFormatted)")
        }
        parts.append("| \(nonBindingLabel): \(Int(nonBinding.utilization * 100))%")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(parts.joined(separator: " "), forType: .string)
    }

    @objc func openDashboard() {
        NSWorkspace.shared.open(URL(string: "https://claude.ai/settings")!)
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
                windowEnd: bindingWindow.resetsAt
            )

            let windowType = isFiveHour ? "5-hour" : "7-day"
            let lastWindowPeak = WindowSummaryStore.lastSummary(windowType: windowType)?.peakUtilization

            // Compute trajectory warning for icon
            let bindingPace = isFiveHour ? fiveHourPace : sevenDayPace
            let paceWarning = bindingPace?.showWarning ?? false
            var projectedUtil: Double? = nil
            let timeToReset = bindingWindow.resetsAt.timeIntervalSinceNow
            if timeToReset > 0, bindingWindow.utilization > 0.01,
               let t = trend, abs(t.velocityPerHour) > 0.001 {
                let hoursRemaining = timeToReset / 3600
                let p = bindingWindow.utilization + (t.velocityPerHour * hoursRemaining)
                projectedUtil = max(min(p, 1.0), bindingWindow.utilization)
            }
            let trajectoryWarning = projectedUtil.map { $0 >= 0.9 } ?? false
            if bindingWindow.utilization < 0.7 {
                if paceWarning {
                    iconProjectedUtilization = projectedUtil ?? 1.0
                } else if trajectoryWarning {
                    iconProjectedUtilization = projectedUtil
                } else {
                    iconProjectedUtilization = nil
                }
            } else {
                iconProjectedUtilization = nil
            }

            let heroView = NSHostingView(rootView: BindingView(
                quota: quota,
                fiveHourPace: fiveHourPace,
                sevenDayPace: sevenDayPace,
                trend: trend,
                sparklineData: sparklineData,
                dominantModel: cachedDominantModel,
                lastWindowPeak: lastWindowPeak
            ))
            heroView.frame.size = heroView.fittingSize
            contentItem.view = heroView
        }
    }

    private func updateIcon(_ state: QuotaState) {
        guard let button = statusItem.button else { return }
        let icon = StatusBarIcon.icon(for: state, projectedUtilization: iconProjectedUtilization)
        button.image = icon.image
        button.title = ""
    }
}

// MARK: - Actions Footer View

struct ActionsFooterView: View {
    let onCopy: () -> Void
    let onDashboard: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                FooterButton(title: "Copy status", shortcut: "\u{2318}C", action: onCopy)
                Spacer()
                FooterButton(title: "Dashboard", shortcut: nil, action: onDashboard)
            }
            HStack {
                Text("Refresh  \u{2318}R")
                Spacer()
                Text("Quit  \u{2318}Q")
            }
            .font(.system(.caption2))
            .foregroundStyle(.quaternary)
        }
        .frame(width: 232)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }
}

struct FooterButton: View {
    let title: String
    let shortcut: String?
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 3) {
            Text(title)
            if let shortcut {
                Text(shortcut)
                    .foregroundStyle(isHovered ? .tertiary : .quaternary)
            }
        }
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
