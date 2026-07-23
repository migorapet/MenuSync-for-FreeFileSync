import AppKit
import Combine
import Foundation
import ServiceManagement
import SwiftUI
import UserNotifications

private struct IconFrameCacheSignature: Equatable {
    let indicator: String
    let drawingID: UUID?
    let systemSymbolName: String?
    let configuration: IconAnimationConfiguration
    let isPreview: Bool
    let reduceMotion: Bool
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var state: SyncState
    @Published private(set) var lastSummary: StoredSyncSummary?
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var launchAtLoginEnabled: Bool
    @Published private(set) var currentTime = Date()
    @Published private(set) var iconAnimationDate = Date()
    @Published private(set) var nextScheduledSyncAt: Date?
    @Published private(set) var consecutiveFailureCount: Int
    @Published private(set) var previewIconDrawing: CustomIconDrawing? = nil
    @Published private(set) var previewAnimationConfiguration:
        IconAnimationConfiguration? = nil
    @Published private(set) var iconPreviewEndsAt: Date?

    private static let summaryKey = "lastSyncSummary"
    private static let failureCountKey = "consecutiveFailureCount"
    private static let failureBatchPathKey = "failureBatchJobPath"
    private static let maximumConsecutiveFailures = 3
    private let settings: SettingsStore
    private var syncTimer: Timer?
    private var indicatorTimer: Timer?
    private var iconAnimationTimer: Timer?
    private var iconPreviewTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var preferencesWindowController: NSWindowController?
    private var failureBatchJobPath: String
    private var iconFrameCacheSignature: IconFrameCacheSignature?
    private var iconFrameCache: [NSImage] = []
    private var iconAnimationStartedAt: Date?

    init(settings: SettingsStore) {
        self.settings = settings
        let storedSummary = Self.loadSummary()
        let matchingSummary = storedSummary?.batchJobPath == settings.batchJobPath
            ? storedSummary
            : nil
        lastSummary = matchingSummary
        launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
        let storedFailurePath = UserDefaults.standard.string(forKey: Self.failureBatchPathKey) ?? ""
        failureBatchJobPath = storedFailurePath
        consecutiveFailureCount = storedFailurePath == settings.batchJobPath
            ? UserDefaults.standard.integer(forKey: Self.failureCountKey)
            : 0

        if settings.batchJobPath.isEmpty {
            state = .notConfigured
        } else if let summary = matchingSummary {
            state = SyncEvaluation.state(
                for: summary.output,
                terminationStatus: summary.terminationStatus
            )
        } else {
            state = .ready
        }

        settings.$intervalMinutes
            .dropFirst()
            .sink { [weak self] _ in self?.scheduleNextSync() }
            .store(in: &cancellables)

        settings.$statusIconAssignments
            .dropFirst()
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        settings.$statusAnimationSettings
            .dropFirst()
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        settings.$customIconHistory
            .dropFirst()
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        settings.$batchJobPath
            .dropFirst()
            .sink { [weak self] path in
                guard let self, self.state != .syncing else { return }
                self.lastErrorMessage = nil
                self.resetFailures(for: path)
                guard self.lastSummary?.batchJobPath == path else {
                    self.lastSummary = nil
                    self.state = path.isEmpty ? .notConfigured : .ready
                    self.syncTimer?.invalidate()
                    self.syncTimer = nil
                    self.nextScheduledSyncAt = nil
                    if self.hasValidBatchJob {
                        self.scheduleInitialSync(requireExistingBatch: true)
                    }
                    return
                }
            }
            .store(in: &cancellables)

        startIndicatorTimer()
        startIconAnimationTimer()
        scheduleInitialSync()
    }

    var indicator: MenuBarIndicator {
        if state != .syncing, isAutomaticallyPaused {
            return .paused
        }
        return MenuBarIndicator.evaluate(
            state: state,
            lastCompletedAt: lastSummary?.completedAt,
            nextScheduledAt: nextScheduledSyncAt,
            interval: syncInterval,
            now: currentTime
        )
    }

    var isIconAnimationActive: Bool {
        let configuration = previewAnimationConfiguration
            ?? settings.animationConfiguration(for: indicator)
        guard configuration.effect != .none,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        else {
            return false
        }
        guard let iconAnimationStartedAt else { return true }
        return iconAnimationDate
            < iconAnimationStartedAt.addingTimeInterval(
                TimeInterval(configuration.durationSeconds)
            )
    }

    var menuBarImage: NSImage {
        menuBarImage(at: iconAnimationDate)
    }

