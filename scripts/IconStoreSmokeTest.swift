import Foundation

@main
@MainActor
struct IconStoreSmokeTest {
    static func main() {
        let suiteName = "IconStoreSmokeTest-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)
        let pinned = drawing(createdAt: Date(timeIntervalSinceReferenceDate: 1))
        store.saveAndAssign(pinned, to: .synced)
        store.setAnimationEffect(.spin, for: .synced)
        store.setAnimationDuration(5, for: .synced)
        let reloadedStore = SettingsStore(defaults: defaults)
        precondition(reloadedStore.customIconHistory.first?.strokes.first?.color == .mint)
        precondition(
            reloadedStore.animationConfiguration(for: .synced)
                == IconAnimationConfiguration(effect: .spin, durationSeconds: 5)
        )

        let legacyStrokeData = """
        {"points":[{"x":0.2,"y":0.2}],"width":0.08}
        """.data(using: .utf8)!
        let legacyStroke = try! JSONDecoder().decode(
            IconStroke.self,
            from: legacyStrokeData
        )
        precondition(legacyStroke.color == .white)

        var oldestUnusedID: UUID?
        for index in 0..<20 {
            let drawing = drawing(
                createdAt: Date(timeIntervalSinceReferenceDate: Double(index + 2))
            )
            if index == 0 { oldestUnusedID = drawing.id }
            store.saveAndAssign(drawing, to: .agingNormally)
        }

        precondition(
            store.customIconHistory.count == SettingsStore.maximumCustomIconHistory
        )
        precondition(store.customIconHistory.contains { $0.id == pinned.id })
        precondition(!store.customIconHistory.contains { $0.id == oldestUnusedID })
        precondition(store.orderedCustomIcons.first?.id == pinned.id)
        precondition(!store.deleteCustomIcon(pinned.id))
        if let oldestRemainingUnused = store.customIconHistory.first(
            where: { !store.isCustomIconInUse($0.id) }
        ) {
            precondition(store.deleteCustomIcon(oldestRemainingUnused.id))
            precondition(
                !store.customIconHistory.contains { $0.id == oldestRemainingUnused.id }
            )
        } else {
            preconditionFailure("Expected an unused drawing")
        }

        store.setAnimationEffect(.none, for: .synced)
        precondition(
            store.animationConfiguration(for: .synced)
                == IconAnimationConfiguration()
        )
        store.setAnimationDuration(5, for: .synced)
        precondition(
            store.animationConfiguration(for: .synced).durationSeconds == 0
        )
        store.setAnimationEffect(.sway, for: .synced)
        precondition(
            store.animationConfiguration(for: .synced)
                == IconAnimationConfiguration(
                    effect: .sway,
                    durationSeconds: 2
                )
        )
        store.setAnimationDuration(4, for: .synced)
        store.useDefaultIcon(for: .synced)
        precondition(store.customDrawing(for: .synced) == nil)
        precondition(
            store.animationConfiguration(for: .synced)
                == IconAnimationConfiguration()
        )

        store.intervalMinutes = 60
        store.batchJobPath = "/tmp/kept.ffs_batch"
        store.freeFileSyncAppPath = "/tmp/Custom FreeFileSync.app"
        store.resetToDefaultsPreservingBatchJob()
        precondition(store.intervalMinutes == 5)
        precondition(store.batchJobPath == "/tmp/kept.ffs_batch")
        precondition(
            store.freeFileSyncAppPath == SettingsStore.defaultFreeFileSyncAppPath
        )
        precondition(
            store.animationConfiguration(for: .synced)
                == IconAnimationConfiguration()
        )

        print("Icon store smoke tests passed")
    }

    private static func drawing(createdAt: Date) -> CustomIconDrawing {
        CustomIconDrawing(
            createdAt: createdAt,
            strokes: [
                IconStroke(
                    points: [
                        IconPoint(x: 0.2, y: 0.2),
                        IconPoint(x: 0.8, y: 0.8)
                    ],
                    width: 0.08,
                    color: .mint
                )
            ]
        )
    }
}
