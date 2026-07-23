import Foundation

enum SyncState: Equatable {
    case notConfigured
    case ready
    case syncing
    case success
    case warning
    case error

    var displayName: String {
        switch self {
        case .notConfigured: return "Not Configured"
        case .ready: return "Ready"
        case .syncing: return "Syncing…"
        case .success: return "Synced"
        case .warning: return "Warning"
        case .error: return "Error"
        }
    }
}

enum MenuBarIndicator: String, CaseIterable, Hashable {
    case setupRequired
    case neverSynced
    case synced
    case agingNormally
    case startingSoon
    case overdue
    case syncing
    case paused
    case warning
    case error

    var defaultSystemSymbol: String {
        switch self {
        case .setupRequired: return "gearshape.fill"
        case .neverSynced: return "circle"
        case .synced: return "checkmark.circle.fill"
        case .agingNormally: return "checkmark.circle"
        case .startingSoon: return "clock.fill"
        case .overdue: return "exclamationmark.circle"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .paused: return "pause.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        }
    }

    var displayName: String {
        switch self {
        case .setupRequired: return "Setup Required"
        case .neverSynced: return "Not Yet Synced"
        case .synced: return "Just Synced"
        case .agingNormally: return "Up to Date"
        case .startingSoon: return "Starting Soon"
        case .overdue: return "Sync Overdue"
        case .syncing: return "Syncing…"
        case .paused: return "Automatic Sync Paused"
        case .warning: return "Warning"
        case .error: return "Error"
        }
    }

    static func evaluate(
        state: SyncState,
        lastCompletedAt: Date?,
        nextScheduledAt: Date?,
        interval: TimeInterval,
        now: Date
    ) -> MenuBarIndicator {
        switch state {
        case .notConfigured:
            return .setupRequired
        case .syncing:
            return .syncing
        case .error:
            return .error
        case .ready, .success, .warning:
            break
        }

        guard let lastCompletedAt else { return .neverSynced }
        let elapsed = max(now.timeIntervalSince(lastCompletedAt), 0)
        guard elapsed <= interval else { return .overdue }

        if state == .warning {
            return .warning
        }

        if let nextScheduledAt {
            let timeUntilNext = nextScheduledAt.timeIntervalSince(now)
            if timeUntilNext >= 0, timeUntilNext <= 10 {
                return .startingSoon
            }
        }

        return elapsed <= interval / 2 ? .synced : .agingNormally
    }
}

enum SyncSchedule {
    static func initialDelay(
        lastCompletedAt: Date?,
        interval: TimeInterval,
        now: Date
    ) -> TimeInterval {
        guard let lastCompletedAt else { return 0 }
        return max(lastCompletedAt.addingTimeInterval(interval).timeIntervalSince(now), 0)
    }
}

enum SyncEvaluation {
    static func state(for output: FreeFileSyncOutput, terminationStatus: Int32) -> SyncState {
        guard terminationStatus == 0 else { return .error }

        switch output.syncResult.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "success":
            if (output.errors ?? 0) > 0 { return .error }
            if (output.warnings ?? 0) > 0 { return .warning }
            return .success
        case "warning":
            return .warning
        case "error":
            return .error
        default:
            return .error
        }
    }
}
