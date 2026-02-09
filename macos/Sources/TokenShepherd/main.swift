import AppKit
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    let quotaService = QuotaService()
    let notificationService = NotificationService()
    private var cancellables = Set<AnyCancellable>()

    private var contentItem: NSMenuItem!
    private var footerItem: NSMenuItem!

    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem.button else {
            NSLog("[TokenShepherd] ERROR: no status item button")
            return
        }

        button.title = "\u{1F411}"

        let menu = NSMenu()
        menu.delegate = self

        // Content (hero + everything)
        contentItem = NSMenuItem()
        menu.addItem(contentItem)

        menu.addItem(NSMenuItem.separator())

        // Footer: Refresh + Quit on one line
        footerItem = NSMenuItem()
        let footerView = NSHostingView(rootView: FooterView())
        footerView.frame.size = footerView.fittingSize
        footerItem.view = footerView
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

            let heroView = NSHostingView(rootView: BindingView(
                quota: quota,
                fiveHourPace: fiveHourPace,
                sevenDayPace: sevenDayPace
            ))
            heroView.frame.size = heroView.fittingSize
            contentItem.view = heroView
        }
    }

    private func updateIcon(_ state: QuotaState) {
        guard let button = statusItem.button else { return }
        let icon = StatusBarIcon.icon(for: state)
        button.attributedTitle = icon.attributedTitle
    }
}

// MARK: - Footer View

struct FooterView: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("Refresh  \u{2318}R")
            Spacer()
            Text("Quit  \u{2318}Q")
        }
        .font(.system(.caption2))
        .foregroundStyle(.tertiary)
        .frame(width: 232)
        .padding(.horizontal, 14)
        .padding(.vertical, 3)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate

delegate.setupStatusItem()
delegate.quotaService.refresh()

app.run()
