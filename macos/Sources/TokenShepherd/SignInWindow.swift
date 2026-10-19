import AppKit
import SwiftUI

/// Drives TokenShepherd's own OAuth sign-in via the RFC 8252 loopback flow: opens the browser
/// to Anthropic's consent page, catches the redirect on a local listener, and exchanges the
/// code — no copy-paste. A small status window gives the user feedback (waiting → connected)
/// and a clear recovery path if anything fails.
@MainActor
final class SignInController: NSObject, ObservableObject, NSWindowDelegate {
    enum Phase: Equatable {
        case waiting        // browser open, awaiting approval
        case connecting     // code received, exchanging
        case success
        case failed(String)
    }

    @Published var phase: Phase = .waiting

    private var window: NSWindow?
    private var server: LoopbackServer?
    private var pkce: PKCE?
    private var state: String?
    private var timeoutTask: Task<Void, Never>?
    private var onComplete: (() -> Void)?

    /// Start (or resume) the sign-in flow. `onComplete` fires after credentials are stored.
    func start(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete

        // Resume, don't restart: a live window already has a listener + matching pkce/state.
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        beginFlow()
        presentWindow()
    }

    private func beginFlow() {
        let pkce = AuthService.generatePKCE()
        let state = AuthService.randomState()
        self.pkce = pkce
        self.state = state
        self.phase = .waiting

        let server = LoopbackServer(port: AuthService.callbackPort) { [weak self] path, query in
            // NWListener callbacks run on the main queue; assert that to reach @MainActor state.
            MainActor.assumeIsolated { self?.handleCallback(path: path, query: query) ?? "OK" }
        }
        do {
            try server.start()
            self.server = server
        } catch {
            phase = .failed("Couldn't open the local sign-in listener on port \(AuthService.callbackPort). "
                            + "Another app may be using it. (\(error.localizedDescription))")
            return
        }

        NSWorkspace.shared.open(AuthService.authorizeURL(challenge: pkce.challenge, state: state))

        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300 * 1_000_000_000)   // 5 min
            guard let self else { return }
            if self.phase == .waiting {
                self.phase = .failed("Timed out waiting for browser approval.")
                self.teardownServer()
            }
        }
    }

    func retry() {
        teardownServer()
        beginFlow()
    }

    func cancel() { close() }

    // MARK: - Callback

    /// Handle the browser redirect. Returns the HTML page shown in the browser. The token
    /// exchange runs asynchronously afterward; the browser gets a neutral "done" page and the
    /// real success/failure surfaces in this app's window.
    private func handleCallback(path: String, query: [String: String]) -> String {
        guard path == "/callback" else { return "Not found" }

        if let err = query["error"] {
            phase = .failed("Authorization was denied (\(err)).")
            teardownServer()
            return Self.browserPage(title: "Sign-in cancelled", body: "You can close this tab.")
        }
        guard let code = query["code"], let returnedState = query["state"],
              let expected = state, returnedState == expected else {
            phase = .failed(AuthError.stateMismatch.localizedDescription)
            teardownServer()
            return Self.browserPage(title: "Sign-in failed", body: "Please try again from TokenShepherd.")
        }

        phase = .connecting
        let verifier = pkce?.verifier ?? ""
        Task { [weak self] in
            guard let self else { return }
            do {
                let creds = try await AuthService.exchangeCode(code: code, state: expected, verifier: verifier)
                try AuthStore.write(creds)
                self.phase = .success
                self.onComplete?()
                try? await Task.sleep(nanoseconds: 1_600_000_000)
                self.close()
            } catch {
                self.phase = .failed(error.localizedDescription)
            }
            self.teardownServer()
        }
        return Self.browserPage(title: "Authorized", body: "You can close this tab and return to TokenShepherd.")
    }

    private static func browserPage(title: String, body: String) -> String {
        """
        <!DOCTYPE html><html><head><meta charset="utf-8"><title>\(title)</title></head>
        <body style="font-family:-apple-system,system-ui;text-align:center;padding:60px;color:#333">
        <h2>\(title)</h2><p>\(body)</p></body></html>
        """
    }

    // MARK: - Window

    private func presentWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Connect TokenShepherd"
        window.contentViewController = NSHostingController(rootView: SignInView(controller: self))
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.center()
        window.level = .floating
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func close() {
        teardownServer()
        window?.close()
        window = nil
    }

    private func teardownServer() {
        timeoutTask?.cancel()
        timeoutTask = nil
        server?.stop()
        server = nil
    }

    func windowWillClose(_ notification: Notification) {
        teardownServer()
        window = nil
    }
}

// MARK: - View

struct SignInView: View {
    @ObservedObject var controller: SignInController

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch controller.phase {
            case .waiting, .connecting: progressView
            case .success: successView
            case .failed(let message): failedView(message)
            }
        }
        .padding(24)
        .frame(width: 420, alignment: .leading)
    }

    private var progressView: some View {
        HStack(spacing: 14) {
            ProgressView().controlSize(.small)
            VStack(alignment: .leading, spacing: 4) {
                Text(controller.phase == .connecting ? "Connecting…" : "Waiting for approval")
                    .font(.system(.title3, weight: .semibold))
                Text(controller.phase == .connecting
                     ? "Finishing sign-in."
                     : "Approve access in the browser window that just opened. This window updates automatically.")
                    .font(.system(.callout))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .overlay(alignment: .bottomTrailing) {
            Button("Cancel") { controller.cancel() }
                .keyboardShortcut(.cancelAction)
                .offset(y: 36)
        }
    }

    private var successView: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 4) {
                Text("Connected")
                    .font(.system(.title3, weight: .semibold))
                Text("Quota now updates on its own — no terminal needed.")
                    .font(.system(.callout))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func failedView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sign-in didn't complete")
                        .font(.system(.title3, weight: .semibold))
                    Text(message)
                        .font(.system(.callout))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack {
                Spacer()
                Button("Cancel") { controller.cancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Try again") { controller.retry() }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }
}
