import XCTest
@testable import MenuSyncForFreeFileSync

final class FreeFileSyncOutputTests: XCTestCase {
    func testDecodesDocumentedJSON() throws {
        let json = """
        {
          "syncResult": "success",
          "startTime": "2026-07-23T16:34:27+08:00",
          "totalTimeSec": 1,
          "errors": 0,
          "warnings": 0,
          "totalItems": 0,
          "processedItems": 0,
          "processedBytes": 0,
          "logFile": "/Users/example/Logs/result.html"
        }
        """.data(using: .utf8)!

        let output = try JSONDecoder().decode(FreeFileSyncOutput.self, from: json)

        XCTAssertEqual(output.syncResult, "success")
        XCTAssertEqual(output.totalTimeSec, 1)
        XCTAssertEqual(output.processedItems, 0)
        XCTAssertNotNil(output.startDate)
    }

    func testNonzeroExitOverridesSuccess() throws {
        let output = makeOutput(result: "success")
        XCTAssertEqual(SyncEvaluation.state(for: output, terminationStatus: 1), .error)
    }

    func testWarningsUpgradeSuccessToWarning() throws {
        let output = makeOutput(result: "success", warnings: 2)
        XCTAssertEqual(SyncEvaluation.state(for: output, terminationStatus: 0), .warning)
    }

    func testUnknownResultIsError() throws {
        let output = makeOutput(result: "something-new")
        XCTAssertEqual(SyncEvaluation.state(for: output, terminationStatus: 0), .error)
    }

    func testStrokeColorRoundTripAndLegacyDefault() throws {
        let stroke = IconStroke(
            points: [IconPoint(x: 0.25, y: 0.75)],
            width: 0.08,
            color: .mint
        )
        let encoded = try JSONEncoder().encode(stroke)
        XCTAssertEqual(try JSONDecoder().decode(IconStroke.self, from: encoded), stroke)

        let legacyJSON = #"""
        {"points":[{"x":0.25,"y":0.75}],"width":0.08}
        """#.data(using: .utf8)!
        let legacyStroke = try JSONDecoder().decode(IconStroke.self, from: legacyJSON)
        XCTAssertEqual(legacyStroke.color, .white)
    }

    func testMenuBarFreshnessTransitions() {
        let now = Date(timeIntervalSinceReferenceDate: 10_000)
        let interval: TimeInterval = 600

        XCTAssertEqual(
            indicator(completedAgo: 60, nextIn: 540, interval: interval, now: now),
            .synced
        )
        XCTAssertEqual(
            indicator(completedAgo: 301, nextIn: 299, interval: interval, now: now),
            .agingNormally
        )
        XCTAssertEqual(
            indicator(completedAgo: 591, nextIn: 9, interval: interval, now: now),
            .startingSoon
        )
        XCTAssertEqual(
            indicator(completedAgo: 601, nextIn: 599, interval: interval, now: now),
            .overdue
        )
    }

    func testInitialScheduleRunsOverdueJobImmediately() {
        let now = Date(timeIntervalSinceReferenceDate: 10_000)
        XCTAssertEqual(
            SyncSchedule.initialDelay(
                lastCompletedAt: now.addingTimeInterval(-601),
                interval: 600,
                now: now
            ),
            0
        )
    }

    func testInitialSchedulePreservesRemainingInterval() {
        let now = Date(timeIntervalSinceReferenceDate: 10_000)
        XCTAssertEqual(
            SyncSchedule.initialDelay(
                lastCompletedAt: now.addingTimeInterval(-200),
                interval: 600,
                now: now
            ),
            400
        )
    }

    private func makeOutput(
        result: String,
        errors: Int = 0,
        warnings: Int = 0
    ) -> FreeFileSyncOutput {
        FreeFileSyncOutput(
            syncResult: result,
            startTime: nil,
            totalTimeSec: 1,
            errors: errors,
            warnings: warnings,
            totalItems: 1,
            processedItems: 1,
            processedBytes: 1,
            logFile: nil
        )
    }

    private func indicator(
        completedAgo: TimeInterval,
        nextIn: TimeInterval,
        interval: TimeInterval,
        now: Date
    ) -> MenuBarIndicator {
        MenuBarIndicator.evaluate(
            state: .success,
            lastCompletedAt: now.addingTimeInterval(-completedAgo),
            nextScheduledAt: now.addingTimeInterval(nextIn),
            interval: interval,
            now: now
        )
    }
}
