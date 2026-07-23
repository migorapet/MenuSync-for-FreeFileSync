import AppKit
import SwiftUI

struct IconStudioView: View {
    @ObservedObject var model: AppModel
    @EnvironmentObject private var settings: SettingsStore

    @State private var selectedIndicator: MenuBarIndicator = .synced
    @State private var draft = CustomIconDrawing()
    @State private var lineWidth = 0.075
    @State private var selectedColor: IconStrokeColor = .white
    @State private var deletionCandidateID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Menu Bar Icon Studio")
                    .font(.headline)

                Spacer()

                Text("Status")
                    .foregroundStyle(.secondary)

                Menu {
                    ForEach(MenuBarIndicator.allCases, id: \.self) { indicator in
                        Button {
                            selectedIndicator = indicator
                        } label: {
                            statusMenuItemLabel(for: indicator)
                        }
                    }
                } label: {
                    HStack(spacing: 7) {
                        statusPickerIcon(for: selectedIndicator)
                        Text(selectedIndicator.displayName)
                        Spacer()
                    }
                    .frame(width: 205, alignment: .leading)
                }
                .menuStyle(.borderlessButton)
            }

            HStack(alignment: .top, spacing: 12) {
                GroupBox("Drawing") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 14) {
                            IconDrawingCanvas(
                                drawing: $draft,
                                lineWidth: $lineWidth,
                                selectedColor: $selectedColor
                            )
                            .frame(width: 205, height: 205)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Choose a pen color, then draw. Each stroke keeps its selected color.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text("Pen Color")
                                    .font(.subheadline.weight(.medium))

                                LazyVGrid(
                                    columns: Array(
                                        repeating: GridItem(
                                            .fixed(32),
                                            spacing: 8
                                        ),
                                        count: 4
                                    ),
                                    alignment: .leading,
                                    spacing: 8
                                ) {
                                    ForEach(IconStrokeColor.allCases) { color in
                                        ColorSwatchButton(
                                            color: color,
                                            isSelected: selectedColor == color
                                        ) {
                                            selectedColor = color
                                        }
                                    }
                                }

                                HStack(spacing: 8) {
                                    Text("Stroke")
                                    Slider(
                                        value: $lineWidth,
                                        in: 0.035...0.15
                                    )
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
                                    Button("Preview Draft") {
                                        model.previewIcon(
                                            draft,
                                            animationConfiguration:
                                                animationConfiguration
                                        )
                                    }
                                    .disabled(draft.isEmpty)

                                    if model.isPreviewingIcon {
                                        Button("Stop") {
                                            model.clearIconPreview()
                                        }
                                    }
                                }
                            }
                        }

                        Divider()

                        HStack {
                            Text("Drawing History")
                                .font(.subheadline.weight(.semibold))
                            Text(
                                "\(settings.customIconHistory.count)/\(SettingsStore.maximumCustomIconHistory)"
                            )
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
                                            isInUse: settings.isCustomIconInUse(
                                                drawing.id
                                            ),
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

                        Button(
                            "Save & Use for \(selectedIndicator.displayName)"
                        ) {
                            settings.saveAndAssign(
                                draft,
                                to: selectedIndicator
                            )
                            model.clearIconPreview()
                            draft = CustomIconDrawing()
                        }
                        .disabled(draft.isEmpty)
                    }
                }
                .frame(
                    maxWidth: .infinity,
                    minHeight: 375,
                    maxHeight: 375,
                    alignment: .top
                )

                GroupBox("Motion & Current Preview") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(selectedIndicator.displayName)
                                    .font(.subheadline.weight(.medium))
                                Text("Current status icon")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            AnimatedIconPreview(
                                image: assignedBaseImage,
                                configuration: animationConfiguration,
                                size: 44
                            )
                            .id(animatedPreviewIdentity)
                            .padding(6)
                        }

                        Divider()

                        Text("Motion")
                            .font(.subheadline.weight(.medium))

                        LazyVGrid(
                            columns: Array(
                                repeating: GridItem(
                                    .flexible(),
                                    spacing: 7
                                ),
                                count: 3
                            ),
                            spacing: 7
                        ) {
                            ForEach(IconAnimationEffect.allCases) { effect in
                                MotionOptionButton(
                                    effect: effect,
                                    isSelected:
                                        animationConfiguration.effect == effect
                                ) {
                                    settings.setAnimationEffect(
                                        effect,
                                        for: selectedIndicator
                                    )
                                }
                            }
                        }

                        Text("Duration")
                            .font(.subheadline.weight(.medium))

                        Picker(
                            "Duration",
                            selection: animationDurationBinding
                        ) {
                            ForEach(animationDurationChoices, id: \.self) {
                                seconds in
                                Text("\(seconds)s").tag(seconds)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .disabled(animationConfiguration.effect == .none)

                        Text("The motion uses a one-second cycle, then becomes static after this duration.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)

                        Divider()

                        HStack {
                            Spacer()
                            Button("Use System Default") {
                                settings.useDefaultIcon(
                                    for: selectedIndicator
                                )
                                model.clearIconPreview()
                            }
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                }
                .frame(width: 265)
                .frame(
                    minHeight: 375,
                    maxHeight: 375,
                    alignment: .top
                )
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

    private var animationConfiguration: IconAnimationConfiguration {
        settings.animationConfiguration(for: selectedIndicator)
    }

    private var animationDurationBinding: Binding<Int> {
        Binding(
            get: { animationConfiguration.durationSeconds },
            set: { settings.setAnimationDuration($0, for: selectedIndicator) }
        )
    }

    private var animationDurationChoices: [Int] {
        animationConfiguration.effect == .none
            ? [0]
            : Array(1...5)
    }

    private var assignedBaseImage: NSImage {
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

    @ViewBuilder
    private func statusMenuItemLabel(
        for indicator: MenuBarIndicator
    ) -> some View {
        if let drawing = settings.customDrawing(for: indicator) {
            Label {
                Text(indicator.displayName)
            } icon: {
                Image(
                    nsImage: MenuBarIconRenderer.customImage(
                        from: drawing,
                        accessibilityDescription: indicator.displayName
                    )
                )
            }
        } else {
            Text(indicator.displayName)
        }
    }

    @ViewBuilder
    private func statusPickerIcon(
        for indicator: MenuBarIndicator
    ) -> some View {
        if let drawing = settings.customDrawing(for: indicator) {
            Image(
                nsImage: MenuBarIconRenderer.customImage(
                    from: drawing,
                    accessibilityDescription: indicator.displayName
                )
            )
            .resizable()
            .scaledToFit()
            .frame(width: 14, height: 14)
        }
    }

    private var animatedPreviewIdentity: String {
        let assignment = settings.statusIconAssignments[
            selectedIndicator.rawValue
        ] ?? "default"
        return [
            selectedIndicator.rawValue,
            assignment,
            animationConfiguration.effect.rawValue,
            String(animationConfiguration.durationSeconds)
        ].joined(separator: ":")
    }
}

private struct ColorSwatchButton: View {
    let color: IconStrokeColor
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color.swiftUIColor)
                Circle()
                    .stroke(
                        isSelected
                            ? Color.accentColor
                            : Color.secondary.opacity(0.45),
                        lineWidth: isSelected ? 3 : 1
                    )
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(color.checkmarkColor)
                }
            }
            .frame(width: 32, height: 32)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(color.displayName)
        .accessibilityLabel(color.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct MotionOptionButton: View {
    let effect: IconAnimationEffect
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: effect.symbolName)
                    .font(.system(size: 12, weight: .semibold))
                Text(effect.displayName)
                    .font(.caption)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 42)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(
                isSelected
                    ? Color.accentColor
                    : Color(nsColor: .controlBackgroundColor),
                in: RoundedRectangle(cornerRadius: 7)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(
                        isSelected
                            ? Color.accentColor
                            : Color.secondary.opacity(0.25),
                        lineWidth: 1
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct AnimatedIconPreview: View {
    let configuration: IconAnimationConfiguration
    let size: CGFloat
    private let frames: [NSImage]
    @State private var animationStartedAt: Date

    init(
        image: NSImage,
        configuration: IconAnimationConfiguration,
        size: CGFloat
    ) {
        self.configuration = configuration
        self.size = size
        _animationStartedAt = State(initialValue: Date())
        frames = MenuBarIconRenderer.animationFrames(
            from: image,
            configuration: configuration
        )
    }

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: 1.0 / 10.0,
                paused: frames.count <= 1
            )
        ) { context in
            Image(
                nsImage: MenuBarIconRenderer.frame(
                    at: context.date,
                    animationStartedAt: animationStartedAt,
                    from: frames,
                    animationDurationSeconds: configuration.durationSeconds
                )
            )
            .resizable()
            .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
    }
}

private extension IconAnimationEffect {
    var symbolName: String {
        switch self {
        case .none: "minus"
        case .spin: "arrow.clockwise"
        case .shake: "waveform"
        case .sway: "arrow.left.and.right"
        case .breathe: "circle.dotted"
        }
    }
}

private extension IconStrokeColor {
    var swiftUIColor: Color {
        Color(
            red: components.red,
            green: components.green,
            blue: components.blue
        )
    }

    var checkmarkColor: Color {
        self == .charcoal ? .white : .black.opacity(0.72)
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
