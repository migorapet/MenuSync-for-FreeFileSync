import AppKit

@main
struct AnimationSmokeTest {
    static func main() {
        let drawing = CustomIconDrawing(
            strokes: [
                IconStroke(
                    points: [
                        IconPoint(x: 0.2, y: 0.5),
                        IconPoint(x: 0.8, y: 0.5)
                    ],
                    width: 0.08,
                    color: .mint
                )
            ]
        )
        let source = MenuBarIconRenderer.customImage(
            from: drawing,
            accessibilityDescription: "Animation test"
        )
        let configuration = IconAnimationConfiguration(
            effect: .spin,
            durationSeconds: 2
        )
        let frames = MenuBarIconRenderer.animationFrames(
            from: source,
            configuration: configuration
        )
        precondition(frames.count == MenuBarIconRenderer.animationFrameCount)
        assertInitialAnimationSizeMatches(source)
        assertAnimationSizeRemainsStable(source)
        assertOpaqueAnimationEnergyIsStable(source)
        assertAnimationsVisuallyChange(source)
        assertPlaybackVisuallyChanges(source)

        let systemSource = MenuBarIconRenderer.systemImage(
            named: "arrow.triangle.2.circlepath",
            accessibilityDescription: "System animation test"
        )
        assertInitialAnimationSizeMatches(systemSource)
        assertAnimationSizeRemainsStable(systemSource)
        assertOpaqueAnimationEnergyIsStable(systemSource)

        var identities = Set<ObjectIdentifier>()
        let animationStart = Date(timeIntervalSinceReferenceDate: 0)
        for offset in 0..<100_000 {
            let frame = MenuBarIconRenderer.frame(
                at: animationStart.addingTimeInterval(
                    Double(offset) / 120
                ),
                animationStartedAt: animationStart,
                from: frames,
                animationDurationSeconds: configuration.durationSeconds
            )
            identities.insert(ObjectIdentifier(frame))
        }
        precondition(identities.count <= frames.count)
        let stoppedFrame = MenuBarIconRenderer.frame(
            at: animationStart.addingTimeInterval(2),
            animationStartedAt: animationStart,
            from: frames,
            animationDurationSeconds: 2
        )
        precondition(stoppedFrame === frames[0])
        let firstCycleFrame = MenuBarIconRenderer.frame(
            at: animationStart.addingTimeInterval(0.25),
            animationStartedAt: animationStart,
            from: frames,
            animationDurationSeconds: 3
        )
        let secondCycleFrame = MenuBarIconRenderer.frame(
            at: animationStart.addingTimeInterval(1.25),
            animationStartedAt: animationStart,
            from: frames,
            animationDurationSeconds: 3
        )
        precondition(firstCycleFrame === secondCycleFrame)

        let staticFrames = MenuBarIconRenderer.animationFrames(
            from: source,
            configuration: IconAnimationConfiguration()
        )
        precondition(staticFrames.count == 1)
        precondition(staticFrames[0] === source)

        print("Animation smoke tests passed")
    }

    private static func assertInitialAnimationSizeMatches(_ source: NSImage) {
        let sourceBounds = alphaBounds(of: source)
        for effect in [
            IconAnimationEffect.spin,
            .shake,
            .sway
        ] {
            let firstFrame = MenuBarIconRenderer.animationFrames(
                from: source,
                configuration: IconAnimationConfiguration(
                    effect: effect,
                    durationSeconds: 2
                )
            )[0]
            let frameBounds = alphaBounds(of: firstFrame)
            precondition(
                abs(frameBounds.width - sourceBounds.width) <= 1,
                "\(effect) width changed from \(sourceBounds.width) to \(frameBounds.width)"
            )
            precondition(
                abs(frameBounds.height - sourceBounds.height) <= 1,
                "\(effect) height changed from \(sourceBounds.height) to \(frameBounds.height)"
            )
        }
    }

    private static func assertAnimationSizeRemainsStable(_ source: NSImage) {
        let sourceBounds = alphaBounds(of: source)
        // A rotated non-square drawing naturally has a different axis-aligned
        // bounding box even when no scaling is applied. Only effects that must
        // preserve the drawing's axes can use this width/height invariant.
        for effect in [IconAnimationEffect.shake, .breathe] {
            let frames = MenuBarIconRenderer.animationFrames(
                from: source,
                configuration: IconAnimationConfiguration(
                    effect: effect,
                    durationSeconds: 2
                )
            )
            for frame in frames {
                let frameBounds = alphaBounds(of: frame)
                precondition(
                    abs(frameBounds.width - sourceBounds.width) <= 1.5,
                    "\(effect) width changed from \(sourceBounds.width) to \(frameBounds.width)"
                )
                precondition(
                    abs(frameBounds.height - sourceBounds.height) <= 1.5,
                    "\(effect) height changed from \(sourceBounds.height) to \(frameBounds.height)"
                )
            }
        }
    }

