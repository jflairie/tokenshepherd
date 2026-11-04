import XCTest
import os
@testable import TokenShepherd

/// A failure detail can carry a whole reply (2,179 bytes on 2026-11-04), and the unified log cuts
/// each message at ~1 KB. The parts must each fit and rejoin to the exact text.
final class LogTests: XCTestCase {
    func testLongTextSplitsIntoPartsThatFitAndRejoin() {
        let reply = String(repeating: #"{"kind": "weekly_all", "percent": 3}, "#, count: 60)   // ~2.3 KB
        let parts = Logger.parts(of: reply)

        XCTAssertEqual(parts.count, 3)
        XCTAssertTrue(parts.allSatisfy { $0.utf8.count <= 800 })
        XCTAssertEqual(parts.joined(), reply)
    }

    /// The limit is in bytes: a 2-byte "é" counts double, and a part never ends mid-character.
    func testMultiByteTextSplitsOnCharacters() {
        let text = String(repeating: "\u{E9}", count: 1_000)   // "é", 2,000 bytes
        let parts = Logger.parts(of: text)

        XCTAssertEqual(parts.map(\.utf8.count), [800, 800, 400])
        XCTAssertEqual(parts.joined(), text)
    }

    func testShortTextIsOnePart() {
        XCTAssertEqual(Logger.parts(of: "Network error: offline"), ["Network error: offline"])
        XCTAssertEqual(Logger.parts(of: ""), [""])
    }
}
