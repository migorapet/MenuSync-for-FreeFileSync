import AppKit
import SwiftUI

struct CompanionMenuView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            compactInfoPanel

            if let message = model.lastErrorMessage {
                Divider()
                    .padding(.vertical, 5)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }

            Divider()
                .padding(.vertical, 5)

            actionButton("Run Sync Now") {
                model.runSync()
            }
            .disabled(!model.canRun)

            actionButton("Open Last Log") {
                model.openLastLog()
            }
            .disabled(!model.canOpenLastLog)

            actionButton("Open Batch in FreeFileSync") {
                model.openBatchInFreeFileSync()
            }
            .disabled(!model.canOpenBatch)

            Divider()
                .padding(.vertical, 5)

            actionButton("Preferences…") {
                model.showPreferences()
            }

            actionButton("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(10)
        .frame(width: 350)
    }

    private var compactInfoPanel: some View {
        VStack(alignment: .leading, spacing: 3) {
            statusRow
            infoRow("Last Sync", model.lastSyncText)
            infoRow("Next Sync", model.nextSyncText)
            infoRow("Duration", model.durationText)
            infoRow("Files", model.filesProcessedText)
            infoRow("Warnings / Errors", "\(model.warningsText) / \(model.errorsText)")
            if model.consecutiveFailureCount > 0 {
                infoRow("Failed Runs", model.failureCountText)
            }
        }
        .font(.system(size: 12))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusRow: some View {
        HStack(spacing: 8) {
            Text("Status")
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Image(nsImage: model.menuBarImage)
                .resizable()
                .frame(width: 14, height: 14)
            .frame(width: 14, height: 14)
            Text(model.isPreviewingIcon ? "Icon Preview" : model.menuBarStatusText)
                .lineLimit(1)
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .lineLimit(1)
                .monospacedDigit()
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private func actionButton(
        _ title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
            }
            .contentShape(Rectangle())
            .frame(height: 25)
        }
        .buttonStyle(.plain)
    }
}
