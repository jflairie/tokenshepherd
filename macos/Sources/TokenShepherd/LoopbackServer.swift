import Foundation
import Network

/// Minimal single-shot HTTP listener for the OAuth loopback callback.
///
/// Binds ONLY to 127.0.0.1 (via `requiredLocalEndpoint`) so macOS never shows the "accept
/// incoming network connections" firewall prompt — this is a localhost-only socket. It lives
/// just long enough to catch the browser's `GET /callback?code=…&state=…` redirect, hand the
/// query back to the caller, and reply with a small HTML page.
final class LoopbackServer {
    private var listener: NWListener?
    private let port: UInt16
    /// Called on the main queue with the request path and parsed query; returns the HTML to
    /// serve back to the browser.
    private let onRequest: (_ path: String, _ query: [String: String]) -> String

    init(port: UInt16, onRequest: @escaping (_ path: String, _ query: [String: String]) -> String) {
        self.port = port
        self.onRequest = onRequest
    }

    func start() throws {
        let params = NWParameters.tcp
        params.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!)
        params.allowLocalEndpointReuse = true
        let listener = try NWListener(using: params)
        self.listener = listener
        listener.newConnectionHandler = { [weak self] conn in self?.handle(conn) }
        listener.start(queue: .main)
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handle(_ conn: NWConnection) {
        conn.start(queue: .main)
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, _ in
            guard let self, let data, let requestText = String(data: data, encoding: .utf8) else {
                conn.cancel(); return
            }
            let (path, query) = Self.parseRequestLine(requestText)
            let html = self.onRequest(path, query)
            let response = """
            HTTP/1.1 200 OK\r
            Content-Type: text/html; charset=utf-8\r
            Content-Length: \(html.utf8.count)\r
            Connection: close\r
            \r
            \(html)
            """
            conn.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
                conn.cancel()
            })
        }
    }

    /// Extract the path and query from the first HTTP request line: `GET /callback?… HTTP/1.1`.
    private static func parseRequestLine(_ text: String) -> (path: String, query: [String: String]) {
        let firstLine = text.split(whereSeparator: { $0 == "\r" || $0 == "\n" }).first.map(String.init) ?? ""
        let fields = firstLine.split(separator: " ")
        guard fields.count >= 2 else { return ("", [:]) }
        let target = String(fields[1])
        guard let comps = URLComponents(string: "http://localhost" + target) else { return ("", [:]) }
        var query: [String: String] = [:]
        for item in comps.queryItems ?? [] { query[item.name] = item.value ?? "" }
        return (comps.path, query)
    }
}
