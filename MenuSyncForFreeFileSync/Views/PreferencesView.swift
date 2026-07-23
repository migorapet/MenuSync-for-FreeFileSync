import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PreferencesView: View {
    @ObservedObject var model: AppModel
    @EnvironmentObject private var settings: SettingsStore
    @State private var isShowingResetConfirmation = false

    private let intervals = [1, 5, 10, 15, 30, 60]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 16) {
                GridRow {
                    preferenceLabel("FreeFileSync")
                    HStack(spacing: 8) {
                        TextField(
                            "Choose FreeFileSync.app",
                            text: $settings.freeFileSyncAppPath
                        )
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
                        Button("Choose…", action: chooseFreeFileSyncApp)
                    }
                }

                GridRow {
                    preferenceLabel("Batch Job")
                    HStack(spacing: 8) {
                        TextField("Choose a .ffs_batch file", text: $settings.batchJobPath)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: .infinity)
                        Button("Choose…", action: chooseBatchJob)
                    }
                }

                GridRow {
                    preferenceLabel("Sync Interval")
                    Picker("", selection: $settings.intervalMinutes) {
                        ForEach(intervals, id: \.self) { minutes in
                            Text(intervalLabel(minutes)).tag(minutes)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 180, alignment: .leading)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Toggle(
                    "Launch at Login",
                    isOn: Binding(
                        get: { model.launchAtLoginEnabled },
                        set: { model.setLaunchAtLogin($0) }
                    )
                )

                Toggle(
                    "Notifications for warnings and failures",
                    isOn: $settings.notificationsOnFailure
                )
                .onChange(of: settings.notificationsOnFailure) { _, enabled in
                    if enabled { model.requestNotificationAuthorizationIfNeeded() }
                }
            }
            .padding(.leading, 134)

            Divider()

            IconStudioView(model: model)

            if let message = model.lastErrorMessage {
                Text(message)
                    .foregroundStyle(.red)
                    .font(.callout)
                    .lineLimit(2)
            }

            HStack {
                Button {
                    isShowingResetConfirmation = true
                } label: {
                    Text("Reset All Preferences…")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Synchronization rules remain managed by FreeFileSync.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Open Batch in FreeFileSync") {
                    model.openBatchInFreeFileSync()
                }
                .disabled(!model.canOpenBatch)
            }
        }
        .padding(24)
        .frame(width: 780, height: 810, alignment: .topLeading)
        .onAppear {
            model.requestNotificationAuthorizationIfNeeded()
        }
        .alert(
            "Reset All Preferences?",
            isPresented: $isShowingResetConfirmation
        ) {
            Button("Reset All Preferences", role: .destructive) {
                model.resetPreferencesToDefaults()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "This resets the FreeFileSync app path, sync interval, notifications, status icons, animations, and Launch at Login. The batch job path and saved drawing history are kept."
            )
        }
    }

    private func preferenceLabel(_ text: String) -> some View {
        Text(text)
            .frame(width: 120, alignment: .trailing)
    }

    private func chooseBatchJob() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Choose"
        panel.message = "Select a FreeFileSync batch job."
        panel.allowedContentTypes = [
            UTType(filenameExtension: "ffs_batch") ?? .data
        ]

        if panel.runModal() == .OK, let url = panel.url {
            settings.batchJobPath = url.path
        }
    }

    private func chooseFreeFileSyncApp() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Choose"
        panel.message = "Select the FreeFileSync application."
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)

        if panel.runModal() == .OK, let url = panel.url {
            settings.freeFileSyncAppPath = url.path
        }
    }

    private func intervalLabel(_ minutes: Int) -> String {
        minutes == 1 ? "Every minute" : "Every \(minutes) minutes"
    }
}
