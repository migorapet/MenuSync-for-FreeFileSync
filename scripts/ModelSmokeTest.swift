import Foundation

@main
struct ModelSmokeTest {
    static func main() throws {
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
        precondition(output.startDate != nil)
        precondition(SyncEvaluation.state(for: output, terminationStatus: 0) == .success)
        precondition(SyncEvaluation.state(for: output, terminationStatus: 1) == .error)

        let warningOutput = FreeFileSyncOutput(
            syncResult: "success",
            startTime: nil,
            totalTimeSec: 1,
            errors: 0,
            warnings: 1,
            totalItems: 1,
            processedItems: 1,
            processedBytes: 1,
            logFile: nil
        )
        precondition(SyncEvaluation.state(for: warningOutput, terminationStatus: 0) == .warning)

        let now = Date(timeIntervalSinceReferenceDate: 10_000)
        let interval: TimeInterval = 600
        func indicator(completedAgo: TimeInterval, nextIn: TimeInterval) -> MenuBarIndicator {
            MenuBarIndicator.evaluate(
                state: .success,
                lastCompletedAt: now.addingTimeInterval(-completedAgo),
                nextScheduledAt: now.addingTimeInterval(nextIn),
                interval: interval,
                now: now
            )
        }

        precondition(indicator(completedAgo: 60, nextIn: 540) == .synced)
        precondition(indicator(completedAgo: 301, nextIn: 299) == .agingNormally)
        precondition(indicator(completedAgo: 591, nextIn: 9) == .startingSoon)
        precondition(indicator(completedAgo: 601, nextIn: 599) == .overdue)
        precondition(
            SyncSchedule.initialDelay(
                lastCompletedAt: now.addingTimeInterval(-601),
                interval: interval,
                now: now
            ) == 0
        )
        precondition(
            SyncSchedule.initialDelay(
                lastCompletedAt: now.addingTimeInterval(-200),
                interval: interval,
                now: now
            ) == 400
        )

        print("Model smoke tests passed")
    }
}
