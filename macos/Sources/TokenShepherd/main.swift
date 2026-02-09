import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    let quotaService = QuotaService()

    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem.button else {
            NSLog("[TokenShepherd] ERROR: no status item button")
            return
        }

        button.title = "🐑"

        let menu = NSMenu()

        let quotaItem = NSMenuItem()
        let hostingView = NSHostingView(rootView: QuotaView(service: quotaService))
        hostingView.frame = NSRect(x: 0, y: 0, width: 280, height: 200)
        quotaItem.view = hostingView
        menu.addItem(quotaItem)

        menu.addItem(NSMenuItem.separator())

        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refresh), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit TokenShepherd", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        menu.delegate = self

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


}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate

// Create status item immediately — don't rely on delegate callback
delegate.setupStatusItem()
delegate.quotaService.refresh()

app.run()