    private static func assertOpaqueAnimationEnergyIsStable(_ source: NSImage) {
        for effect in [IconAnimationEffect.spin, .shake, .sway] {
            let frames = MenuBarIconRenderer.animationFrames(
                from: source,
                configuration: IconAnimationConfiguration(effect: effect)
            )
            let energies = frames.map(alphaEnergy)
            guard let minimum = energies.min(), let maximum = energies.max(),
                  maximum > 0
            else {
                preconditionFailure("Expected visible \(effect) frames")
            }
            precondition(
                minimum / maximum >= 0.90,
                "\(effect) unexpectedly changes opacity: \(minimum / maximum)"
            )
        }
    }

    private static func assertAnimationsVisuallyChange(_ source: NSImage) {
        for effect in IconAnimationEffect.allCases where effect != .none {
            let frames = MenuBarIconRenderer.animationFrames(
                from: source,
                configuration: IconAnimationConfiguration(effect: effect)
            )
            let uniqueFrames = Set(frames.compactMap(\.tiffRepresentation))
            precondition(
                uniqueFrames.count > 1,
                "\(effect) did not produce visually distinct frames"
            )
        }
    }

    private static func assertPlaybackVisuallyChanges(_ source: NSImage) {
        let startedAt = Date(timeIntervalSinceReferenceDate: 100)
        for effect in IconAnimationEffect.allCases where effect != .none {
            let frames = MenuBarIconRenderer.animationFrames(
                from: source,
                configuration: IconAnimationConfiguration(effect: effect)
            )
            let playbackFrames = [0.1, 0.4, 0.7].map { elapsed in
                MenuBarIconRenderer.frame(
                    at: startedAt.addingTimeInterval(elapsed),
                    animationStartedAt: startedAt,
                    from: frames,
                    animationDurationSeconds: 1
                )
            }
            let uniqueFrames = Set(
                playbackFrames.compactMap(\.tiffRepresentation)
            )
            precondition(
                uniqueFrames.count > 1,
                "\(effect) playback remained on one frame"
            )
        }
    }

    private static func alphaEnergy(of image: NSImage) -> Double {
        guard let data = image.tiffRepresentation,
              let representation = NSBitmapImageRep(data: data)
        else {
            preconditionFailure("Expected a bitmap representation")
        }
        var total = 0.0
        for y in 0..<representation.pixelsHigh {
            for x in 0..<representation.pixelsWide {
                total += Double(
                    representation.colorAt(x: x, y: y)?
                        .alphaComponent ?? 0
                )
            }
        }
        return total
    }

    private static func alphaBounds(of image: NSImage) -> NSRect {
        guard let data = image.tiffRepresentation,
              let representation = NSBitmapImageRep(data: data)
        else {
            preconditionFailure("Expected a bitmap representation")
        }

        var minimumX = representation.pixelsWide
        var minimumY = representation.pixelsHigh
        var maximumX = -1
        var maximumY = -1

        for y in 0..<representation.pixelsHigh {
            for x in 0..<representation.pixelsWide {
                guard let color = representation.colorAt(x: x, y: y),
                      color.alphaComponent > 0.05
                else {
                    continue
                }
                minimumX = min(minimumX, x)
                minimumY = min(minimumY, y)
                maximumX = max(maximumX, x)
                maximumY = max(maximumY, y)
            }
        }

        guard maximumX >= minimumX, maximumY >= minimumY else {
            return .zero
        }
        let pointScaleX = image.size.width
            / CGFloat(representation.pixelsWide)
        let pointScaleY = image.size.height
            / CGFloat(representation.pixelsHigh)
        return NSRect(
            x: CGFloat(minimumX) * pointScaleX,
            y: CGFloat(minimumY) * pointScaleY,
            width: CGFloat(maximumX - minimumX + 1) * pointScaleX,
            height: CGFloat(maximumY - minimumY + 1) * pointScaleY
        )
    }
}
