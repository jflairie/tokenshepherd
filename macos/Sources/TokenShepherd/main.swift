import AppKit
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    let quotaService = QuotaService()
    private var cancellables = Set<AnyCancellable>()

    // Mutable menu item references
    private var fiveHourItem: NSMenuItem!
    private var sevenDayItem: NSMenuItem!
    private var fiveHourSparklineItem: NSMenuItem!
    private var sevenDaySparklineItem: NSMenuItem!
    private var detailToggleItem: NSMenuItem!
    private var detailItem: NSMenuItem!
    private var detailsVisible = false

    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem.button else {
            NSLog("[TokenShepherd] ERROR: no status item button")
            return
        }

        button.title = "\u{1F411}"

        let menu = NSMenu()
        menu.delegate = self

        // 5-Hour window row
        fiveHourItem = NSMenuItem()
        menu.addItem(fiveHourItem)

        // 7-Day window row
        sevenDayItem = NSMenuItem()
        menu.addItem(sevenDayItem)

        menu.addItem(NSMenuItem.separator())

        // Details toggle
        detailToggleItem = NSMenuItem(title: "Show Details", action: #selector(toggleDetails), keyEquivalent: "")
        detailToggleItem.target = self
        menu.addItem(detailToggleItem)

        // Detail section (hidden by default)
        detailItem = NSMenuItem()
        detailItem.isHidden = true
        menu.addItem(detailItem)

        menu.addItem(NSMenuItem.separator())

        // Refresh
        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refresh), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit TokenShepherd", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu

        // Set up sparkline submenus
        setupSparklineSubmenus()

        // Show loading state
        setLoadingState()

        // Subscribe to state changes
        quotaService.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateUI(state)
                self?.updateIcon(state)
            }
            .store(in: &cancellables)

        NSLog("[TokenShepherd] Ready")
    }

    func menuWillOpen(_ menu: NSMenu) {
        quotaService.refresh()
    }

    // MARK: - Actions

    @objc func refresh() {
        quotaService.refresh()
    }

    @objc func toggleDetails() {
        detailsVisible.toggle()
        detailItem.isHidden = !detailsVisible
        detailToggleItem.title = detailsVisible ? "Hide Details" : "Show Details"
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Sparkline Submenus

    private func setupSparklineSubmenus() {
        let fiveHourSubmenu = NSMenu()
        fiveHourSparklineItem = NSMenuItem()
        fiveHourSubmenu.addItem(fiveHourSparklineItem)
        fiveHourItem.submenu = fiveHourSubmenu

        let sevenDaySubmenu = NSMenu()
        sevenDaySparklineItem = NSMenuItem()
        sevenDaySubmenu.addItem(sevenDaySparklineItem)
        sevenDayItem.submenu = sevenDaySubmenu
    }

    // MARK: - UI Updates

    private func setLoadingState() {
        let loadingView = NSHostingView(rootView:
            HStack {
                ProgressView()
                    .controlSize(.small)
                Text("Loading quota...")
                    .font(.system(.body))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 260)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        )
        loadingView.frame.size = loadingView.fittingSize
        fiveHourItem.view = loadingView
        sevenDayItem.isHidden = true
        detailToggleItem.isHidden = true
        detailItem.isHidden = true
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
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(width: 260, alignment: .leading)
            )
            errorView.frame.size = errorView.fittingSize
            fiveHourItem.view = errorView
            fiveHourItem.submenu = nil
            sevenDayItem.isHidden = true
            detailToggleItem.isHidden = true
            detailItem.isHidden = true

        case .loaded(let quota):
            // 5-Hour row
            let fiveHourPace = PaceCalculator.pace(for: quota.fiveHour, windowDuration: PaceCalculator.fiveHourDuration)
            let fiveHourRowView = NSHostingView(rootView: WindowRowView(
                label: "5-Hour",
                window: quota.fiveHour,
                pace: fiveHourPace
            ))
            fiveHourRowView.frame.size = fiveHourRowView.fittingSize
            fiveHourItem.view = fiveHourRowView

            // Re-attach sparkline submenu (view replacement clears it)
            setupSparklineSubmenus()

            // 7-Day row
            let sevenDayPace = PaceCalculator.pace(for: quota.sevenDay, windowDuration: PaceCalculator.sevenDayDuration)
            let sevenDayRowView = NSHostingView(rootView: WindowRowView(
                label: "7-Day",
                window: quota.sevenDay,
                pace: sevenDayPace
            ))
            sevenDayRowView.frame.size = sevenDayRowView.fittingSize
            sevenDayItem.view = sevenDayRowView
            sevenDayItem.isHidden = false

            // Sparklines
            updateSparklines()

            // Detail section
            let detailView = NSHostingView(rootView: DetailView(
                quota: quota,
                credentials: quotaService.lastCredentials
            ))
            detailView.frame.size = detailView.fittingSize
            detailItem.view = detailView
            detailItem.isHidden = !detailsVisible
            detailToggleItem.isHidden = false
        }
    }

    private func updateSparklines() {
        // 5-hour: last 24 hours of history
        let last24h = HistoryStore.read(since: Date().addingTimeInterval(-86_400))
        let fiveHourSparkline = NSHostingView(rootView: SparklineView(
            entries: last24h,
            keyPath: \.fiveHourUtil,
            periodLabel: "Last 24 hours"
        ))
        fiveHourSparkline.frame.size = fiveHourSparkline.fittingSize
        fiveHourSparklineItem.view = fiveHourSparkline

        // 7-day: last 7 days of history
        let last7d = HistoryStore.read(since: Date().addingTimeInterval(-604_800))
        let sevenDaySparkline = NSHostingView(rootView: SparklineView(
            entries: last7d,
            keyPath: \.sevenDayUtil,
            periodLabel: "Last 7 days"
        ))
        sevenDaySparkline.frame.size = sevenDaySparkline.fittingSize
        sevenDaySparklineItem.view = sevenDaySparkline
    }

    private func updateIcon(_ state: QuotaState) {
        guard let button = statusItem.button else { return }
        let icon = StatusBarIcon.icon(for: state)
        button.attributedTitle = icon.attributedTitle
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate

delegate.setupStatusItem()
delegate.quotaService.refresh()

app.run()