    func menuBarImage(at date: Date = Date()) -> NSImage {
        let drawing = previewIconDrawing
            ?? settings.customDrawing(for: indicator)
        let systemSymbolName = drawing == nil
            ? settings.systemSymbolName(for: indicator)
                ?? indicator.defaultSystemSymbol
            : nil
        let configuration = previewAnimationConfiguration
            ?? settings.animationConfiguration(for: indicator)
        let signature = IconFrameCacheSignature(
            indicator: indicator.rawValue,
            drawingID: drawing?.id,
            systemSymbolName: systemSymbolName,
            configuration: configuration,
            isPreview: previewIconDrawing != nil,
            reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        )

        var frameDate = date
        if signature != iconFrameCacheSignature {
            let baseImage: NSImage
            if let drawing {
                baseImage = MenuBarIconRenderer.customImage(
                    from: drawing,
                    accessibilityDescription: previewIconDrawing == nil
                        ? menuBarStatusText
                        : "Custom icon preview"
                )
            } else {
                baseImage = MenuBarIconRenderer.systemImage(
                    named: systemSymbolName ?? indicator.defaultSystemSymbol,
                    accessibilityDescription: menuBarStatusText
                )
            }
            iconFrameCache = MenuBarIconRenderer.animationFrames(
                from: baseImage,
                configuration: configuration
            )
            iconFrameCacheSignature = signature
            let startedAt = Date()
            iconAnimationStartedAt = startedAt
            frameDate = startedAt
        }

        return MenuBarIconRenderer.frame(
            at: frameDate,
            animationStartedAt: iconAnimationStartedAt ?? frameDate,
            from: iconFrameCache,
            animationDurationSeconds: configuration.durationSeconds
        )
    }

    var menuBarStatusText: String { indicator.displayName }
    var isPreviewingIcon: Bool { previewIconDrawing != nil }
    var iconPreviewSecondsRemaining: Int {
        guard isPreviewingIcon, let iconPreviewEndsAt else { return 0 }
        return max(
            Int(ceil(iconPreviewEndsAt.timeIntervalSinceNow)),
            0
        )
    }

    var lastSyncText: String {
        guard let summary = lastSummary else { return "Never" }
        let date = summary.output.startDate ?? summary.completedAt
        return compactDateTime(date)
    }

    var durationText: String {
        guard let duration = lastSummary?.output.totalTimeSec else { return "—" }
        if duration < 60 { return String(format: "%.1f sec", duration) }
        return Duration.seconds(duration).formatted(.units(allowed: [.minutes, .seconds]))
    }

    var filesProcessedText: String {
        guard let value = lastSummary?.output.processedItems else { return "—" }
        return value.formatted()
    }

    var warningsText: String {
        guard let value = lastSummary?.output.warnings else { return "—" }
        return value.formatted()
    }

    var errorsText: String {
        guard let value = lastSummary?.output.errors else { return "—" }
        return value.formatted()
    }

    var nextSyncText: String {
        if isAutomaticallyPaused { return "Paused" }
        guard let nextScheduledSyncAt else {
            return state == .syncing ? "After completion" : "—"
        }
        return compactDateTime(nextScheduledSyncAt)
    }

    var canRun: Bool {
        state != .syncing
    }

    var failureCountText: String {
        "\(consecutiveFailureCount) / \(Self.maximumConsecutiveFailures)"
    }

    var isAutomaticallyPaused: Bool {
        consecutiveFailureCount >= Self.maximumConsecutiveFailures
    }

    var canOpenLastLog: Bool {
        guard let path = lastSummary?.output.logFile else { return false }
        return FileManager.default.fileExists(atPath: path)
    }

    var canOpenBatch: Bool {
        !settings.batchJobPath.isEmpty
            && URL(fileURLWithPath: settings.batchJobPath).pathExtension.lowercased() == "ffs_batch"
            && FileManager.default.fileExists(atPath: settings.batchJobPath)
    }

