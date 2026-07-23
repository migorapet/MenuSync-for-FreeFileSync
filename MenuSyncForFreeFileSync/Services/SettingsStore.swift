import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    private enum Key {
        static let batchJobPath = "batchJobPath"
        static let freeFileSyncAppPath = "freeFileSyncAppPath"
        static let intervalMinutes = "intervalMinutes"
        static let notificationsOnFailure = "notificationsOnFailure"
        static let statusIconAssignments = "statusIconAssignments"
        static let customIconHistory = "customIconHistory"
    }

    static let defaultIntervalMinutes = 5
    static let defaultFreeFileSyncAppPath = "/Applications/FreeFileSync.app"
    static let maximumCustomIconHistory = 20
    private static let systemPrefix = "system:"
    private static let customPrefix = "custom:"

    @Published var batchJobPath: String {
        didSet { defaults.set(batchJobPath, forKey: Key.batchJobPath) }
    }

    @Published var freeFileSyncAppPath: String {
        didSet { defaults.set(freeFileSyncAppPath, forKey: Key.freeFileSyncAppPath) }
    }

    @Published var intervalMinutes: Int {
        didSet { defaults.set(intervalMinutes, forKey: Key.intervalMinutes) }
    }

    @Published var notificationsOnFailure: Bool {
        didSet { defaults.set(notificationsOnFailure, forKey: Key.notificationsOnFailure) }
    }

    @Published var statusIconAssignments: [String: String] {
        didSet {
            if let data = try? JSONEncoder().encode(statusIconAssignments) {
                defaults.set(data, forKey: Key.statusIconAssignments)
            }
        }
    }

    @Published var customIconHistory: [CustomIconDrawing] {
        didSet {
            if let data = try? JSONEncoder().encode(customIconHistory) {
                defaults.set(data, forKey: Key.customIconHistory)
            }
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        batchJobPath = defaults.string(forKey: Key.batchJobPath) ?? ""
        freeFileSyncAppPath = defaults.string(forKey: Key.freeFileSyncAppPath)
            ?? Self.defaultFreeFileSyncAppPath

        let savedInterval = defaults.integer(forKey: Key.intervalMinutes)
        intervalMinutes = savedInterval > 0 ? savedInterval : Self.defaultIntervalMinutes

        if defaults.object(forKey: Key.notificationsOnFailure) == nil {
            notificationsOnFailure = true
        } else {
            notificationsOnFailure = defaults.bool(forKey: Key.notificationsOnFailure)
        }

        var assignments = Self.defaultStatusIconAssignments
        if let data = defaults.data(forKey: Key.statusIconAssignments),
           let saved = try? JSONDecoder().decode([String: String].self, from: data) {
            assignments.merge(saved) { _, savedValue in savedValue }
        }
        statusIconAssignments = assignments

        if let data = defaults.data(forKey: Key.customIconHistory),
           let saved = try? JSONDecoder().decode([CustomIconDrawing].self, from: data) {
            customIconHistory = saved
        } else {
            customIconHistory = []
        }
        pruneCustomIconHistory()
    }

    func systemSymbolName(for indicator: MenuBarIndicator) -> String? {
        let reference = iconReference(for: indicator)
        guard reference.hasPrefix(Self.systemPrefix) else { return nil }
        return String(reference.dropFirst(Self.systemPrefix.count))
    }

    func customDrawing(for indicator: MenuBarIndicator) -> CustomIconDrawing? {
        let reference = iconReference(for: indicator)
        guard reference.hasPrefix(Self.customPrefix),
              let id = UUID(uuidString: String(reference.dropFirst(Self.customPrefix.count)))
        else {
            return nil
        }
        return customIconHistory.first { $0.id == id }
    }

    func saveAndAssign(
        _ drawing: CustomIconDrawing,
        to indicator: MenuBarIndicator
    ) {
        guard !drawing.isEmpty else { return }
        customIconHistory.removeAll { $0.id == drawing.id }
        customIconHistory.append(drawing)
        assignCustomIcon(drawing.id, to: indicator)
        pruneCustomIconHistory()
    }

    func assignCustomIcon(_ id: UUID, to indicator: MenuBarIndicator) {
        guard customIconHistory.contains(where: { $0.id == id }) else { return }
        statusIconAssignments[indicator.rawValue] = Self.customPrefix + id.uuidString
        pruneCustomIconHistory()
    }

    func useDefaultIcon(for indicator: MenuBarIndicator) {
        statusIconAssignments[indicator.rawValue] =
            Self.systemPrefix + indicator.defaultSystemSymbol
        pruneCustomIconHistory()
    }

    func isCustomIconInUse(_ id: UUID) -> Bool {
        usedCustomIconIDs.contains(id)
    }

    @discardableResult
    func deleteCustomIcon(_ id: UUID) -> Bool {
        guard !usedCustomIconIDs.contains(id),
              customIconHistory.contains(where: { $0.id == id })
        else {
            return false
        }
        customIconHistory.removeAll { $0.id == id }
        return true
    }

    var orderedCustomIcons: [CustomIconDrawing] {
        let usedIDs = MenuBarIndicator.allCases.compactMap { indicator -> UUID? in
            let reference = iconReference(for: indicator)
            guard reference.hasPrefix(Self.customPrefix) else { return nil }
            return UUID(uuidString: String(reference.dropFirst(Self.customPrefix.count)))
        }
        let uniqueUsedIDs = usedIDs.reduce(into: [UUID]()) { result, id in
            if !result.contains(id) { result.append(id) }
        }
        let used = uniqueUsedIDs.compactMap { id in
            customIconHistory.first { $0.id == id }
        }
        let usedSet = Set(uniqueUsedIDs)
        let unused = customIconHistory
            .filter { !usedSet.contains($0.id) }
            .sorted { $0.createdAt > $1.createdAt }
        return used + unused
    }

    func resetToDefaultsPreservingBatchJob() {
        freeFileSyncAppPath = Self.defaultFreeFileSyncAppPath
        intervalMinutes = Self.defaultIntervalMinutes
        notificationsOnFailure = true
        statusIconAssignments = Self.defaultStatusIconAssignments
        pruneCustomIconHistory()
    }

    private func iconReference(for indicator: MenuBarIndicator) -> String {
        statusIconAssignments[indicator.rawValue]
            ?? Self.systemPrefix + indicator.defaultSystemSymbol
    }

    private var usedCustomIconIDs: Set<UUID> {
        Set(statusIconAssignments.values.compactMap { reference in
            guard reference.hasPrefix(Self.customPrefix) else { return nil }
            return UUID(uuidString: String(reference.dropFirst(Self.customPrefix.count)))
        })
    }

    private func pruneCustomIconHistory() {
        while customIconHistory.count > Self.maximumCustomIconHistory {
            let usedIDs = usedCustomIconIDs
            guard let oldestUnusedIndex = customIconHistory.indices
                .filter({ !usedIDs.contains(customIconHistory[$0].id) })
                .min(by: {
                    customIconHistory[$0].createdAt < customIconHistory[$1].createdAt
                })
            else {
                break
            }
            customIconHistory.remove(at: oldestUnusedIndex)
        }
    }

    private static var defaultStatusIconAssignments: [String: String] {
        Dictionary(
            uniqueKeysWithValues: MenuBarIndicator.allCases.map {
                ($0.rawValue, systemPrefix + $0.defaultSystemSymbol)
            }
        )
    }
}
