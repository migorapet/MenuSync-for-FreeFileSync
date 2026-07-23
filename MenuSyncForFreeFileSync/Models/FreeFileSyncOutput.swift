import Foundation

struct FreeFileSyncOutput: Codable, Equatable {
    let syncResult: String
    let startTime: String?
    let totalTimeSec: Double?
    let errors: Int?
    let warnings: Int?
    let totalItems: Int?
    let processedItems: Int?
    let processedBytes: Int64?
    let logFile: String?

    var startDate: Date? {
        guard let startTime else { return nil }
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds,
            .withColonSeparatorInTimeZone
        ]
        if let date = fractionalFormatter.date(from: startTime) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
        return formatter.date(from: startTime)
    }
}

struct StoredSyncSummary: Codable {
    let batchJobPath: String
    let output: FreeFileSyncOutput
    let terminationStatus: Int32
    let completedAt: Date
}
