import SwiftUI

struct IconStudioView: View {
    @ObservedObject var model: AppModel
    @EnvironmentObject private var settings: SettingsStore

    @State private var selectedIndicator: MenuBarIndicator = .synced
    @State private var draft = CustomIconDrawing()
    @State private var lineWidth = 0.075
    @State private var deletionCandidateID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Menu Bar Icon Studio")
                    .font(.headline)

                Picker("Status", selection: $selectedIndicator) {
                    ForEach(MenuBarIndicator.allCases, id: \.self) { indicator in
                        Text(indicator.displayName).tag(indicator)
                    }
                }
                .frame(width: 230)

                Spacer()

                Text("Current")
                    .foregroundStyle(.secondary)
                Image(nsImage: assignedImage)
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 20, height: 20)
            }

            HStack(alignment: .top, spacing: 18) {
                IconDrawingCanvas(drawing: $draft, lineWidth: $lineWidth)
                    .frame(width: 220, height: 220)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Draw in white. The saved icon becomes a macOS template and automatically matches the menu bar appearance.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        Text("Stroke")
                        Slider(value: $lineWidth, in: 0.035...0.15)
                    }

                    HStack {
                        Button("Undo") {
                            if !draft.strokes.isEmpty {
                                draft.strokes.removeLast()
                            }
                        }
                        .disabled(draft.strokes.isEmpty)

                        Button("Clear") {
                            draft = CustomIconDrawing()
                            model.clearIconPreview()
                        }
                        .disabled(draft.isEmpty)
                    }

                    HStack {
                        Button("Preview for 15s") {
                            model.previewIcon(draft)
                        }
                        .disabled(draft.isEmpty)

                        if model.isPreviewingIcon {
                            Button("Stop Preview") {
                                model.clearIconPreview()
                            }
                        }
                    }

                    Button("Save & Use for \(selectedIndicator.displayName)") {
                        settings.saveAndAssign(draft, to: selectedIndicator)
                        model.clearIconPreview()
                        draft = CustomIconDrawing()
                    }
                    .disabled(draft.isEmpty)

                    Button("Use System Default") {
                        settings.useDefaultIcon(for: selectedIndicator)
                        model.clearIconPreview()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            HStack {
                Text("Drawing History")
                    .font(.subheadline.weight(.semibold))
                Text("\(settings.customIconHistory.count)/\(SettingsStore.maximumCustomIconHistory)")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Used icons are pinned first")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if settings.orderedCustomIcons.isEmpty {
                Text("Saved drawings will appear here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(height: 48)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(settings.orderedCustomIcons) { drawing in
                            HistoryIconTile(
                                drawing: drawing,
                                isInUse: settings.isCustomIconInUse(drawing.id),
                                onSelect: {
                                    settings.assignCustomIcon(
                                        drawing.id,
                                        to: selectedIndicator
                                    )
                                    model.clearIconPreview()
                                },
                                onDelete: {
                                    deletionCandidateID = drawing.id
                                }
                            )
                        }
                    }
                }
                .scrollIndicators(.visible)
                .frame(height: 58)
            }
        }
        .onChange(of: selectedIndicator) { _, _ in
            model.clearIconPreview()
        }
        .alert(
            "Delete Drawing?",
            isPresented: Binding(
                get: { deletionCandidateID != nil },
                set: { if !$0 { deletionCandidateID = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                if let deletionCandidateID {
                    settings.deleteCustomIcon(deletionCandidateID)
                }
                deletionCandidateID = nil
            }
            Button("Cancel", role: .cancel) {
                deletionCandidateID = nil
            }
        } message: {
            Text("This removes the drawing from history. This action cannot be undone.")
        }
    }

    private var assignedImage: NSImage {
        if let drawing = settings.customDrawing(for: selectedIndicator) {
            return MenuBarIconRenderer.customImage(
                from: drawing,
                accessibilityDescription: selectedIndicator.displayName
            )
        }
        return MenuBarIconRenderer.systemImage(
            named: settings.systemSymbolName(for: selectedIndicator)
                ?? selectedIndicator.defaultSystemSymbol,
            accessibilityDescription: selectedIndicator.displayName
        )
    }
}

private struct HistoryIconTile: View {
    let drawing: CustomIconDrawing
    let isInUse: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onSelect) {
                DrawingThumbnail(drawing: drawing)
                    .padding(7)
            }
            .buttonStyle(.bordered)
            .help(isInUse ? "In use — select for another status" : "Use this drawing")

            if isInUse {
                Image(systemName: "pin.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                    .padding(3)
            } else if isHovering {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .red)
                }
                .buttonStyle(.plain)
                .help("Delete drawing")
                .padding(1)
            }
        }
        .onHover { isHovering = $0 }
    }
}
