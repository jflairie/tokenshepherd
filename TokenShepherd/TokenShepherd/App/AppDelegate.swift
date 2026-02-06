import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var floatingWindow: FloatingWindow?
    private var dataService: DataService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize data service
        dataService = DataService()

        // Create and show floating window
        floatingWindow = FloatingWindow(dataService: dataService!)
        floatingWindow?.show()

        // Start monitoring
        dataService?.startMonitoring()
    }

    func applicationWillTerminate(_ notification: Notification) {
        dataService?.stopMonitoring()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}

// MARK: - Floating Window

class FloatingWindow: NSObject {
    private var window: NSWindow?
    private let dataService: DataService

    private let positionXKey = "floatingWindowPositionX"
    private let positionYKey = "floatingWindowPositionY"

    init(dataService: DataService) {
        self.dataService = dataService
        super.init()
        setupWindow()
    }

    private func setupWindow() {
        let contentView = FloatingWidget(dataService: dataService)

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 200, height: 60)

        window = NSWindow(
            contentRect: hostingView.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        guard let window = window else { return }

        // Floating window configuration
        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]

        window.contentView = hostingView

        // Restore position or use default
        let savedX = UserDefaults.standard.double(forKey: positionXKey)
        let savedY = UserDefaults.standard.double(forKey: positionYKey)

        if savedX != 0 || savedY != 0 {
            window.setFrameOrigin(NSPoint(x: savedX, y: savedY))
        } else {
            // Default position: top-right corner
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                let x = screenFrame.maxX - hostingView.frame.width - 20
                let y = screenFrame.maxY - hostingView.frame.height - 20
                window.setFrameOrigin(NSPoint(x: x, y: y))
            }
        }

        // Track window movement
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove),
            name: NSWindow.didMoveNotification,
            object: window
        )
    }

    func show() {
        window?.makeKeyAndOrderFront(nil)
    }

    @objc private func windowDidMove(_ notification: Notification) {
        guard let window = window else { return }
        let origin = window.frame.origin
        UserDefaults.standard.set(origin.x, forKey: positionXKey)
        UserDefaults.standard.set(origin.y, forKey: positionYKey)
    }
}