    func runSync(showPreferencesIfNeeded: Bool = true) {
        guard state != .syncing else { return }
        guard !settings.batchJobPath.isEmpty else {
            state = .notConfigured
            if showPreferencesIfNeeded {
                lastErrorMessage = "Select a FreeFileSync batch job to begin."
                showPreferences()
            }
            scheduleNextSync()
            return
        }

        syncTimer?.invalidate()
        syncTimer = nil
        nextScheduledSyncAt = nil
        state = .syncing
        lastErrorMessage = nil
        let batchPath = settings.batchJobPath

        Task {
            do {
                let response = try await FreeFileSyncRunner.run(
                    batchJobPath: batchPath,
                    freeFileSyncAppPath: settings.freeFileSyncAppPath
                )
                let summary = StoredSyncSummary(
                    batchJobPath: batchPath,
                    output: response.output,
                    terminationStatus: response.terminationStatus,
                    completedAt: Date()
                )
                let completedState = SyncEvaluation.state(
                    for: response.output,
                    terminationStatus: response.terminationStatus
                )
                Self.saveSummary(summary)
                notifyIfNeeded(for: completedState, output: response.output)

                guard settings.batchJobPath == batchPath else {
                    lastSummary = nil
                    state = settings.batchJobPath.isEmpty ? .notConfigured : .ready
                    resetFailures(for: settings.batchJobPath)
                    currentTime = Date()
                    scheduleNextSync()
                    return
                }

                lastSummary = summary
                state = completedState
                currentTime = Date()
                if completedState == .error {
                    recordFailure(for: batchPath)
                } else {
                    resetFailures(for: batchPath)
                }
                scheduleNextSync()
            } catch {
                lastErrorMessage = error.localizedDescription
                notifyFailure(message: error.localizedDescription)
                state = settings.batchJobPath == batchPath
                    ? .error
                    : (settings.batchJobPath.isEmpty ? .notConfigured : .ready)
                currentTime = Date()
                if settings.batchJobPath == batchPath {
                    recordFailure(for: batchPath)
                }
                scheduleNextSync()
            }
        }
    }

    func openLastLog() {
        guard let path = lastSummary?.output.logFile else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    func openBatchInFreeFileSync() {
        do {
            try FreeFileSyncRunner.openForEditing(
                batchJobPath: settings.batchJobPath,
                freeFileSyncAppPath: settings.freeFileSyncAppPath
            )
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func showPreferences() {
        // MenuBarExtra with .menu style is backed by NSMenu. Presenting a window
        // while the menu is still tracking can cause AppKit to immediately order
        // it behind the active application, so wait until the next main-loop pass.
        DispatchQueue.main.async { [weak self] in
            self?.presentPreferencesWindow()
        }
    }

    private func presentPreferencesWindow() {
        let preferredHeight: CGFloat = 810
        let availableHeight = NSScreen.main?.visibleFrame.height
            ?? preferredHeight
        let contentSize = NSSize(
            width: 780,
            height: min(
                preferredHeight,
                max(620, availableHeight - 40)
            )
        )

        if let window = preferencesWindowController?.window {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.setContentSize(contentSize)
            window.contentMinSize = contentSize
            window.center()
            NSApp.unhide(nil)
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            return
        }

        let preferencesView = PreferencesView(model: self)
            .environmentObject(settings)
        let hostingController = NSHostingController(rootView: preferencesView)
        hostingController.sizingOptions = []
        hostingController.preferredContentSize = contentSize
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "MenuSync for FreeFileSync Preferences"
        window.contentViewController = hostingController
        window.setContentSize(contentSize)
        window.contentMinSize = contentSize
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace]
        window.center()

        let controller = NSWindowController(window: window)
        preferencesWindowController = controller
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
            lastErrorMessage = nil
        } catch {
            launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
            lastErrorMessage = "Launch at Login could not be changed: \(error.localizedDescription)"
        }
    }

    func resetPreferencesToDefaults() {
        settings.resetToDefaultsPreservingBatchJob()
        clearIconPreview()
        if launchAtLoginEnabled {
            setLaunchAtLogin(false)
        } else {
            lastErrorMessage = nil
        }
    }

    func previewIcon(
        _ drawing: CustomIconDrawing,
        animationConfiguration: IconAnimationConfiguration
    ) {
        guard !drawing.isEmpty else { return }
        previewIconDrawing = drawing
        previewAnimationConfiguration = animationConfiguration
        iconFrameCacheSignature = nil
        iconAnimationStartedAt = nil
        iconPreviewTimer?.invalidate()
        iconPreviewEndsAt = Date().addingTimeInterval(5)
        let timer = Timer(timeInterval: 5, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.clearIconPreview()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        iconPreviewTimer = timer
    }

    func clearIconPreview() {
        iconPreviewTimer?.invalidate()
        iconPreviewTimer = nil
        previewIconDrawing = nil
        previewAnimationConfiguration = nil
        iconPreviewEndsAt = nil
        iconFrameCacheSignature = nil
        iconAnimationStartedAt = nil
    }

    func requestNotificationAuthorizationIfNeeded() {
        guard settings.notificationsOnFailure else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private var syncInterval: TimeInterval {
        TimeInterval(max(settings.intervalMinutes, 1) * 60)
    }

    private var hasValidBatchJob: Bool {
        !settings.batchJobPath.isEmpty
            && URL(fileURLWithPath: settings.batchJobPath).pathExtension.lowercased() == "ffs_batch"
            && FileManager.default.fileExists(atPath: settings.batchJobPath)
    }

    private func scheduleInitialSync(requireExistingBatch: Bool = false) {
        syncTimer?.invalidate()
        syncTimer = nil
        nextScheduledSyncAt = nil

        guard !settings.batchJobPath.isEmpty, !isAutomaticallyPaused else { return }
        if requireExistingBatch, !hasValidBatchJob { return }
        let delay = SyncSchedule.initialDelay(
            lastCompletedAt: lastSummary?.completedAt,
            interval: syncInterval,
            now: Date()
        )
        if delay <= 0 {
            nextScheduledSyncAt = Date()
            DispatchQueue.main.async { [weak self] in
                self?.runSync(showPreferencesIfNeeded: false)
            }
        } else {
            scheduleNextSync(after: delay)
        }
    }

    private func scheduleNextSync(after delay: TimeInterval? = nil) {
        syncTimer?.invalidate()
        guard !isAutomaticallyPaused else {
            syncTimer = nil
            nextScheduledSyncAt = nil
            return
        }
        let actualDelay = max(delay ?? syncInterval, 1)
        let scheduledDate = Date().addingTimeInterval(actualDelay)
        nextScheduledSyncAt = scheduledDate
        let timer = Timer(timeInterval: actualDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.runSync(showPreferencesIfNeeded: false)
            }
        }
        timer.tolerance = min(actualDelay * 0.01, 0.5)
        RunLoop.main.add(timer, forMode: .common)
        syncTimer = timer
    }

    private func startIndicatorTimer() {
        indicatorTimer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.currentTime = Date()
            }
        }
        timer.tolerance = 0.15
        RunLoop.main.add(timer, forMode: .common)
        indicatorTimer = timer
    }

