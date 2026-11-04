import XCTest
@testable import TokenShepherd

/// The usage reply is the app's one external boundary: a shape it rejects blinds the sheep, and
/// a shape it misreads makes the menu claim things Anthropic never said. Fixtures are real
/// replies, trimmed to the fields we read plus a few we don't.
final class QuotaResponseTests: XCTestCase {
    // Ultra plan, 2026-11-04: no 5h limit since 2026-10-31 — `five_hour` is null AND limits[]
    // has no "session", while the weekly climbed 2% → 3% in use. Rejecting this left the app
    // blind for 4 days behind a "Can't reach Anthropic" footer.
    private let replyWithoutFiveHour = #"""
    {
      "five_hour": null,
      "seven_day": {"utilization": 2.0, "resets_at": "2026-11-06T16:59:59.659753+00:00",
                    "limit_dollars": null, "used_dollars": null, "locked_reason": null},
      "seven_day_opus": null,
      "extra_usage": {"is_enabled": false, "monthly_limit": null},
      "limits": [
        {"kind": "weekly_all", "group": "weekly", "percent": 2, "severity": "normal",
         "resets_at": "2026-11-06T16:59:59.659753+00:00", "scope": null, "is_active": true},
        {"kind": "weekly_scoped", "group": "weekly", "percent": 0, "severity": "normal",
         "resets_at": "2026-11-06T17:00:00+00:00",
         "scope": {"model": {"id": null, "display_name": "Fable"}, "surface": null}, "is_active": false}
      ]
    }
    """#

    // A plan with a 5h limit (every plan but Ultra), 2026-10-30: an idle session — reported,
    // nothing used yet, no reset time.
    private let replyIdleSession = #"""
    {
      "five_hour": {"utilization": 0.0, "resets_at": null, "locked_reason": null},
      "seven_day": {"utilization": 38.0, "resets_at": "2026-10-30T17:00:00.244801+00:00"},
      "limits": [
        {"kind": "session", "group": "session", "percent": 0, "severity": "normal",
         "resets_at": null, "scope": null, "is_active": false},
        {"kind": "weekly_all", "group": "weekly", "percent": 38, "severity": "normal",
         "resets_at": "2026-10-30T17:00:00.244801+00:00", "scope": null, "is_active": true}
      ]
    }
    """#

    func testReplyWithoutFiveHourDecodes() throws {
        let reply = try decode(replyWithoutFiveHour)
        XCTAssertNil(reply.fiveHour)
        XCTAssertEqual(reply.sevenDay?.utilization, 2.0)
    }

    /// Not reported means no 5h column — never a "reset" Anthropic didn't say.
    func testUnreportedFiveHourHasNoWindow() throws {
        let quota = try QuotaService.mapResponse(decode(replyWithoutFiveHour))

        XCTAssertNil(quota.fiveHour)
        XCTAssertEqual(quota.sevenDay.utilization, 0.02, accuracy: 0.0001)
        XCTAssertEqual(quota.sevenDay.resetsAt.timeIntervalSince1970, epoch("2026-11-06T16:59:59Z"), accuracy: 1)
        // No fractional seconds in this one: it used to parse as "resets now" → column showed "reset".
        XCTAssertEqual(quota.weeklyScoped?.label, "Fable")
        XCTAssertEqual(quota.weeklyScoped?.resetsAt.timeIntervalSince1970 ?? 0, epoch("2026-11-06T17:00:00Z"), accuracy: 1)
    }

    func testIdleSessionIsStillAFiveHourWindow() throws {
        let quota = try QuotaService.mapResponse(decode(replyIdleSession))

        let fiveHour = try XCTUnwrap(quota.fiveHour)
        XCTAssertEqual(fiveHour.utilization, 0)
        XCTAssertLessThanOrEqual(fiveHour.resetsAt.timeIntervalSinceNow, 0)   // renders as "reset"
        XCTAssertEqual(quota.sevenDay.utilization, 0.38, accuracy: 0.0001)
    }

    /// A plan with a 5h limit, mid-session: the column the sheep mostly rides on. Shape of the
    /// real 2026-10-30 reply; values from a real 2026-02-10 reading (5h 75%, weekly 60%).
    func testFiveHourPlanMidSession() throws {
        let reply = #"""
        {
          "five_hour": {"utilization": 75.0, "resets_at": "2026-02-10T12:00:00.231467+00:00"},
          "seven_day": {"utilization": 60.0, "resets_at": "2026-02-12T12:00:00+00:00"},
          "limits": [
            {"kind": "session", "group": "session", "percent": 75, "severity": "normal",
             "resets_at": "2026-02-10T12:00:00.231467+00:00", "scope": null, "is_active": true},
            {"kind": "weekly_all", "group": "weekly", "percent": 60, "severity": "normal",
             "resets_at": "2026-02-12T12:00:00+00:00", "scope": null, "is_active": true}
          ]
        }
        """#
        let quota = try QuotaService.mapResponse(decode(reply))

        let fiveHour = try XCTUnwrap(quota.fiveHour)
        XCTAssertEqual(fiveHour.utilization, 0.75, accuracy: 0.0001)
        XCTAssertEqual(fiveHour.resetsAt.timeIntervalSince1970, epoch("2026-02-10T12:00:00Z"), accuracy: 1)
        XCTAssertEqual(quota.sevenDay.utilization, 0.60, accuracy: 0.0001)
        XCTAssertEqual(quota.sevenDay.resetsAt.timeIntervalSince1970, epoch("2026-02-12T12:00:00Z"), accuracy: 1)
    }

    /// Anthropic drops fields; limits[] alone carries everything we need.
    func testLimitsAloneAreEnough() throws {
        let reply = #"""
        {"limits": [{"kind": "weekly_all", "group": "weekly", "percent": 3,
                     "resets_at": "2026-11-06T17:00:00.356147+00:00"}]}
        """#
        let quota = try QuotaService.mapResponse(decode(reply))
        XCTAssertNil(quota.fiveHour)
        XCTAssertEqual(quota.sevenDay.utilization, 0.03, accuracy: 0.0001)
    }

    /// No weekly from any source: the reply is unusable and must fail loudly
    /// ("Can't read Anthropic's reply"), not read as a quiet "Standing by".
    func testReplyWithoutWeeklyIsUnreadable() throws {
        let reply = try decode(#"{"five_hour": null, "seven_day": null, "limits": []}"#)
        XCTAssertThrowsError(try QuotaService.mapResponse(reply)) { error in
            XCTAssertTrue(error is DecodingError, "routes to .unreadable only as a DecodingError, got \(error)")
        }
    }

    /// history.jsonl: rows without a 5h window omit its keys; rows written before still read.
    func testHistoryRowsWithAndWithoutFiveHour() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let now = Date(timeIntervalSince1970: 1_793_781_919)
        let new = HistoryEntry(ts: now, fiveHourUtil: nil, sevenDayUtil: 0.03,
                               fiveHourResetsAt: nil, sevenDayResetsAt: now.addingTimeInterval(3600))
        let line = try XCTUnwrap(String(data: encoder.encode(new), encoding: .utf8))
        XCTAssertFalse(line.contains("fiveHour"))
        XCTAssertNil(try decoder.decode(HistoryEntry.self, from: Data(line.utf8)).reading(fiveHour: true))

        let old = #"{"ts":"2026-10-30T16:34:46Z","fiveHourUtil":0.12,"fiveHourResetsAt":"2026-10-30T19:00:00Z","sevenDayUtil":0.38,"sevenDayResetsAt":"2026-10-30T16:59:59Z"}"#
        let reading = try XCTUnwrap(decoder.decode(HistoryEntry.self, from: Data(old.utf8)).reading(fiveHour: true))
        XCTAssertEqual(reading.util, 0.12)
    }

    private func decode(_ json: String) throws -> APIQuotaResponse {
        try JSONDecoder().decode(APIQuotaResponse.self, from: Data(json.utf8))
    }

    private func epoch(_ iso: String) -> TimeInterval {
        ISO8601DateFormatter().date(from: iso)!.timeIntervalSince1970
    }
}