    private func startIconAnimationTimer() {
        iconAnimationTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0 / 15.0, repeats: true) {
            [weak self] _ in
            Task { @MainActor in
                guard let self, self.isIconAnimationActive else { return }
                self.iconAnimationDate = Date()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        iconAnimationTimer = timer
    }

    private func recordFailure(for batchJobPath: String) {
        if failureBatchJobPath != batchJobPath {
            failureBatchJobPath = batchJobPath
            consecutiveFailureCount = 0
        }
        consecutiveFailureCount = min(
            consecutiveFailureCount + 1,
            Self.maximumConsecutiveFailures
        )
        persistFailureState()
    }

    private func resetFailures(for batchJobPath: String) {
        failureBatchJobPath = batchJobPath
        consecutiveFailureCount = 0
        persistFailureState()
    }

    private func persistFailureState() {
        UserDefaults.standard.set(consecutiveFailureCount, forKey: Self.failureCountKey)
        UserDefaults.standard.set(failureBatchJobPath, forKey: Self.failureBatchPathKey)
    }

    private func compactDateTime(_ date: Date) -> String {
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        return String(
            format: "%04d/%02d/%02d %02d:%02d:%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0,
            components.hour ?? 0,
            components.minute ?? 0,
            components.second ?? 0
        )
    }

    private func notifyIfNeeded(for state: SyncState, output: FreeFileSyncOutput) {
        guard settings.notificationsOnFailure else { return }
        switch state {
        case .warning:
            deliverNotification(
                title: "FreeFileSync completed with warnings",
                body: "\(output.warnings ?? 0) warning(s)"
            )
        case .error:
            deliverNotification(
                title: "FreeFileSync failed",
                body: "\(output.errors ?? 0) error(s)"
            )
        default:
            break
        }
    }

    private func notifyFailure(message: String) {
        guard settings.notificationsOnFailure else { return }
        deliverNotification(title: "FreeFileSync failed", body: message)
    }

    private func deliverNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        )
    }

    private static func loadSummary() -> StoredSyncSummary? {
        guard let data = UserDefaults.standard.data(forKey: summaryKey) else { return nil }
        return try? JSONDecoder().decode(StoredSyncSummary.self, from: data)
    }

    private static func saveSummary(_ summary: StoredSyncSummary) {
        guard let data = try? JSONEncoder().encode(summary) else { return }
        UserDefaults.standard.set(data, forKey: summaryKey)
    }
}
